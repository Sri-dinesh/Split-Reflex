import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/palette.dart';
import '../core/constants/physics_constants.dart';

enum MechanicSide { left, right }

enum HemisphereMechanic {
  orb, // Pair 1: Gravity Defier
  dart, // Pair 1: Rail Weaver
  breachAlpha, // Pair 2: Zero-G Deflector Alpha (Ping Pong)
  breachBeta, // Pair 2: Heavy-G Deflector Beta (Ping Pong)
  shieldPing, // Pair 3: Rhythm reflex deflector
  quantumWarp, // Pair 3: Binary dual-track hopper
}

class HemisphereState {
  // Current assignment
  HemisphereMechanic leftMechanic = HemisphereMechanic.orb;
  HemisphereMechanic rightMechanic = HemisphereMechanic.dart;
  HemisphereMechanic initialLeftMechanic = HemisphereMechanic.orb;

  // Split Divider position
  double splitX = 0.5; // normalized 0.0 - 1.0 (defaults to 0.5W)
  double rawSplitPixels = 0.0;

  // Swap State Machine
  bool isSwapWarning = false;
  double swapWarningRemaining = 0.0;
  bool isSwapping = false;
  double swapTransitionElapsed = 0.0;
  double swapProgress = 0.0; // 0.0 -> 1.0 during transition

  // Tug-of-War State
  bool isTugOfWarActive = false;
  double tugOfWarTime = 0.0;

  // Polarity Inversion State
  bool isPolarityInverted = false;
  double polarityFlipWarningRemaining = 0.0;

  // Colors
  Color leftBg = SplitPalette.darkBg;
  Color leftFg = SplitPalette.lightBg;
  Color rightBg = SplitPalette.lightBg;
  Color rightFg = SplitPalette.darkBg;

  // Initial setup
  void reset(
    double screenWidth, {
    HemisphereMechanic initialLeft = HemisphereMechanic.orb,
    HemisphereMechanic initialRight = HemisphereMechanic.dart,
  }) {
    initialLeftMechanic = initialLeft;
    leftMechanic = initialLeft;
    rightMechanic = initialRight;
    splitX = 0.5;
    rawSplitPixels = screenWidth * 0.5;

    isSwapWarning = false;
    swapWarningRemaining = 0.0;
    isSwapping = false;
    swapTransitionElapsed = 0.0;
    swapProgress = 0.0;

    isTugOfWarActive = false;
    tugOfWarTime = 0.0;

    isPolarityInverted = false;
    polarityFlipWarningRemaining = 0.0;

    _updateColors(isOverdrive: false, isGodMode: false);
  }

  void update({
    required double dt,
    required double survivalTime,
    required double screenWidth,
    required bool isOverdrive,
    required bool isGodMode,
    bool isMutationEnabled = true,
    String themeName = 'monochrome',
    required void Function(int countdownSeconds) onSwapWarningTick,
    required void Function() onSwapExecuted,
  }) {
    // Determine Mutation Timeline
    // 00-15s: Calibration
    // 15-30s: Swap 1
    // 30-45s: Tug-of-war
    // 45-60s: Polarity flip
    // 60s+: Swaps every 10s, speed * 1.35x

    double nextMutationTime;
    if (survivalTime < 60.0) {
      nextMutationTime = ((survivalTime / 15.0).floor() + 1) * 15.0;
    } else {
      nextMutationTime =
          60.0 + (((survivalTime - 60.0) / 10.0).floor() + 1) * 10.0;
    }

    final double timeUntilNextMutation = nextMutationTime - survivalTime;

    // Polarity Flip trigger at 45s
    if (isMutationEnabled && survivalTime >= 45.0 && !isPolarityInverted) {
      isPolarityInverted = true;
      polarityFlipWarningRemaining = 1.5;
    }
    if (polarityFlipWarningRemaining > 0.0) {
      polarityFlipWarningRemaining = math.max(
        0.0,
        polarityFlipWarningRemaining - dt,
      );
    }

    // Tug-of-war active between 30s and 45s, and also resumes intermittently past 60s
    isTugOfWarActive =
        isMutationEnabled &&
        ((survivalTime >= 30.0 && survivalTime < 45.0) ||
            (survivalTime >= 70.0));
    if (isTugOfWarActive) {
      tugOfWarTime += dt;
      // Oscillate split between 0.32W and 0.68W via sine wave: W/2 + 0.16W * sin(1.4t)
      splitX = 0.50 + 0.16 * math.sin(1.4 * tugOfWarTime);
    } else if (!isSwapping) {
      // Settle back to center
      splitX = 0.50;
    }
    rawSplitPixels = screenWidth * splitX;

    // Swap Warning (2.0s before next mutation)
    if (isMutationEnabled &&
        timeUntilNextMutation <= PhysicsConstants.swapWarningDuration &&
        timeUntilNextMutation > 0.0) {
      if (!isSwapWarning) {
        isSwapWarning = true;
      }
      final int prevSecond = (swapWarningRemaining).ceil();
      swapWarningRemaining = timeUntilNextMutation;
      final int curSecond = (swapWarningRemaining).ceil();
      if (curSecond > 0 && curSecond != prevSecond) {
        onSwapWarningTick(curSecond);
      }
    } else {
      isSwapWarning = false;
    }

    // Swap Transition execution
    if (isSwapping) {
      swapTransitionElapsed += dt;
      swapProgress =
          (swapTransitionElapsed / PhysicsConstants.swapTransitionDuration)
              .clamp(0.0, 1.0);
      if (swapProgress >= 1.0) {
        isSwapping = false;
        swapProgress = 0.0;
      }
    }

    _updateColors(
      isOverdrive: isOverdrive,
      isGodMode: isGodMode,
      themeName: themeName,
    );
  }

  void executeSwap({
    required bool isOverdrive,
    required bool isGodMode,
    String themeName = 'monochrome',
  }) {
    // Invert mechanics
    final temp = leftMechanic;
    leftMechanic = rightMechanic;
    rightMechanic = temp;

    isSwapping = true;
    swapTransitionElapsed = 0.0;
    swapProgress = 0.0;
    isSwapWarning = false;

    _updateColors(
      isOverdrive: isOverdrive,
      isGodMode: isGodMode,
      themeName: themeName,
    );
  }

  void updateTheme({
    required bool isOverdrive,
    required bool isGodMode,
    required String themeName,
  }) {
    _updateColors(
      isOverdrive: isOverdrive,
      isGodMode: isGodMode,
      themeName: themeName,
    );
  }

  void _updateColors({
    required bool isOverdrive,
    required bool isGodMode,
    String themeName = 'monochrome',
  }) {
    final baseDark = SplitPalette.getThemeDark(
      isOverdrive: isOverdrive,
      isGodMode: isGodMode,
      themeName: themeName,
    );
    final baseLight = SplitPalette.getThemeLight(
      isOverdrive: isOverdrive,
      isGodMode: isGodMode,
      themeName: themeName,
    );

    // Left hemisphere starts Dark, Right starts Light.
    // If swapped, left is Light, right is Dark.
    final bool leftIsOriginal = (leftMechanic == initialLeftMechanic);

    final Color targetLeftBg = leftIsOriginal ? baseDark : baseLight;
    final Color targetLeftFg = leftIsOriginal ? baseLight : baseDark;
    final Color targetRightBg = leftIsOriginal ? baseLight : baseDark;
    final Color targetRightFg = leftIsOriginal ? baseDark : baseLight;

    if (isSwapping) {
      final double t = Curves.easeInOutCubic.transform(swapProgress);
      leftBg = Color.lerp(targetRightBg, targetLeftBg, t)!;
      leftFg = Color.lerp(targetRightFg, targetLeftFg, t)!;
      rightBg = Color.lerp(targetLeftBg, targetRightBg, t)!;
      rightFg = Color.lerp(targetLeftFg, targetRightFg, t)!;
    } else {
      leftBg = targetLeftBg;
      leftFg = targetLeftFg;
      rightBg = targetRightBg;
      rightFg = targetRightFg;
    }
  }

  double getLaneLeft(HemisphereMechanic mechanic, double screenWidth) {
    if (leftMechanic == mechanic) {
      return 0.0;
    } else {
      return rawSplitPixels;
    }
  }

  double getLaneRight(HemisphereMechanic mechanic, double screenWidth) {
    if (leftMechanic == mechanic) {
      return rawSplitPixels;
    } else {
      return screenWidth;
    }
  }
}
