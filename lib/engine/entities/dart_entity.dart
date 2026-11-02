import 'dart:math' as math;
import 'dart:ui';

import '../../core/constants/physics_constants.dart';

class DartHitboxCircle {
  final Offset offset;
  final double radius;
  const DartHitboxCircle({required this.offset, required this.radius});
}

class DartEntity {
  double x = 0.0;
  double targetX = 0.0;
  double vx = 0.0;
  double bankAngle = 0.0;
  double railY = 0.0;
  double targetRailY = 0.0;

  void reset({required double initialX, required double initialRailY}) {
    x = initialX;
    targetX = initialX;
    vx = 0.0;
    bankAngle = 0.0;
    railY = initialRailY;
    targetRailY = initialRailY;
  }

  void handleTap(
    double tapX, {
    required double laneLeft,
    required double laneRight,
  }) {
    const double margin = 18.0;
    final double minX = laneLeft + margin;
    final double maxX = laneRight - margin;
    if (minX >= maxX) {
      targetX = (laneLeft + laneRight) / 2.0;
    } else {
      targetX = tapX.clamp(minX, maxX);
    }
  }

  void handleDragDelta(
    double deltaX, {
    double? currentX,
    required double laneLeft,
    required double laneRight,
  }) {
    const double margin = 18.0;
    final double minX = laneLeft + margin;
    final double maxX = laneRight - margin;
    if (minX >= maxX) {
      targetX = (laneLeft + laneRight) / 2.0;
    } else if (currentX != null) {
      targetX = currentX.clamp(minX, maxX);
    } else {
      targetX = (targetX + deltaX * PhysicsConstants.dartTouchSensitivity)
          .clamp(minX, maxX);
    }
  }

  void update({
    required double dt,
    required double laneLeft,
    required double laneRight,
    required double screenHeight,
    required bool inverted,
    bool isGyro = false,
  }) {
    const double margin = 18.0;
    final double minX = laneLeft + margin;
    final double maxX = laneRight - margin;
    if (minX < maxX) {
      targetX = targetX.clamp(minX, maxX);
    } else {
      targetX = (laneLeft + laneRight) / 2.0;
    }

    // Smooth horizontal tracking via exponential decay (higher rate in gyro for zero latency)
    final double trackingSpeed = isGyro
        ? 38.0
        : PhysicsConstants.dartTrackingSpeed;
    final double prevX = x;
    final double lerpFactor = 1.0 - math.exp(-trackingSpeed * dt);
    x = lerpDouble(x, targetX, lerpFactor) ?? targetX;
    vx = dt > 0 ? (x - prevX) / dt : 0.0;

    // Banking tilt
    bankAngle = (vx * 0.0012).clamp(
      -PhysicsConstants.dartBankAngleClamp,
      PhysicsConstants.dartBankAngleClamp,
    );

    // Rail Y position smooth interpolation (normal: 0.85H, inverted: 0.15H)
    targetRailY = inverted
        ? screenHeight * PhysicsConstants.dartInvertedRailYFactor
        : screenHeight * PhysicsConstants.dartDefaultRailYFactor;
    railY =
        lerpDouble(railY, targetRailY, 1.0 - math.exp(-12.0 * dt)) ??
        targetRailY;
  }

  /// 3 sample collision circles representing the Dart's geometry
  List<DartHitboxCircle> getHitboxCircles({required bool inverted}) {
    final double dir = inverted ? -1.0 : 1.0;
    return [
      DartHitboxCircle(offset: Offset(x, railY - 13.0 * dir), radius: 4.0),
      DartHitboxCircle(
        offset: Offset(x - 9.0, railY + 10.0 * dir),
        radius: 6.0,
      ),
      DartHitboxCircle(
        offset: Offset(x + 9.0, railY + 10.0 * dir),
        radius: 6.0,
      ),
    ];
  }

  Path createHullPath({required bool inverted}) {
    final Path path = Path();
    final double dir = inverted ? -1.0 : 1.0;

    path.moveTo(0.0, -17.0 * dir);
    path.lineTo(14.0, 17.0 * dir);
    path.lineTo(0.0, 10.0 * dir);
    path.lineTo(-14.0, 17.0 * dir);
    path.close();
    return path;
  }

  Path createInnerCutoutPath({required bool inverted}) {
    final Path path = Path();
    final double dir = inverted ? -1.0 : 1.0;

    path.moveTo(0.0, -8.0 * dir);
    path.lineTo(7.0, 12.0 * dir);
    path.lineTo(0.0, 7.0 * dir);
    path.lineTo(-7.0, 12.0 * dir);
    path.close();
    return path;
  }
}
