import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

const String _kBluetoothSosMessage =
    'Broadcasting SOS over Bluetooth needs device-specific protocols '
    '(e.g. Aurora-style open signaling). This build only uses flashlight, '
    'screen, tone, and vibration — Bluetooth transmit is not active yet.';

const String _kSosAlarmAsset = 'assets/sounds/sos_alarm_loop.wav';

/// Full-screen SOS: alternating screen flash + Morse SOS on torch + optional tone/haptics.
Future<void> openSosOverlay(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (BuildContext context, _, __) => const _SosOverlayPage(),
    ),
  );
}

class _SosOverlayPage extends StatefulWidget {
  const _SosOverlayPage();

  @override
  State<_SosOverlayPage> createState() => _SosOverlayPageState();
}

class _SosOverlayPageState extends State<_SosOverlayPage> {
  static const int _unitMs = 160;
  static const List<int> _kSosVibrationPattern = <int>[
    0,
    80,
    50,
    80,
    50,
    80,
    50,
    80,
    300,
  ];

  bool _surfaceLit = false;
  bool _torchReady = false;
  bool _running = true;
  bool _bluetoothAlert = false;
  bool _audioAlerts = true;
  bool _vibrationAlerts = true;

  AudioPlayer? _alarmPlayer;
  Timer? _hapticBurstTimer;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareTorch());
    unawaited(_runLoop());
    unawaited(_bootstrapAlarmAndVibration());
  }

  Future<void> _bootstrapAlarmAndVibration() async {
    await _ensureAlarmPlayer();
    if (mounted && _running && _audioAlerts) {
      unawaited(_playAlarmIfReady());
    }
    if (mounted && _running && _vibrationAlerts) {
      await _startSosVibration();
    }
  }

  Future<void> _ensureAlarmPlayer() async {
    if (_alarmPlayer != null) {
      return;
    }
    try {
      if (!kIsWeb) {
        final AudioSession session = await AudioSession.instance;
        await session.configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playback,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.sonification,
              usage: AndroidAudioUsage.alarm,
            ),
            androidAudioFocusGainType:
                AndroidAudioFocusGainType.gainTransientMayDuck,
          ),
        );
      }
      final AudioPlayer player = AudioPlayer();
      await player.setAsset(_kSosAlarmAsset);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(1);
      if (!mounted) {
        await player.dispose();
        return;
      }
      _alarmPlayer = player;
    } on Object {
      await _alarmPlayer?.dispose();
      _alarmPlayer = null;
      if (mounted && _audioAlerts) {
        unawaited(SystemSound.play(SystemSoundType.alert));
      }
    }
  }

  Future<void> _playAlarmIfReady() async {
    if (!_audioAlerts || !_running || !mounted) {
      return;
    }
    await _ensureAlarmPlayer();
    final AudioPlayer? player = _alarmPlayer;
    if (player == null) {
      return;
    }
    try {
      await player.seek(Duration.zero);
      await player.play();
    } on Object {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  Future<void> _pauseAlarm() async {
    try {
      await _alarmPlayer?.pause();
    } on Object {
      // ignore
    }
  }

  Future<void> _stopAlarm() async {
    try {
      await _alarmPlayer?.stop();
    } on Object {
      // ignore
    }
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

  Future<void> _dit() async {
    await _pulseVisualAndTorch(true);
    await Future<void>.delayed(const Duration(milliseconds: _unitMs));
    await _pulseVisualAndTorch(false);
    await Future<void>.delayed(const Duration(milliseconds: _unitMs));
  }

  Future<void> _dah() async {
    await _pulseVisualAndTorch(true);
    await Future<void>.delayed(const Duration(milliseconds: _unitMs * 3));
    await _pulseVisualAndTorch(false);
    await Future<void>.delayed(const Duration(milliseconds: _unitMs));
  }

  Future<void> _letterGap() async {
    await Future<void>.delayed(const Duration(milliseconds: _unitMs * 2));
  }

  Future<void> _wordGap() async {
    await Future<void>.delayed(const Duration(milliseconds: _unitMs * 4));
  }

  Future<void> _sendSosOnce() async {
    await _dit();
    await _dit();
    await _dit();
    await _letterGap();
    await _dah();
    await _dah();
    await _dah();
    await _letterGap();
    await _dit();
    await _dit();
    await _dit();
    await _wordGap();
  }

  Future<void> _runLoop() async {
    while (mounted && _running) {
      await _sendSosOnce();
    }
  }

  Future<void> _startSosVibration() async {
    if (!_vibrationAlerts || !mounted || !_running) {
      return;
    }
    try {
      final bool has = await Vibration.hasVibrator();
      if (!has) {
        _startHapticBurstTimer();
        return;
      }
      final bool custom = await Vibration.hasCustomVibrationsSupport();
      if (_isAndroid && custom) {
        await Vibration.vibrate(pattern: _kSosVibrationPattern, repeat: 1);
      } else {
        _startHapticBurstTimer();
      }
    } on Object {
      _startHapticBurstTimer();
    }
  }

  void _startHapticBurstTimer() {
    _hapticBurstTimer?.cancel();
    _hapticBurstTimer = Timer.periodic(const Duration(milliseconds: 360), (_) {
      if (!_running || !_vibrationAlerts || !mounted) {
        return;
      }
      unawaited(_fireHapticBurst());
    });
  }

  Future<void> _fireHapticBurst() async {
    for (int i = 0; i < 5; i++) {
      if (!_running || !_vibrationAlerts || !mounted) {
        return;
      }
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 36));
    }
  }

  Future<void> _stopSosVibration() async {
    _hapticBurstTimer?.cancel();
    _hapticBurstTimer = null;
    try {
      await Vibration.cancel();
    } on Object {
      // ignore
    }
  }

  Future<void> _stop() async {
    _running = false;
    await _stopSosVibration();
    await _stopAlarm();
    await _pulseVisualAndTorch(false);
    await _setTorch(false);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _sosModalitiesDescription() {
    final List<String> parts = <String>['Screen flash', 'torch Morse'];
    if (_audioAlerts) {
      parts.add('looping alarm tone');
    }
    if (_vibrationAlerts) {
      parts.add('repeating vibration');
    }
    final String core = parts.join(' + ');
    final List<String> off = <String>[];
    if (!_audioAlerts) {
      off.add('audio off');
    }
    if (!_vibrationAlerts) {
      off.add('vibration off');
    }
    final String suffix = off.isEmpty ? '' : ' (${off.join(', ')})';
    return '$core$suffix. Point lamp away from eyes.';
  }

  void _onBluetoothChanged(bool value) {
    setState(() => _bluetoothAlert = value);
    if (value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_kBluetoothSosMessage),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  void dispose() {
    _running = false;
    _hapticBurstTimer?.cancel();
    unawaited(_setTorch(false));
    unawaited(_stopSosVibration());
    final AudioPlayer? player = _alarmPlayer;
    _alarmPlayer = null;
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color fg =
        _surfaceLit ? Colors.black : Theme.of(context).colorScheme.surface;
    final Color bg = _surfaceLit ? Colors.white : Colors.black;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            color: bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.sos, size: 96, color: fg),
                    const SizedBox(height: 16),
                    Text(
                      'SOS — tap Stop',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _sosModalitiesDescription(),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: fg),
                      textAlign: TextAlign.center,
                    ),
                    if (_bluetoothAlert) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _kBluetoothSosMessage,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: fg),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        value: _bluetoothAlert,
                        onChanged: _onBluetoothChanged,
                        secondary: Icon(
                          Icons.bluetooth,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Bluetooth alert',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          _bluetoothAlert
                              ? 'Preference on — not transmitting in this build.'
                              : 'Off (default)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      SwitchListTile.adaptive(
                        value: _audioAlerts,
                        onChanged: (bool v) {
                          setState(() => _audioAlerts = v);
                          if (v) {
                            unawaited(_playAlarmIfReady());
                          } else {
                            unawaited(_pauseAlarm());
                          }
                        },
                        secondary: Icon(
                          Icons.volume_up_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Alert sound',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          _audioAlerts
                              ? 'Looping alarm tone (default)'
                              : 'Alarm tone off',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      SwitchListTile.adaptive(
                        value: _vibrationAlerts,
                        onChanged: (bool v) {
                          setState(() => _vibrationAlerts = v);
                          if (v) {
                            unawaited(_startSosVibration());
                          } else {
                            unawaited(_stopSosVibration());
                          }
                        },
                        secondary: Icon(
                          Icons.vibration,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          'Vibration',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          _vibrationAlerts
                              ? 'Repeating burst pattern (default)'
                              : 'Vibration off',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _stop,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Stop SOS'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
