import 'dart:math' as math;
import 'package:flutter/material.dart';

class MathUtils {
  /// Simple linear interpolation
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Damped harmonic oscillator elastic snap
  /// x(t) = target + delta * e^(-decay * t) * cos(frequency * t)
  static double dampedSpring({
    required double target,
    required double delta,
    required double timeElapsed,
    double decay = 8.0,
    double frequency = 25.0,
  }) {
    return target + delta * math.exp(-decay * timeElapsed) * math.cos(frequency * timeElapsed);
  }

  /// Test if a circle at (cx, cy) with radius r intersects with an axis-aligned bounding box (AABB)
  static bool circleIntersectsAABB({
    required double cx,
    required double cy,
    required double radius,
    required Rect aabb,
  }) {
    // Find closest point on AABB to circle center
    final double closestX = cx.clamp(aabb.left, aabb.right);
    final double closestY = cy.clamp(aabb.top, aabb.bottom);

    final double dx = cx - closestX;
    final double dy = cy - closestY;

    return (dx * dx + dy * dy) <= (radius * radius);
  }

  /// Calculates minimum Euclidean distance from circle center to an AABB
  static double distanceCircleToAABB({
    required double cx,
    required double cy,
    required Rect aabb,
  }) {
    final double closestX = cx.clamp(aabb.left, aabb.right);
    final double closestY = cy.clamp(aabb.top, aabb.bottom);

    final double dx = cx - closestX;
    final double dy = cy - closestY;

    return math.sqrt(dx * dx + dy * dy);
  }

  /// Test if a 2D line segment intersects a circle
  static bool circleIntersectsSegment({
    required Offset center,
    required double radius,
    required Offset p1,
    required Offset p2,
  }) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double lenSq = dx * dx + dy * dy;

    if (lenSq == 0) {
      return (center - p1).distanceSquared <= (radius * radius);
    }

    // Projection parameter t
    final double t = (((center.dx - p1.dx) * dx + (center.dy - p1.dy) * dy) / lenSq).clamp(0.0, 1.0);
    final double projX = p1.dx + t * dx;
    final double projY = p1.dy + t * dy;

    final double distSq = (center.dx - projX) * (center.dx - projX) + (center.dy - projY) * (center.dy - projY);
    return distSq <= (radius * radius);
  }
}
