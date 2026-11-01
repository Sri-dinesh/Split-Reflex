import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/physics_constants.dart';

class OrbEntity {
  double x = 0.0;
  double y = 0.0;
  double vx = PhysicsConstants.orbHorizontalSpeed;
  double vy = 0.0;
  double squashTimer = 0.0;
  double corePulseTime = 0.0;

  final List<Offset> trail = List.filled(PhysicsConstants.orbTrailLength, Offset.zero);
  int _trailHead = 0;

  void reset({required double initialX, required double initialY}) {
    x = initialX;
    y = initialY;
    vx = PhysicsConstants.orbHorizontalSpeed;
    vy = 0.0;
    squashTimer = 0.0;
    corePulseTime = 0.0;
    for (int i = 0; i < trail.length; i++) {
      trail[i] = Offset(initialX, initialY);
    }
    _trailHead = 0;
  }

  void thrust({required bool inverted}) {
    vy = inverted ? -PhysicsConstants.orbJumpImpulse : PhysicsConstants.orbJumpImpulse;
    squashTimer = PhysicsConstants.orbSquashDuration;
  }

  void update({
    required double dt,
    required double laneLeft,
    required double laneRight,
    required double gravity,
    required bool inverted,
  }) {
    // Gravity & vertical movement
    vy += gravity * dt;
    y += vy * dt;

    // Horizontal drift & wall bounce
    x += vx * dt;
    final double radius = PhysicsConstants.orbRadius;
    if (x - radius <= laneLeft) {
      x = laneLeft + radius;
      vx = vx.abs();
    } else if (x + radius >= laneRight) {
      x = laneRight - radius;
      vx = -vx.abs();
    }

    // Squash factor decay
    if (squashTimer > 0.0) {
      squashTimer = math.max(0.0, squashTimer - dt);
    }

    // Core pulsing animation
    corePulseTime += dt;

    // Update trail ring buffer
    trail[_trailHead] = Offset(x, y);
    _trailHead = (_trailHead + 1) % trail.length;
  }

  /// Retrieves trail ordered from newest to oldest
  List<Offset> getOrderedTrail() {
    final List<Offset> ordered = [];
    for (int i = 0; i < trail.length; i++) {
      final int idx = (_trailHead - 1 - i + trail.length) % trail.length;
      ordered.add(trail[idx]);
    }
    return ordered;
  }

  double get squashScaleX {
    if (squashTimer <= 0.0) return 1.0;
    final double progress = squashTimer / PhysicsConstants.orbSquashDuration;
    return 1.0 + 0.25 * progress;
  }

  double get squashScaleY {
    if (squashTimer <= 0.0) return 1.0;
    final double progress = squashTimer / PhysicsConstants.orbSquashDuration;
    return 1.0 - 0.25 * progress;
  }

  double get coreRadius {
    return 6.0 + 2.0 * math.sin(8.0 * corePulseTime);
  }
}
