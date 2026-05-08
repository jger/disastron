import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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

  static int _mobileAudioSessionHolders = 0;
  static AudioSessionConfiguration? _mobileAudioSessionBackup;

  static const AudioSessionConfiguration _sosSession =
      AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions:
        AVAudioSessionCategoryOptions.defaultToSpeaker,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.sonification,
      usage: AndroidAudioUsage.alarm,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientExclusive,
  );

  Future<void> _prepareMobileAudioSession() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    try {
      final AudioSession session = await AudioSession.instance;
      if (_mobileAudioSessionHolders == 0) {
        _mobileAudioSessionBackup = session.configuration;
        await session.configure(_sosSession);
        await session.setActive(
          true,
          fallbackConfiguration: _sosSession,
        );
      }
      _mobileAudioSessionHolders++;
    } on Object {
      // ignore — SoLoud still runs with default session
    }
  }

  Future<void> _restoreMobileAudioSession() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    try {
      if (_mobileAudioSessionHolders <= 0) {
        return;
      }
      _mobileAudioSessionHolders--;
      if (_mobileAudioSessionHolders > 0) {
        return;
      }
      final AudioSession session = await AudioSession.instance;
      final AudioSessionConfiguration? prev = _mobileAudioSessionBackup;
      _mobileAudioSessionBackup = null;
      if (prev != null) {
        await session.configure(prev);
      } else {
        await session.configure(const AudioSessionConfiguration.music());
      }
      await session.setActive(false);
    } on Object {
      // ignore
    }
  }

  Future<void> ensureReady() async {
    if (_ready) {
      return;
    }
    try {
      await _prepareMobileAudioSession();
      if (!SoLoud.instance.isInitialized) {
        await SoLoud.instance.init(
          bufferSize: 4096,
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
      await _restoreMobileAudioSession();
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
    await _restoreMobileAudioSession();
  }
}
