import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// In-memory procedural audio synthesizer producing 16-bit PCM WAV byte buffers.
/// Requires 0 external audio files (.mp3, .wav, etc.).
class ProceduralAudioSynth {
  static final ProceduralAudioSynth instance = ProceduralAudioSynth._internal();
  ProceduralAudioSynth._internal();

  static const int sampleRate = 44100;

  /// Notified whenever [soundEnabled] changes, so menu quick-mute and the
  /// settings-sheet switch can share one live source of truth.
  static final ValueNotifier<bool> soundEnabledState = ValueNotifier<bool>(
    true,
  );

  late final Uint8List tapWav;
  late final Uint8List nearMissWav;
  late final Uint8List swapTickWav;
  late final Uint8List swapExecuteWav;
  late final Uint8List deathShatterWav;
  late final Uint8List chargeHumWav;
  late final Uint8List warpWav;
  late final Uint8List shieldPingWav;
  late final Uint8List phaseAbsorbWav;

  AudioPlayer? _sfxPlayer1;
  AudioPlayer? _sfxPlayer2;
  AudioPlayer? _deathPlayer;
  bool _playerToggle = false;
  bool _buffersReady = false;
  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;
  set soundEnabled(bool value) {
    _soundEnabled = value;
    soundEnabledState.value = value;
  }

  Future<void> init() async {
    if (!_buffersReady) {
      // Synthesize all audio buffers in memory (< 15ms total CPU time)
      tapWav = _generateTapWav();
      nearMissWav = _generateNearMissWav();
      swapTickWav = _generateSwapTickWav();
      swapExecuteWav = _generateSwapExecuteWav();
      deathShatterWav = _generateDeathShatterWav();
      chargeHumWav = _generateChargeHumWav();
      warpWav = _generateWarpWav();
      shieldPingWav = _generateShieldPingWav();
      phaseAbsorbWav = _generatePhaseAbsorbWav();
      _buffersReady = true;
    }

    if (soundEnabled) {
      await _ensurePlayers();
    }
  }

  Future<void> _ensurePlayers() async {
    if (_sfxPlayer1 != null && _sfxPlayer2 != null && _deathPlayer != null) {
      return;
    }
    try {
      _sfxPlayer1 ??= AudioPlayer();
      _sfxPlayer2 ??= AudioPlayer();
      _deathPlayer ??= AudioPlayer();
      await _sfxPlayer1?.setReleaseMode(ReleaseMode.stop);
      await _sfxPlayer2?.setReleaseMode(ReleaseMode.stop);
      await _deathPlayer?.setReleaseMode(ReleaseMode.stop);
    } catch (_) {
      // Audio is a nice-to-have; never let a platform failure break gameplay.
    }
  }

  /// Enables or disables all sound. Turning sound back on lazily rebuilds the
  /// native players if they were released when the game view was destroyed.
  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    if (enabled) {
      await init();
    }
  }

  bool get _ready => soundEnabled && _buffersReady && _sfxPlayer1 != null;

  int _lastTapTime = 0;
  void playTap() {
    if (!_ready) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapTime < 80) return;
    _lastTapTime = now;
    _playOnAvailablePlayer(tapWav, volume: 0.7);
  }

  void playNearMiss() {
    if (!_ready) return;
    _playOnAvailablePlayer(nearMissWav, volume: 0.9);
  }

  void playSwapTick({bool isFinal = false}) {
    if (!_ready) return;
    _playOnAvailablePlayer(swapTickWav, volume: 0.85);
  }

  void playSwapExecute() {
    if (!_ready) return;
    _playOnAvailablePlayer(swapExecuteWav, volume: 1.0);
  }

  void playDeath() {
    if (!_ready) return;
    try {
      _deathPlayer?.stop().catchError((_) {});
      _deathPlayer
          ?.play(BytesSource(deathShatterWav), volume: 1.0)
          .catchError((_) {});
    } catch (_) {}
  }

  void playChargeHum() {
    if (!_ready) return;
    _playOnAvailablePlayer(chargeHumWav, volume: 0.5);
  }

  void playWarp() {
    if (!_ready) return;
    _playOnAvailablePlayer(warpWav, volume: 0.75);
  }

  void playShieldPing() {
    if (!_ready) return;
    _playOnAvailablePlayer(shieldPingWav, volume: 0.85);
  }

  void playPhaseAbsorb() {
    if (!_ready) return;
    _playOnAvailablePlayer(phaseAbsorbWav, volume: 0.80);
  }

  void _playOnAvailablePlayer(Uint8List wavBytes, {double volume = 1.0}) {
    try {
      final player = _playerToggle ? _sfxPlayer1 : _sfxPlayer2;
      _playerToggle = !_playerToggle;
      player?.stop().catchError((_) {});
      player?.play(BytesSource(wavBytes), volume: volume).catchError((_) {});
    } catch (_) {}
  }

  // --- PROCEDURAL WAVEFORM GENERATORS ---

  /// Thumb Tap: 85ms sine sweep from 280Hz -> 580Hz with exponential amplitude decay e^(-25t).
  Uint8List _generateTapWav() {
    const double duration = 0.085;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 280.0 + (580.0 - 280.0) * (t / duration);
      final double amp = math.exp(-25.0 * t);
      samples[i] = math.sin(2.0 * math.pi * freq * t) * amp;
    }

    return buildWavBytes(samples);
  }

  /// Near-Miss Whoosh: 110ms bandpass-filtered noise + 880Hz chime ping.
  Uint8List _generateNearMissWav() {
    const double duration = 0.110;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);
    final math.Random rng = math.Random(42);

    double filterState = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double rawNoise = rng.nextDouble() * 2.0 - 1.0;
      // Simple one-pole bandpass/lowpass simulation
      filterState += 0.25 * (rawNoise - filterState);

      final double chime =
          math.sin(2.0 * math.pi * 880.0 * t) * math.exp(-35.0 * t);
      final double whoosh =
          filterState * math.sin(math.pi * (t / duration)) * 0.7;

      samples[i] = (chime * 0.6 + whoosh * 0.4);
    }

    return buildWavBytes(samples);
  }

  /// Swap Warning Tick: 50ms square wave at 1200Hz.
  Uint8List _generateSwapTickWav() {
    const double duration = 0.050;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double phase = (t * 1200.0) % 1.0;
      final double square = phase < 0.5 ? 0.7 : -0.7;
      final double env = math.exp(-40.0 * t);
      samples[i] = square * env;
    }

    return buildWavBytes(samples);
  }

  /// Swap Execute Thud: 120ms punchy pitch drop 180Hz -> 50Hz.
  Uint8List _generateSwapExecuteWav() {
    const double duration = 0.120;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 180.0 * math.exp(-14.0 * t) + 50.0;
      final double env = math.exp(-18.0 * t);
      samples[i] = math.sin(2.0 * math.pi * freq * t) * env;
    }

    return buildWavBytes(samples);
  }

  /// Death Shatter: 450ms layered low-frequency square wave (90Hz -> 30Hz) mixed with noise burst.
  Uint8List _generateDeathShatterWav() {
    const double duration = 0.450;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);
    final math.Random rng = math.Random(1337);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 90.0 - 60.0 * (t / duration);
      final double phase = (t * freq) % 1.0;
      final double square = phase < 0.5 ? 0.8 : -0.8;
      final double noise = (rng.nextDouble() * 2.0 - 1.0) * math.exp(-8.0 * t);
      final double env = math.exp(-6.5 * t);

      samples[i] = (square * 0.5 + noise * 0.5) * env;
    }

    return buildWavBytes(samples);
  }

  /// Biometric Charge Hum: 800ms rising harmonic hum.
  Uint8List _generateChargeHumWav() {
    const double duration = 0.800;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 120.0 + 260.0 * (t / duration);
      final double env =
          math.min(1.0, t / 0.1) * (1.0 - math.exp(-5.0 * (duration - t)));
      final double osc1 = math.sin(2.0 * math.pi * freq * t);
      final double osc2 = math.sin(2.0 * math.pi * (freq * 1.5) * t) * 0.5;

      samples[i] = (osc1 + osc2) * 0.5 * env;
    }

    return buildWavBytes(samples);
  }

  /// Quantum Warp: 95ms rapid high-frequency upward chirp (440Hz -> 1320Hz)
  Uint8List _generateWarpWav() {
    const double duration = 0.095;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 440.0 + 880.0 * (t / duration);
      final double env = math.exp(-18.0 * t);
      samples[i] = math.sin(2.0 * math.pi * freq * t) * env;
    }

    return buildWavBytes(samples);
  }

  /// Shield Ping: 120ms crystalline pure chime harmonic at 1760Hz
  Uint8List _generateShieldPingWav() {
    const double duration = 0.120;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double chime1 = math.sin(2.0 * math.pi * 1760.0 * t);
      final double chime2 = math.sin(2.0 * math.pi * 3520.0 * t) * 0.35;
      final double env = math.exp(-32.0 * t);
      samples[i] = (chime1 + chime2) * 0.7 * env;
    }

    return buildWavBytes(samples);
  }

  /// Phase Absorb: 100ms resonant electric synth bubble pop (520Hz -> 780Hz -> 390Hz)
  Uint8List _generatePhaseAbsorbWav() {
    const double duration = 0.100;
    final int numSamples = (sampleRate * duration).toInt();
    final List<double> samples = List.filled(numSamples, 0.0);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double freq = 520.0 + 260.0 * math.sin(math.pi * (t / duration));
      final double env = math.exp(-22.0 * t);
      samples[i] = math.sin(2.0 * math.pi * freq * t) * env;
    }

    return buildWavBytes(samples);
  }

  /// Encodes a normalized sample list [-1.0, 1.0] into a valid 16-bit mono PCM RIFF/WAVE header and data block.
  static Uint8List buildWavBytes(
    List<double> samples, {
    int sampleRate = 44100,
  }) {
    final int numSamples = samples.length;
    final int byteRate =
        sampleRate * 2; // 16 bits = 2 bytes per sample, 1 channel
    final int dataSize = numSamples * 2;
    final int totalSize = 36 + dataSize;

    final ByteData byteData = ByteData(44 + dataSize);

    // ChunkID "RIFF"
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'

    // ChunkSize
    byteData.setUint32(4, totalSize, Endian.little);

    // Format "WAVE"
    byteData.setUint8(8, 0x57); // 'W'
    byteData.setUint8(9, 0x41); // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'

    // Subchunk1ID "fmt "
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '

    // Subchunk1Size (16 for PCM)
    byteData.setUint32(16, 16, Endian.little);
    // AudioFormat (1 for PCM)
    byteData.setUint16(20, 1, Endian.little);
    // NumChannels (1 mono)
    byteData.setUint16(22, 1, Endian.little);
    // SampleRate
    byteData.setUint32(24, sampleRate, Endian.little);
    // ByteRate
    byteData.setUint32(28, byteRate, Endian.little);
    // BlockAlign (2 bytes)
    byteData.setUint16(32, 2, Endian.little);
    // BitsPerSample (16 bits)
    byteData.setUint16(34, 16, Endian.little);

    // Subchunk2ID "data"
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'

    // Subchunk2Size
    byteData.setUint32(40, dataSize, Endian.little);

    // Write PCM 16-bit Little-Endian audio samples
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final double clamped = samples[i].clamp(-1.0, 1.0);
      final int intSample = (clamped * 32767.0).toInt();
      byteData.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  /// Disposes the native players but keeps the synthesised buffers so a later
  /// [init] can rebuild playback without re-synthesising.
  Future<void> releasePlayers() async {
    final AudioPlayer? p1 = _sfxPlayer1;
    final AudioPlayer? p2 = _sfxPlayer2;
    final AudioPlayer? death = _deathPlayer;
    _sfxPlayer1 = null;
    _sfxPlayer2 = null;
    _deathPlayer = null;
    try {
      await p1?.dispose();
      await p2?.dispose();
      await death?.dispose();
    } catch (_) {
      // Nothing to recover from: the players are already gone.
    }
  }

  void dispose() {
    releasePlayers();
  }
}
