import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torch_light/torch_light.dart';

const String _kBluetoothSosMessage =
    'Broadcasting SOS over Bluetooth needs device-specific protocols '
    '(e.g. Aurora-style open signaling). This build only uses flashlight, '
    'screen, tone, and vibration — Bluetooth transmit is not active yet.';

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
  bool _surfaceLit = false;
  bool _torchReady = false;
  bool _running = true;
  bool _bluetoothAlert = false;
  bool _audioAlerts = true;
  bool _vibrationAlerts = true;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareTorch());
    unawaited(_runLoop());
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
    if (on && _audioAlerts) {
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
    if (on && _vibrationAlerts) {
      unawaited(HapticFeedback.mediumImpact());
    }
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

  Future<void> _stop() async {
    _running = false;
    await _pulseVisualAndTorch(false);
    await _setTorch(false);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _sosModalitiesDescription() {
    final List<String> parts = <String>['Screen flash', 'torch Morse'];
    if (_audioAlerts) {
      parts.add('alert tone');
    }
    if (_vibrationAlerts) {
      parts.add('vibration');
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
    unawaited(_setTorch(false));
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
                        onChanged: (bool v) => setState(() => _audioAlerts = v),
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
                              ? 'System tone with each flash (default)'
                              : 'No system tone with flashes',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      SwitchListTile.adaptive(
                        value: _vibrationAlerts,
                        onChanged: (bool v) =>
                            setState(() => _vibrationAlerts = v),
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
                              ? 'Haptic pulse with each flash (default)'
                              : 'No haptics',
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
