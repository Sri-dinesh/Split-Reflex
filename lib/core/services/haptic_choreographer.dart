import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Manages tactile haptic waveforms with fallback to standard HapticFeedback.
class HapticChoreographer {
  static final HapticChoreographer instance = HapticChoreographer._internal();
  HapticChoreographer._internal();

  bool _hasCustomVibration = false;
  bool hapticsEnabled = true;

  Future<void> init() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      final hasAmplitudeControl = await Vibration.hasAmplitudeControl();
      _hasCustomVibration = (hasVibrator == true) && (hasAmplitudeControl == true);
    } catch (_) {
      _hasCustomVibration = false;
    }
  }

  /// Orb Tap: Quick, light tactile tap
  void triggerTap() {
    if (!hapticsEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Near-Miss: 18ms sharp pulse with 180 amplitude
  void triggerNearMiss() {
    if (!hapticsEnabled) return;
    try {
      if (_hasCustomVibration) {
        Vibration.vibrate(duration: 18, amplitude: 180);
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Swap Warning Tick: 25ms sharp tick
  void triggerSwapTick() {
    if (!hapticsEnabled) return;
    try {
      if (_hasCustomVibration) {
        Vibration.vibrate(duration: 25, amplitude: 200);
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      HapticFeedback.selectionClick();
    }
  }

  /// Swap Execution Thud: Heavy 90ms thud
  void triggerSwapExecute() {
    if (!hapticsEnabled) return;
    try {
      if (_hasCustomVibration) {
        Vibration.vibrate(duration: 90, amplitude: 255);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Death Collision: Multi-stage crash pulse [0, 60, 30, 120]
  void triggerDeath() {
    if (!hapticsEnabled) return;
    try {
      if (_hasCustomVibration) {
        Vibration.vibrate(pattern: [0, 60, 30, 120], intensities: [0, 255, 0, 200]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }
}
