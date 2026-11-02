import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/physics_constants.dart';
import '../../core/utils/math_utils.dart';

class LaserGate {
  double y;
  double gapCenterX;
  double gapWidth;
  double speed;
  double oscillationTime = 0.0;
  bool nearMissTriggered = false;

  LaserGate({
    required this.y,
    required this.gapCenterX,
    this.gapWidth = PhysicsConstants.laserGateGapWidth,
    this.speed = PhysicsConstants.laserGateSpeed,
  });

  double get gapLeft => gapCenterX - gapWidth / 2.0;
  double get gapRight => gapCenterX + gapWidth / 2.0;

  void update({
    required double dt,
    required double laneLeft,
    required double laneRight,
    required bool inverted,
    required bool shouldOscillate,
  }) {
    // Scroll direction: normal = down, inverted = up
    final double dirY = inverted ? -1.0 : 1.0;
    y += dirY * speed * dt;

    if (shouldOscillate) {
      oscillationTime += dt;
      final double availableWidth = (laneRight - laneLeft) - gapWidth - 20.0;
      if (availableWidth > 0) {
        final double mid = (laneLeft + laneRight) / 2.0;
        final double amplitude = availableWidth / 2.0;
        gapCenterX = mid + amplitude * math.sin(oscillationTime * 2.2);
      }
    } else {
      // Clamp gap within lane
      final double half = gapWidth / 2.0;
      gapCenterX = gapCenterX.clamp(
        laneLeft + half + 8.0,
        laneRight - half - 8.0,
      );
    }
  }

  /// Checks collision and near-miss against Orb
  bool checkCollisionWithOrb({
    required double orbX,
    required double orbY,
    required double orbRadius,
    required void Function() onNearMiss,
  }) {
    // Vertical proximity
    if ((orbY - y).abs() <= (orbRadius + 4.0)) {
      final double orbLeft = orbX - orbRadius;
      final double orbRight = orbX + orbRadius;

      // If outside gap, collision occurs
      if (orbLeft < gapLeft || orbRight > gapRight) {
        return true;
      }

      // Check near-miss: close to gap edge
      if (!nearMissTriggered) {
        final double distToLeftEdge = (orbLeft - gapLeft).abs();
        final double distToRightEdge = (gapRight - orbRight).abs();
        final double minDist = math.min(distToLeftEdge, distToRightEdge);
        if (minDist < PhysicsConstants.nearMissDistanceThreshold) {
          nearMissTriggered = true;
          onNearMiss();
        }
      }
    }
    return false;
  }
}

class Monolith {
  double x;
  double y;
  double width;
  double height;
  double speed;
  bool nearMissTriggered = false;

  Monolith({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
  });

  Rect get rect => Rect.fromLTWH(x - width / 2.0, y, width, height);

  void update({required double dt, required bool inverted}) {
    final double dirY = inverted ? -1.0 : 1.0;
    y += dirY * speed * dt;
  }

  /// Test collision against Dart's 3 hitbox circles
  bool checkCollisionWithDartCircles({
    required List<dynamic> circles,
    required void Function() onNearMiss,
  }) {
    final Rect aabb = rect;
    bool collided = false;
    double minDistance = double.infinity;

    for (final circle in circles) {
      final Offset center = circle.offset;
      final double radius = circle.radius;

      if (MathUtils.circleIntersectsAABB(
        cx: center.dx,
        cy: center.dy,
        radius: radius,
        aabb: aabb,
      )) {
        collided = true;
        break;
      }

      final double d =
          MathUtils.distanceCircleToAABB(
            cx: center.dx,
            cy: center.dy,
            aabb: aabb,
          ) -
          radius;
      if (d < minDistance) {
        minDistance = d;
      }
    }

    if (collided) return true;

    if (!nearMissTriggered &&
        minDistance <= PhysicsConstants.nearMissDistanceThreshold) {
      nearMissTriggered = true;
      onNearMiss();
    }

    return false;
  }
}
