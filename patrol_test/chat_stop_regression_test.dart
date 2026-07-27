// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

// Patrol investigation for the "chat hangs after Stop" report
// (docs/HANDOFF_CHAT_HANG.md): load a model, stream a long reply, tap Stop
// mid-stream, keep chatting — the next turn shows an infinite spinner and
// never prefills (`time-to-first-chunk` appears exactly once in logcat).
//
// Why Patrol: on the repro device (Redmi Note 13, MIUI) `adb shell input` is
// blocked (INJECT_EVENTS), so scripted repro was impossible. Patrol taps are
// synthesized inside the app process by the Flutter test binding, bypassing
// Android input injection entirely. Native (UiAutomator) automation is used
// only as a guarded fallback for permission dialogs.
//
// Model loading: the model is NEVER downloaded during a test. Run
// `make patrol-prepare` once — it caches the model on the host and seeds it
// into the app sandbox. The first test run installs from that seed; because
// app data is kept between runs (no clearPackageData) the app cold-start
// restores the model on every later run in seconds.
//
// Scenarios:
//   A) stop, continue immediately          — the user repro; expected to FAIL
//      while the bug exists (that failure IS the reproduction, with timings).
//   B) stop, wait 120s, then continue      — if B passes while A fails, the
//      conversation is temporarily busy, not permanently wedged; if both fail
//      the wedge is persistent (matches the user report).

import 'dart:io';

import 'package:disastron/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_message.dart';
import 'package:disastron/features/chat/presentation/widgets/gemma_input_field.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/presentation/model_install_orchestrator.dart';
import 'package:disastron/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:permission_handler/permission_handler.dart';

/// Provokes a reply long enough to still be streaming when Stop is tapped
/// (the reply is capped at 512 tokens, see `GemmaLocalService`).
const String _kLongPrompt =
    'Write an extremely detailed, numbered, step-by-step guide with at least '
    '40 steps on preparing a household for a two-week power outage. Explain '
    'every step in full sentences and do not stop early.';

const String _kProbePrompt = 'Reply with exactly one word: PONG';

/// How long the turn after Stop may take to stream its first token before the
/// chat counts as wedged. Prefill of a short prompt takes seconds (~10s
/// measured for the first turn incl. vision init) — 2 min is generous.
const Duration _kFirstTokenTimeout = Duration(minutes: 2);

/// How long a started reply may take to finish (max 512 tokens on-device).
const Duration _kCompletionTimeout = Duration(minutes: 5);

/// Scenario B: time given to the engine to finish decoding the abandoned turn
/// (Stop drops the Dart subscription; whether native generation really stops
/// is part of what this investigation measures).
const Duration _kEngineDrainWait = Duration(seconds: 120);

const List<String> _kModelFileExtensions = <String>[
  '.litertlm',
  '.task',
  '.bin',
];

final Stopwatch _clock = Stopwatch()..start();

// Test names deliberately avoid commas/colons: the no-orchestrator fallback
// (tool/patrol/run_no_orchestrator.sh) selects them via `am instrument -e
// class ...#runDartTest[<name>]`, where a comma splits the argument.
void main() {
  patrolTest('A stop mid-stream then continue immediately', ($) async {
    await _bootIntoReadyChat($);

    _log('baseline turn: proving chat works before any stop');
    await _send($, 'Reply with exactly one word: READY');
    final _TurnResult baseline = await _awaitAssistantTurn($);
    expect(
      baseline.completed,
      isTrue,
      reason:
          'Baseline turn (before any Stop) already failed: '
          '${baseline.describe()}. Plain chat is broken - the stop bug is '
          'not reachable; investigate model/init first.',
    );
    _log('baseline ok: ${baseline.describe()}');

    _log('long turn: sending, will stop mid-stream');
    await _send($, _kLongPrompt);
    await _waitForStreamedChars($, minChars: 24);
    await _tapStop($);
    _log('stopped; continuing immediately (user repro)');

    await _send($, _kProbePrompt);
    final _TurnResult probe = await _awaitAssistantTurn($);
    expect(
      probe.tokensStarted,
      isTrue,
      reason:
          'REPRODUCED (docs/HANDOFF_CHAT_HANG.md): after Stop, the next '
          'message never produced a token in '
          '${_kFirstTokenTimeout.inSeconds}s - prefill never ran, matching '
          'the single time-to-first-chunk logcat signature. '
          '${probe.describe()}',
    );
    expect(
      probe.completed,
      isTrue,
      reason:
          'PARTIAL WEDGE: the turn after Stop started streaming but never '
          'finished within ${_kCompletionTimeout.inSeconds}s more. '
          '${probe.describe()}',
    );
    _log('scenario A passed: ${probe.describe()}');
  });

  patrolTest('B stop mid-stream then drain then continue', ($) async {
    await _bootIntoReadyChat($);

    _log('long turn: sending, will stop mid-stream');
    await _send($, _kLongPrompt);
    await _waitForStreamedChars($, minChars: 24);
    await _tapStop($);

    _log(
      'stopped; waiting ${_kEngineDrainWait.inSeconds}s for the engine to '
      'drain the abandoned turn before continuing',
    );
    await _pumpFor($, _kEngineDrainWait);

    await _send($, _kProbePrompt);
    final _TurnResult probe = await _awaitAssistantTurn($);
    expect(
      probe.tokensStarted && probe.completed,
      isTrue,
      reason:
          'Chat is wedged even after a ${_kEngineDrainWait.inSeconds}s drain '
          'wait - the conversation is persistently broken, not just busy '
          '(compare with scenario A). ${probe.describe()}',
    );
    _log('scenario B passed: ${probe.describe()}');
  });
}

// --------------------------------------------------------------------------
// Boot & environment
// --------------------------------------------------------------------------

Future<void> _bootIntoReadyChat(PatrolIntegrationTester $) async {
  _log('launching app');
  await app.main();
  await $.pump(const Duration(seconds: 1));
  await _grantNativePermissionIfAsked($);
  await _completeFirstRunDialogsIfAny($);
  // The location permission dialog can pop while the terms dialog is still
  // up (dashboard init requests location). Chat init awaits the dashboard
  // situation, so an unanswered dialog blocks chat readiness forever.
  await _grantNativePermissionIfAsked($);
  await _ensureModelActive($);
  _log('model active; opening chat tab');
  await $(Icons.smart_toy_outlined).tap();
  await _waitForChatReady($);
  _log('chat ready');
}

/// Best-effort dismissal of a NATIVE Android permission dialog (location /
/// notifications). Primary defense is `pm grant` (make patrol-prepare and
/// make patrol-test both pre-grant); this UiAutomator fallback may be blocked
/// on MIUI without "USB debugging (Security settings)" — hence best-effort.
Future<void> _grantNativePermissionIfAsked(PatrolIntegrationTester $) async {
  // Grants persist in app data (which is never cleared between runs), so
  // skip the native automation entirely once the permission is in place.
  final PermissionStatus status = await Permission.locationWhenInUse.status;
  if (status.isGranted) {
    _log('location permission already granted - skipping native dialog');
    return;
  }
  try {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
    _log('granted a native permission dialog');
  } on Object catch (e) {
    _log('no native permission dialog handled (${e.runtimeType})');
  }
}

/// Accepts the first-run language + terms dialogs when present (they persist
/// as done afterwards, so on later runs this is a quick no-op poll).
Future<void> _completeFirstRunDialogsIfAny(PatrolIntegrationTester $) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 25));
  int quietPolls = 0;
  while (DateTime.now().isBefore(deadline) && quietPolls < 4) {
    await $.pump(const Duration(milliseconds: 500));
    if (!$.tester.any(find.byType(AlertDialog))) {
      quietPolls += 1;
      continue;
    }
    quietPolls = 0;
    if ($.tester.any(find.byType(CheckboxListTile))) {
      _log('accepting terms dialog');
      await $(CheckboxListTile).tap(settlePolicy: SettlePolicy.trySettle);
      await $(AlertDialog)
          .$(FilledButton)
          .tap(settlePolicy: SettlePolicy.trySettle);
    } else {
      _log('confirming first-run (language) dialog');
      await $(AlertDialog)
          .$(FilledButton)
          .tap(settlePolicy: SettlePolicy.trySettle);
    }
  }
}

/// Waits for the cold-start registry restore; when nothing restores, installs
/// the model from the file seeded by tool/patrol/prepare_model.sh.
Future<void> _ensureModelActive(PatrolIntegrationTester $) async {
  final ModelRegistryStore store = ModelRegistryStore();
  await store.migrateFromLegacyIfNeeded();
  final ModelRegistrySnapshot snap = await store.readSnapshot();
  final bool restoreExpected = snap.activeEntryId != null;
  final Duration restoreWait = restoreExpected
      ? const Duration(minutes: 3)
      : const Duration(seconds: 10);
  _log(
    'waiting up to ${restoreWait.inSeconds}s for an active model '
    '(registry entry present: $restoreExpected)',
  );
  final DateTime deadline = DateTime.now().add(restoreWait);
  while (!FlutterGemma.hasActiveModel() && DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
  }
  if (FlutterGemma.hasActiveModel()) {
    _log('model active via cold-start restore');
    return;
  }

  final File? seed = await _findSeedModelFile();
  if (seed == null) {
    fail(
      'No active model and no seed file on the device. Run '
      '`make patrol-prepare` once (tool/patrol/prepare_model.sh) with the '
      'device connected, then re-run this test. The seed is expected in '
      '<app support dir>/patrol_seed/.',
    );
  }
  _log(
    'installing model from seed ${seed.path} '
    '(${seed.lengthSync()} bytes) - one-time per device',
  );
  await ModelInstallOrchestrator(
    registry: ModelRegistryStore(),
  ).installFromFile(seed.path);
  expect(
    FlutterGemma.hasActiveModel(),
    isTrue,
    reason: 'installFromFile(${seed.path}) finished but no model is active',
  );
  _log('seed install done');
}

Future<File?> _findSeedModelFile() async {
  final List<Directory?> bases = <Directory?>[
    await getApplicationSupportDirectory(),
    await getExternalStorageDirectory(),
  ];
  for (final Directory? base in bases) {
    if (base == null) {
      continue;
    }
    final Directory dir = Directory(p.join(base.path, 'patrol_seed'));
    if (!dir.existsSync()) {
      continue;
    }
    final List<File> candidates = dir
        .listSync()
        .whereType<File>()
        .where(
          (File f) => _kModelFileExtensions.any(
            (String ext) => f.path.toLowerCase().endsWith(ext),
          ),
        )
        .toList()
      ..sort((File a, File b) => b.lengthSync().compareTo(a.lengthSync()));
    if (candidates.isNotEmpty) {
      return candidates.first;
    }
  }
  return null;
}

/// Chat is ready when its input field is present. When the model was seeded
/// mid-session the tab still shows "No on-device model yet" - tap its
/// "Check again" button so the provider re-reads the engine.
Future<void> _waitForChatReady(PatrolIntegrationTester $) async {
  final DateTime deadline = DateTime.now().add(const Duration(minutes: 5));
  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
    if (_chatInputFieldPresent($)) {
      return;
    }
    final Finder checkAgain = find.widgetWithText(FilledButton, 'Check again');
    if ($.tester.any(checkAgain)) {
      _log('tapping "Check again" so chat picks up the seeded model');
      await $.tester.tap(checkAgain);
      await $.pump(const Duration(seconds: 1));
    }
  }
  fail(
    'Chat did not become ready within 5 minutes (model load is ~18s engine '
    'create + ~7-9s session create on the repro device - 5 min means init '
    'is stuck or failed; check for a "Chat init failed" message on screen).',
  );
}

// --------------------------------------------------------------------------
// Chat interaction
// --------------------------------------------------------------------------

bool _chatInputFieldPresent(PatrolIntegrationTester $) => $.tester.any(
  find.descendant(
    of: find.byType(ChatInputField),
    matching: find.byType(TextField),
  ),
);

Future<void> _send(PatrolIntegrationTester $, String text) async {
  _log('sending: "$text"');
  await $(ChatInputField).$(TextField).enterText(text);
  await $.pump(const Duration(milliseconds: 300));
  await $(ChatInputField)
      .$(Icons.send)
      .tap(settlePolicy: SettlePolicy.noSettle);
  // One frame so GemmaInputField mounts and starts streaming; do NOT settle -
  // the assistant spinner animates forever, pumpAndSettle would time out.
  await $.pump(const Duration(milliseconds: 300));
}

Future<void> _tapStop(PatrolIntegrationTester $) async {
  await $(GemmaInputField)
      .$(Icons.stop_circle_outlined)
      .tap(settlePolicy: SettlePolicy.noSettle);
  await $.pump(const Duration(milliseconds: 300));
}

/// The text streamed so far for the in-flight assistant turn ('' when no turn
/// is streaming).
String _streamedText(PatrolIntegrationTester $) {
  final Iterable<Element> found = find
      .descendant(
        of: find.byType(GemmaInputField),
        matching: find.byType(ChatMessageWidget),
      )
      .evaluate();
  if (found.isEmpty) {
    return '';
  }
  return (found.first.widget as ChatMessageWidget).message.text;
}

Future<void> _waitForStreamedChars(
  PatrolIntegrationTester $, {
  required int minChars,
}) async {
  final DateTime deadline = DateTime.now().add(_kFirstTokenTimeout);
  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 250));
    final String text = _streamedText($);
    if (text.length >= minChars) {
      _log('streaming confirmed (${text.length} chars)');
      return;
    }
  }
  fail(
    'The long turn never streamed $minChars chars within '
    '${_kFirstTokenTimeout.inMinutes} min, so the Stop step is unreachable. '
    'Last seen: "${_streamedText($)}"',
  );
}

/// Waits out a turn: first token, then commit (GemmaInputField unmounts and
/// the regular input field returns). Never throws - callers assert on the
/// result so failures carry timing diagnostics.
Future<_TurnResult> _awaitAssistantTurn(PatrolIntegrationTester $) async {
  final Stopwatch sw = Stopwatch()..start();
  Duration? firstTokenAfter;
  Duration? completedAfter;
  String lastSeen = '';

  bool committed() =>
      !$.tester.any(find.byType(GemmaInputField)) && _chatInputFieldPresent($);

  // Phase 1: first token (or an instantly committed short reply).
  while (sw.elapsed < _kFirstTokenTimeout) {
    await $.pump(const Duration(milliseconds: 250));
    final String text = _streamedText($);
    if (text.isNotEmpty) {
      lastSeen = text;
      firstTokenAfter = sw.elapsed;
      break;
    }
    if (committed()) {
      firstTokenAfter = sw.elapsed;
      completedAfter = sw.elapsed;
      break;
    }
  }
  if (firstTokenAfter == null) {
    return _TurnResult(
      tokensStarted: false,
      completed: false,
      lastSeenText: lastSeen,
      firstTokenAfter: null,
      completedAfter: null,
    );
  }

  // Phase 2: completion.
  if (completedAfter == null) {
    final Duration budget = _kFirstTokenTimeout + _kCompletionTimeout;
    while (sw.elapsed < budget) {
      await $.pump(const Duration(milliseconds: 250));
      final String text = _streamedText($);
      if (text.isNotEmpty) {
        lastSeen = text;
      }
      if (committed()) {
        completedAfter = sw.elapsed;
        break;
      }
    }
  }
  return _TurnResult(
    tokensStarted: true,
    completed: completedAfter != null,
    lastSeenText: lastSeen,
    firstTokenAfter: firstTokenAfter,
    completedAfter: completedAfter,
  );
}

Future<void> _pumpFor(PatrolIntegrationTester $, Duration duration) async {
  final DateTime deadline = DateTime.now().add(duration);
  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
  }
}

// --------------------------------------------------------------------------
// Diagnostics
// --------------------------------------------------------------------------

class _TurnResult {
  const _TurnResult({
    required this.tokensStarted,
    required this.completed,
    required this.lastSeenText,
    required this.firstTokenAfter,
    required this.completedAfter,
  });

  final bool tokensStarted;
  final bool completed;
  final String lastSeenText;
  final Duration? firstTokenAfter;
  final Duration? completedAfter;

  String describe() {
    final String preview = lastSeenText.length > 120
        ? '${lastSeenText.substring(0, 120)}(...)'
        : lastSeenText;
    return 'tokensStarted=$tokensStarted '
        '(after ${firstTokenAfter?.inMilliseconds}ms), '
        'completed=$completed (after ${completedAfter?.inMilliseconds}ms), '
        'streamed ${lastSeenText.length} chars: "$preview"';
  }
}

/// Timestamped so failures correlate with
/// `adb logcat -s flutter:V` (`time-to-first-chunk` lines).
void _log(String message) {
  debugPrint('[chat-stop-patrol +${_clock.elapsed}] $message');
}
