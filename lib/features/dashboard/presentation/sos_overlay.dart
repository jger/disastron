import 'dart:async';

import 'package:disastron/features/dashboard/domain/sos_morse_codec.dart';
import 'package:disastron/features/dashboard/presentation/sos_morse_tone.dart';
import 'package:disastron/features/dashboard/presentation/widgets/sos_morse_display.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

List<SosMorseToken> _sosBuildSequenceForCompute(String raw) {
  return buildSosMorseSequence(raw);
}

/// Full-screen SOS / Morse: torch + screen + optional tone/vibration; editable message.
Future<void> openSosOverlay(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (BuildContext context, _, __) => const _SosOverlayPage(),
    ),
  );
}

class _MorseCapsFormatter extends TextInputFormatter {
  static const int kMaxLen = 30;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String upper = newValue.text.toUpperCase();
    final StringBuffer buf = StringBuffer();
    for (final int r in upper.runes) {
      final String ch = String.fromCharCode(r);
      if (RegExp('[A-Z0-9 ]').hasMatch(ch)) {
        buf.write(ch);
      }
    }
    String t = buf.toString();
    if (t.length > kMaxLen) {
      t = t.substring(0, kMaxLen);
    }
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class _SosOverlayPage extends StatefulWidget {
  const _SosOverlayPage();

  @override
  State<_SosOverlayPage> createState() => _SosOverlayPageState();
}

class _SosOverlayPageState extends State<_SosOverlayPage> {
  /// Slider 0 = slow ([kSosMorseUnitMsSlow] ms dit), 1 = fast (dit floored).
  double _speed = 0.5;

  int get _unitMs => (kSosMorseUnitMsSlow -
          _speed * (kSosMorseUnitMsSlow - kSosMorseUnitMsFastFloor))
      .round();

  late final TextEditingController _msgController;

  List<SosMorseToken> _sequence = <SosMorseToken>[];
  int _tokenIndex = 0;

  bool _transmitting = false;
  bool _paused = false;

  bool _surfaceLit = false;
  bool _torchReady = false;
  bool _bluetoothAlert = false;
  bool _audioAlerts = true;
  bool _lightAlerts = true;
  bool _vibrationAlerts = true;

  final SosMorseTone _morseTone = SosMorseTone();

  /// Invalidates in-flight [compute] results after dispose or rapid edits.
  int _sequenceBuildTicket = 0;

  @override
  void initState() {
    super.initState();
    _msgController = TextEditingController(text: 'SOS');
    _sequence = buildSosMorseSequence(_msgController.text);
    unawaited(_prepareTorch());
    unawaited(_morseTone.ensureReady());
    _transmitting = true;
    unawaited(_runLoop());
  }

  @override
  void dispose() {
    _sequenceBuildTicket++;
    _transmitting = false;
    _paused = false;
    _msgController.dispose();
    unawaited(_setTorch(false));
    unawaited(_stopSosVibration());
    unawaited(_morseTone.dispose());
    super.dispose();
  }

  Future<void> _prepareTorch() async {
    try {
      _torchReady = await TorchLight.isTorchAvailable();
    } on Object {
      _torchReady = false;
    }
  }

  Future<void> _setTorch(bool on) async {
    if (!_torchReady) {
      return;
    }
    try {
      if (on) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } on Object {
      // ignore hardware errors
    }
  }

  Future<void> _pulseVisualAndTorch(bool on) async {
    if (!mounted) {
      return;
    }
    setState(() => _surfaceLit = on);
    await _setTorch(on);
  }

  Future<void> _delayWithPause(Duration total) async {
    int left = total.inMilliseconds;
    while (left > 0) {
      if (!mounted || !_transmitting) {
        return;
      }
      while (_paused && _transmitting && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted || !_transmitting) {
        return;
      }
      final int step = left > 50 ? 50 : left;
      await Future<void>.delayed(Duration(milliseconds: step));
      left -= step;
    }
  }

  /// SoLoud sine + optional torch + screen: one [markMs] hold.
  Future<void> _morsePulse(int markMs, {required bool isDit}) async {
    if (!mounted || !_transmitting) {
      return;
    }
    final double hz = isDit ? kSosMorseDitHz : kSosMorseDahHz;
    try {
      if (_audioAlerts) {
        _morseTone.start(hz);
      }
      if (!mounted || !_transmitting) {
        return;
      }
      if (_lightAlerts) {
        setState(() => _surfaceLit = true);
        await _setTorch(true);
      }
      await Future.wait<void>(<Future<void>>[
        Future<void>.delayed(Duration(milliseconds: markMs)),
        _morseVibrationFor(markMs),
      ]);
    } on Object {
      // ignore
    } finally {
      if (_audioAlerts) {
        await _morseTone.stop();
      }
      try {
        await Vibration.cancel();
      } on Object {
        // ignore
      }
    }
    if (!mounted || !_transmitting) {
      return;
    }
    setState(() => _surfaceLit = false);
    await _setTorch(false);
  }

  Future<void> _morseVibrationFor(int onMs) async {
    if (!_vibrationAlerts || !_transmitting || !mounted || onMs <= 0) {
      return;
    }
    try {
      final bool has = await Vibration.hasVibrator();
      if (!has) {
        await _hapticMorseWindow(onMs);
        return;
      }
      final bool custom = await Vibration.hasCustomVibrationsSupport();
      if (custom) {
        await Vibration.vibrate(duration: onMs);
        await Future<void>.delayed(Duration(milliseconds: onMs));
      } else {
        await _hapticMorseWindow(onMs);
      }
    } on Object {
      await _hapticMorseWindow(onMs);
    }
  }

  Future<void> _hapticMorseWindow(int onMs) async {
    if (!_vibrationAlerts || !_transmitting || !mounted || onMs <= 0) {
      return;
    }
    final int end = DateTime.now().millisecondsSinceEpoch + onMs;
    while (mounted &&
        _transmitting &&
        _vibrationAlerts &&
        DateTime.now().millisecondsSinceEpoch < end) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 42));
    }
  }

  Future<void> _executeToken(SosMorseToken t) async {
    final int u = _unitMs;
    switch (t.type) {
      case SosMorseTokenType.dit:
        await _morsePulse(u, isDit: true);
      case SosMorseTokenType.dah:
        await _morsePulse(u * 3, isDit: false);
      case SosMorseTokenType.symbolGap:
        await _delayWithPause(Duration(milliseconds: u));
      case SosMorseTokenType.letterGap:
        await _delayWithPause(Duration(milliseconds: u * 3));
      case SosMorseTokenType.wordGap:
        await _delayWithPause(Duration(milliseconds: u * 7));
    }
  }

  Future<void> _runLoop() async {
    while (mounted && _transmitting) {
      if (_sequence.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        continue;
      }
      while (_paused && _transmitting && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!mounted || !_transmitting) {
        break;
      }

      setState(() {});
      await _executeToken(_sequence[_tokenIndex]);

      if (!mounted || !_transmitting) {
        break;
      }
      final int prevIndex = _tokenIndex;
      setState(() {
        _tokenIndex = (_tokenIndex + 1) % _sequence.length;
      });
      if (_tokenIndex == 0 &&
          _sequence.isNotEmpty &&
          prevIndex == _sequence.length - 1) {
        final int gapMs = (_unitMs * 12).clamp(650, 3200);
        await _delayWithPause(Duration(milliseconds: gapMs));
      }
    }
  }

  Future<void> _stopSosVibration() async {
    try {
      await Vibration.cancel();
    } on Object {
      // ignore
    }
  }

  Future<void> _silenceHardware() async {
    await _stopSosVibration();
    await _morseTone.stop();
    await _pulseVisualAndTorch(false);
    await _setTorch(false);
  }

  void _stopTransmit() {
    setState(() {
      _transmitting = false;
      _paused = false;
      _tokenIndex = 0;
    });
    unawaited(_silenceHardware());
  }

  void _startTransmit() {
    if (_sequence.isEmpty) {
      return;
    }
    setState(() {
      _transmitting = true;
      _paused = false;
      _tokenIndex = 0;
    });
    unawaited(_runLoop());
  }

  void _pauseTransmit() {
    setState(() => _paused = true);
  }

  void _resumeTransmit() {
    setState(() => _paused = false);
  }

  Future<void> _closeOverlay() async {
    setState(() {
      _transmitting = false;
      _paused = false;
    });
    await _silenceHardware();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onMessageChanged(String _) {
    final int ticket = ++_sequenceBuildTicket;
    unawaited(_applyComputedSequence(ticket));
  }

  Future<void> _applyComputedSequence(int ticket) async {
    final String text = _msgController.text;
    final List<SosMorseToken> seq =
        await compute(_sosBuildSequenceForCompute, text);
    if (!mounted || ticket != _sequenceBuildTicket) {
      return;
    }
    if (_msgController.text != text) {
      return;
    }
    setState(() {
      _sequence = seq;
      _tokenIndex = 0;
    });
  }

  void _onBluetoothChanged(bool value) {
    setState(() => _bluetoothAlert = value);
    if (value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sos_bluetooth_message'.tr()),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color fg =
        _surfaceLit ? Colors.black : Theme.of(context).colorScheme.surface;
    final Color bg = _surfaceLit ? Colors.white : Colors.black;
    final int wpm = _unitMs > 0 ? (1200 / _unitMs).round() : 0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            color: bg,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 280),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.sos, size: 72, color: fg),
                  const SizedBox(height: 12),
                  Text(
                    'sos_title'.tr(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: scheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'sos_morse_heading'.tr(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 56,
                          child: SosMorseDisplay(
                            messageUpper: _msgController.text.toUpperCase(),
                            sequence: _sequence,
                            tokenIndex: _tokenIndex,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _msgController,
                          maxLength: _MorseCapsFormatter.kMaxLen,
                          inputFormatters: <TextInputFormatter>[
                            _MorseCapsFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: 'sos_message_label'.tr(),
                            counterText:
                                '${_msgController.text.length}/${_MorseCapsFormatter.kMaxLen}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                          onChanged: _onMessageChanged,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Text(
                              'sos_speed'.tr(),
                              style: theme.textTheme.labelLarge,
                            ),
                            Expanded(
                              child: Slider(
                                value: _speed,
                                divisions: 20,
                                label: 'sos_wpm'.tr(
                                  namedArgs: <String, String>{'wpm': '$wpm'},
                                ),
                                onChanged: (double v) =>
                                    setState(() => _speed = v),
                              ),
                            ),
                            Text(
                              '~$wpm',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            FilterChip(
                              label: Text('sos_bt'.tr()),
                              selected: _bluetoothAlert,
                              onSelected: _onBluetoothChanged,
                            ),
                            FilterChip(
                              label: Text('sos_audio'.tr()),
                              selected: _audioAlerts,
                              onSelected: (bool v) {
                                setState(() => _audioAlerts = v);
                                if (v) {
                                  unawaited(_morseTone.ensureReady());
                                } else {
                                  unawaited(_morseTone.stop());
                                }
                              },
                            ),
                            FilterChip(
                              label: Text('sos_light'.tr()),
                              selected: _lightAlerts,
                              onSelected: (bool v) {
                                setState(() {
                                  _lightAlerts = v;
                                  if (!v) {
                                    _surfaceLit = false;
                                  }
                                });
                                if (!v) {
                                  unawaited(_setTorch(false));
                                }
                              },
                            ),
                            FilterChip(
                              label: Text('sos_vibe'.tr()),
                              selected: _vibrationAlerts,
                              onSelected: (bool v) {
                                setState(() => _vibrationAlerts = v);
                                if (!v) {
                                  unawaited(_stopSosVibration());
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_transmitting && !_paused)
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _pauseTransmit,
                                  child: Text('sos_pause'.tr()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: _stopTransmit,
                                  child: Text('sos_stop'.tr()),
                                ),
                              ),
                            ],
                          )
                        else if (_transmitting && _paused)
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: FilledButton(
                                  onPressed: _resumeTransmit,
                                  child: Text('sos_resume'.tr()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: _stopTransmit,
                                  child: Text('sos_stop'.tr()),
                                ),
                              ),
                            ],
                          )
                        else
                          FilledButton(
                            onPressed:
                                _sequence.isEmpty ? null : _startTransmit,
                            child: Text('sos_start'.tr()),
                          ),
                        TextButton(
                          onPressed: () => unawaited(_closeOverlay()),
                          child: Text('sos_close'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
