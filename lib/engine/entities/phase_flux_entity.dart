import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';

enum PolarityColor { cyan, crimson }

class PolarityWall {
  double y;
  final PolarityColor color;
  final double height;
  final double speed;
  bool absorbed = false;

  PolarityWall({
    required this.y,
    required this.color,
    this.height = 24.0,
    required this.speed,
  });

  Rect getBounds(double laneLeft, double laneRight) {
    return Rect.fromLTWH(laneLeft, y, laneRight - laneLeft, height);
  }
}

class PhaseCoreEntity {
  double x = 0.0;
  double y = 0.0;
  PolarityColor polarity = PolarityColor.cyan;
  double pulseTimer = 0.0;
  double flipAnimProgress = 1.0; // 0.0 -> 1.0 when flipped

  void reset({required double initialX, required double initialY}) {
    x = initialX;
    y = initialY;
    polarity = PolarityColor.cyan;
    pulseTimer = 0.0;
    flipAnimProgress = 1.0;
  }

  void flip() {
    polarity = polarity == PolarityColor.cyan
        ? PolarityColor.crimson
        : PolarityColor.cyan;
    flipAnimProgress = 0.0;
  }

  void update(double dt, double targetX, double targetY) {
    pulseTimer += dt;
    if (flipAnimProgress < 1.0) {
      flipAnimProgress = math.min(1.0, flipAnimProgress + dt * 10.0);
    }
    // Smoothly anchor core to lane center
    x += (targetX - x) * math.min(1.0, dt * 12.0);
    y = targetY;
  }

  Color get currentColor => polarity == PolarityColor.cyan
      ? SplitPalette.nearMissCyan
      : SplitPalette.hazardCrimson;
}
