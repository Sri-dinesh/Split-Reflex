import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'haptic_choreographer.dart';
import 'procedural_audio_synth.dart';

/// Lightweight, failure-tolerant wrapper around [SharedPreferences].
///
/// Everything the app persists lives on-device only. There is no account, no
/// analytics and no network sync, so nothing here is personally identifiable.
class PreferencesService {
  static final PreferencesService instance = PreferencesService._internal();
  PreferencesService._internal();

  static const String _kSoundEnabled = 'pref_sound_enabled';
  static const String _kHapticsEnabled = 'pref_haptics_enabled';
  static const String _kTheme = 'pref_theme';
  static const String _kControlMode = 'pref_control_mode';
  static const String _kPlayMode = 'pref_play_mode';
  static const String _kSessionMode = 'pref_session_mode';
  static const String _kPairMode = 'pref_pair_mode';

  SharedPreferences? _prefs;

  bool get isReady => _prefs != null;

  /// Loads persisted preferences and pushes the audio/haptic flags into the
  /// runtime singletons. Safe to call more than once.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (error) {
      debugPrint('Preferences unavailable, using in-memory defaults: $error');
      _prefs = null;
    }
    _applyRuntimeFlags();
  }

  void _applyRuntimeFlags() {
    ProceduralAudioSynth.instance.soundEnabled = soundEnabled;
    HapticChoreographer.instance.hapticsEnabled = hapticsEnabled;
  }

  bool get soundEnabled => _prefs?.getBool(_kSoundEnabled) ?? true;
  bool get hapticsEnabled => _prefs?.getBool(_kHapticsEnabled) ?? true;

  Future<void> setSoundEnabled(bool value) async {
    ProceduralAudioSynth.instance.soundEnabled = value;
    await _writeBool(_kSoundEnabled, value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    HapticChoreographer.instance.hapticsEnabled = value;
    await _writeBool(_kHapticsEnabled, value);
  }

  String? getString(String key) => _prefs?.getString(key);

  Future<void> setString(String key, String value) async {
    try {
      await _prefs?.setString(key, value);
    } catch (error) {
      debugPrint('Failed to persist $key: $error');
    }
  }

  Future<void> _writeBool(String key, bool value) async {
    try {
      await _prefs?.setBool(key, value);
    } catch (error) {
      debugPrint('Failed to persist $key: $error');
    }
  }

  /// Wipes every preference owned by the app (used by "Erase all local data").
  ///
  /// The audio and haptics singletons are reset to their factory defaults so
  /// the running session matches what a fresh install would do.
  Future<void> clearAll() async {
    try {
      await _prefs?.clear();
    } catch (error) {
      debugPrint('Failed to clear preferences: $error');
    }
    ProceduralAudioSynth.instance.soundEnabled = true;
    HapticChoreographer.instance.hapticsEnabled = true;
  }

  // Typed accessors for the gameplay configuration so callers do not have to
  // remember storage keys.
  String? get theme => getString(_kTheme);
  Future<void> setTheme(String value) => setString(_kTheme, value);

  String? get controlMode => getString(_kControlMode);
  Future<void> setControlMode(String value) => setString(_kControlMode, value);

  String? get playMode => getString(_kPlayMode);
  Future<void> setPlayMode(String value) => setString(_kPlayMode, value);

  String? get sessionMode => getString(_kSessionMode);
  Future<void> setSessionMode(String value) => setString(_kSessionMode, value);

  String? get pairMode => getString(_kPairMode);
  Future<void> setPairMode(String value) => setString(_kPairMode, value);
}
