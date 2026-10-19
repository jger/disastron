// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:io';

import 'package:disastron/features/chat/presentation/widgets/chat_input_field.dart';
import 'package:disastron/features/chat/presentation/widgets/chat_message.dart';
import 'package:disastron/features/chat/presentation/widgets/gemma_input_field.dart';
import 'package:disastron/features/inference/data/model_registry_store.dart';
import 'package:disastron/features/inference/presentation/model_install_orchestrator.dart';
import 'package:disastron/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:permission_handler/permission_handler.dart';

const Duration kPatrolFirstTokenTimeout = Duration(minutes: 2);
const Duration kPatrolCompletionTimeout = Duration(minutes: 5);

const List<String> kPatrolModelFileExtensions = <String>[
  '.litertlm',
  '.task',
  '.bin',
];

final Stopwatch _patrolBootClock = Stopwatch()..start();

Future<void> bootIntoPatrolChat(
  PatrolIntegrationTester $, {
  String logTag = 'patrol-chat',
}) async {
  patrolChatLog('launching app', logTag: logTag);
  await app.main();
  await $.pump(const Duration(seconds: 1));
  await grantNativePermissionIfAskedPatrol($, logTag: logTag);
  await completeFirstRunDialogsIfAnyPatrol($, logTag: logTag);
  await grantNativePermissionIfAskedPatrol($, logTag: logTag);
  await ensurePatrolModelActive($, logTag: logTag);
  patrolChatLog('model active; opening chat tab', logTag: logTag);
  await $(Icons.smart_toy_outlined).tap();
  await waitForPatrolChatReady($, logTag: logTag);
  patrolChatLog('chat ready', logTag: logTag);
}

Future<void> grantNativePermissionIfAskedPatrol(
  PatrolIntegrationTester $, {
  String logTag = 'patrol-chat',
}) async {
  final PermissionStatus status = await Permission.locationWhenInUse.status;
  if (status.isGranted) {
    return;
  }
  try {
    await $.platformAutomator.mobile.grantPermissionWhenInUse();
    patrolChatLog('granted a native permission dialog', logTag: logTag);
  } on Object catch (e) {
    patrolChatLog(
      'no native permission dialog handled (${e.runtimeType})',
      logTag: logTag,
    );
  }
}

Future<void> completeFirstRunDialogsIfAnyPatrol(
  PatrolIntegrationTester $, {
  String logTag = 'patrol-chat',
}) async {
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
      patrolChatLog('accepting terms dialog', logTag: logTag);
      await $(CheckboxListTile).tap(settlePolicy: SettlePolicy.trySettle);
      await $(AlertDialog)
          .$(FilledButton)
          .tap(settlePolicy: SettlePolicy.trySettle);
    } else {
      patrolChatLog('confirming first-run (language) dialog', logTag: logTag);
      await $(AlertDialog)
          .$(FilledButton)
          .tap(settlePolicy: SettlePolicy.trySettle);
    }
  }
}

Future<void> ensurePatrolModelActive(
  PatrolIntegrationTester $, {
  String logTag = 'patrol-chat',
}) async {
  final ModelRegistryStore store = ModelRegistryStore();
  await store.migrateFromLegacyIfNeeded();
  final ModelRegistrySnapshot snap = await store.readSnapshot();
  final bool restoreExpected = snap.activeEntryId != null;
  final Duration restoreWait = restoreExpected
      ? const Duration(minutes: 3)
      : const Duration(seconds: 10);
  final DateTime deadline = DateTime.now().add(restoreWait);
  while (!FlutterEdgeAi.hasActiveModel() && DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
  }
  if (FlutterEdgeAi.hasActiveModel()) {
    return;
  }

  final File? seed = await findPatrolSeedModelFile();
  if (seed == null) {
    fail(
      'No active model and no seed file on the device. Run '
      '`make patrol-prepare` once, then re-run this test.',
    );
  }
  patrolChatLog('installing model from seed ${seed.path}', logTag: logTag);
  await ModelInstallOrchestrator(registry: ModelRegistryStore())
      .installFromFile(seed.path);
  expect(FlutterEdgeAi.hasActiveModel(), isTrue);
}

Future<File?> findPatrolSeedModelFile() async {
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
    final List<File> candidates =
        dir
            .listSync()
            .whereType<File>()
            .where(
              (File f) => kPatrolModelFileExtensions.any(
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

Future<void> waitForPatrolChatReady(
  PatrolIntegrationTester $, {
  String logTag = 'patrol-chat',
}) async {
  const Duration budget = Duration(minutes: 12);
  final DateTime deadline = DateTime.now().add(budget);
  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 500));
    if (patrolChatInputFieldPresent($) ||
        $.tester.any(find.text('Vehicle crash'))) {
      patrolChatLog('chat UI ready (input or accident chips)', logTag: logTag);
      return;
    }
    final Finder checkAgain = find.widgetWithText(FilledButton, 'Check again');
    if ($.tester.any(checkAgain)) {
      patrolChatLog('tapping Check again', logTag: logTag);
      await $.tester.tap(checkAgain);
      await $.pump(const Duration(seconds: 2));
    }
    if ($.tester.any(find.textContaining('Chat init failed'))) {
      fail('Chat init failed on device — see on-screen error text.');
    }
    if ($.tester.any(find.textContaining('Starting offline assistant'))) {
      patrolChatLog('still loading chat session…', logTag: logTag);
    }
  }
  fail(
    'Chat did not become ready within ${budget.inMinutes} minutes '
    '(expected ChatInputField or Vehicle crash chip). '
    'Run `make patrol-prepare DEVICE=emulator-5554` if the model was never seeded.',
  );
}

bool patrolChatInputFieldPresent(PatrolIntegrationTester $) => $.tester.any(
  find.descendant(
    of: find.byType(ChatInputField),
    matching: find.byType(TextField),
  ),
);

String patrolStreamedAssistantText(PatrolIntegrationTester $) {
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

Future<PatrolAssistantTurnResult> awaitPatrolAssistantTurn(
  PatrolIntegrationTester $,
) async {
  final Stopwatch sw = Stopwatch()..start();
  Duration? firstTokenAfter;
  Duration? completedAfter;
  String lastSeen = '';

  bool committed() =>
      !$.tester.any(find.byType(GemmaInputField)) &&
      patrolChatInputFieldPresent($);

  while (sw.elapsed < kPatrolFirstTokenTimeout) {
    await $.pump(const Duration(milliseconds: 250));
    final String text = patrolStreamedAssistantText($);
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
    return PatrolAssistantTurnResult(
      tokensStarted: false,
      completed: false,
      lastSeenText: lastSeen,
    );
  }

  if (completedAfter == null) {
    final Duration budget = kPatrolFirstTokenTimeout + kPatrolCompletionTimeout;
    while (sw.elapsed < budget) {
      await $.pump(const Duration(milliseconds: 250));
      final String text = patrolStreamedAssistantText($);
      if (text.isNotEmpty) {
        lastSeen = text;
      }
      if (committed()) {
        completedAfter = sw.elapsed;
        break;
      }
    }
  }
  return PatrolAssistantTurnResult(
    tokensStarted: true,
    completed: completedAfter != null,
    lastSeenText: lastSeen,
    firstTokenAfter: firstTokenAfter,
    completedAfter: completedAfter,
  );
}

class PatrolAssistantTurnResult {
  const PatrolAssistantTurnResult({
    required this.tokensStarted,
    required this.completed,
    required this.lastSeenText,
    this.firstTokenAfter,
    this.completedAfter,
  });

  final bool tokensStarted;
  final bool completed;
  final String lastSeenText;
  final Duration? firstTokenAfter;
  final Duration? completedAfter;

  String describe() =>
      'tokensStarted=$tokensStarted, completed=$completed, '
      'chars=${lastSeenText.length}';
}

void patrolChatLog(String message, {String logTag = 'patrol-chat'}) {
  debugPrint('[$logTag +${_patrolBootClock.elapsed}] $message');
}
