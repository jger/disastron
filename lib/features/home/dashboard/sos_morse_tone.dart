import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// ITU-ish Morse tone frequencies (Hz).
const double kSosMorseDitHz = 1000;
const double kSosMorseDahHz = 650;

/// SoLoud sine waveform for SOS Morse (no WAV). Init once per overlay; tear down in dispose.
final class SosMorseTone {
  bool _ready = false;
  AudioSource? _sine;
  SoundHandle? _handle;

  bool get isReady => _ready;

  Future<void> ensureReady() async {
    if (_ready) {
      return;
    }
    try {
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          bufferSize: 1024,
          channels: Channels.mono,
        );
      }
      _sine = await SoLoud.instance.loadWaveform(
        WaveForm.sin,
        false,
        0.22,
        0,
      );
      SoLoud.instance.setWaveformFreq(_sine!, kSosMorseDitHz);
      _ready = true;
    } on Object {
      _sine = null;
      _ready = false;
    }
  }

  /// Fire-and-forget start; pairs with [stop] after the mark duration.
  void start(double frequencyHz) {
    if (!_ready || _sine == null) {
      return;
    }
    try {
      SoLoud.instance.setWaveformFreq(_sine!, frequencyHz);
      _handle = SoLoud.instance.play(
        _sine!,
        volume: 0.45,
        looping: true,
      );
    } on Object {
      _handle = null;
      unawaited(SystemSound.play(SystemSoundType.alert));
    }
  }

  Future<void> stop() async {
    final SoundHandle? h = _handle;
    _handle = null;
    if (h == null) {
      return;
    }
    try {
      await SoLoud.instance.stop(h);
    } on Object {
      // ignore
    }
  }

  Future<void> dispose() async {
    await stop();
    final AudioSource? s = _sine;
    _sine = null;
    _ready = false;
    if (s != null && SoLoud.instance.isInitialized) {
      try {
        await SoLoud.instance.disposeSource(s);
      } on Object {
        // ignore
      }
    }
    if (SoLoud.instance.isInitialized) {
      try {
        SoLoud.instance.deinit();
      } on Object {
        // ignore
      }
    }
  }
}
