import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/constants/physics_constants.dart';
import '../entities/obstacle_entity.dart';
import '../entities/orb_entity.dart';

class OrbHemispherePainter {
  static final Paint _spikePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _trailPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _outerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Paint _corePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _nodePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _beamPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  static final Path _topPath = Path();
  static final Path _bottomPath = Path();
  static final Path _jitterPath = Path();

  static void paint({
    required Canvas canvas,
    required Size size,
    required OrbEntity orb,
    required List<LaserGate> laserGates,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required double survivalTime,
    required bool isOverdrive,
  }) {
    // 1. Draw Top and Bottom Boundary Sawtooth Spikes
    _paintSawtoothSpikes(
      canvas: canvas,
      laneLeft: laneLeft,
      laneRight: laneRight,
      screenHeight: size.height,
      color: SplitPalette.hazardCrimson,
      survivalTime: survivalTime,
    );

    // 2. Draw Laser Gates
    _paintLaserGates(
      canvas: canvas,
      laserGates: laserGates,
      laneLeft: laneLeft,
      laneRight: laneRight,
      color: fgColor,
      hazardColor: SplitPalette.hazardCrimson,
      survivalTime: survivalTime,
    );

    // 3. Draw Orb Motion Trail
    final orderedTrail = orb.getOrderedTrail();
    final double baseRadius = PhysicsConstants.orbRadius;

    for (int i = 0; i < orderedTrail.length; i++) {
      final Offset pt = orderedTrail[i];
      if (pt == Offset.zero) continue;
      final double factor = 1.0 - (i / orderedTrail.length);
      final double r = baseRadius * factor * 0.8;
      _trailPaint.color = fgColor.withOpacity(0.35 * factor);
      canvas.drawCircle(pt, r, _trailPaint);
    }

    // 4. Draw Orb Player Entity
    canvas.save();
    canvas.translate(orb.x, orb.y);
    // Squash & Stretch
    canvas.scale(orb.squashScaleX, orb.squashScaleY);

    // Outer Ring
    _outerPaint.color = fgColor;
    canvas.drawCircle(Offset.zero, baseRadius, _outerPaint);

    // Inner Core
    _corePaint.color = isOverdrive ? SplitPalette.hazardCrimson : fgColor;
    canvas.drawCircle(Offset.zero, orb.coreRadius, _corePaint);

    canvas.restore();
  }

  static void _paintSawtoothSpikes({
    required Canvas canvas,
    required double laneLeft,
    required double laneRight,
    required double screenHeight,
    required Color color,
    required double survivalTime,
  }) {
    // Pulse height on every full-second beat
    final double beatFraction = survivalTime % 1.0;
    final double spikeHeight = beatFraction < 0.2
        ? PhysicsConstants.spikePulseHeight
        : PhysicsConstants.spikeBaseHeight;

    _spikePaint.color = color;
    const double step = PhysicsConstants.spikeStep;

    // Top Spikes
    _topPath.reset();
    _topPath.moveTo(laneLeft, 0);
    for (double x = laneLeft; x <= laneRight + step; x += step) {
      _topPath.lineTo(x + step / 2.0, spikeHeight);
      _topPath.lineTo(x + step, 0);
    }
    _topPath.close();
    canvas.drawPath(_topPath, _spikePaint);

    // Bottom Spikes
    _bottomPath.reset();
    _bottomPath.moveTo(laneLeft, screenHeight);
    for (double x = laneLeft; x <= laneRight + step; x += step) {
      _bottomPath.lineTo(x + step / 2.0, screenHeight - spikeHeight);
      _bottomPath.lineTo(x + step, screenHeight);
    }
    _bottomPath.close();
    canvas.drawPath(_bottomPath, _spikePaint);
  }

  static void _paintLaserGates({
    required Canvas canvas,
    required List<LaserGate> laserGates,
    required double laneLeft,
    required double laneRight,
    required Color color,
    required Color hazardColor,
    required double survivalTime,
  }) {
    _nodePaint.color = hazardColor;
    _beamPaint.color = hazardColor;

    for (final gate in laserGates) {
      final double y = gate.y;
      final double gLeft = gate.gapLeft;
      final double gRight = gate.gapRight;

      // Left Node
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(laneLeft, y - 8.0, 10.0, 16.0),
          const Radius.circular(3.0),
        ),
        _nodePaint,
      );

      // Right Node
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(laneRight - 10.0, y - 8.0, 10.0, 16.0),
          const Radius.circular(3.0),
        ),
        _nodePaint,
      );

      // Left Beam: laneLeft -> gLeft with electrical jitter
      _drawJitterSegment(
        canvas: canvas,
        p1: Offset(laneLeft + 10.0, y),
        p2: Offset(gLeft, y),
        segments: 6,
        time: survivalTime,
      );

      // Right Beam: gRight -> laneRight with electrical jitter
      _drawJitterSegment(
        canvas: canvas,
        p1: Offset(gRight, y),
        p2: Offset(laneRight - 10.0, y),
        segments: 6,
        time: survivalTime + 1.5,
      );

      // Gap guide pings
      canvas.drawCircle(Offset(gLeft, y), 3.0, _nodePaint);
      canvas.drawCircle(Offset(gRight, y), 3.0, _nodePaint);
    }
  }

  static void _drawJitterSegment({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required int segments,
    required double time,
  }) {
    if (p2.dx <= p1.dx) return;
    _jitterPath.reset();
    _jitterPath.moveTo(p1.dx, p1.dy);
    final double stepX = (p2.dx - p1.dx) / segments;

    for (int i = 1; i < segments; i++) {
      final double currX = p1.dx + i * stepX;
      final double jitterY = math.sin(currX * 0.15 + time * 30.0) * 2.5;
      _jitterPath.lineTo(currX, p1.dy + jitterY);
    }
    _jitterPath.lineTo(p2.dx, p2.dy);
    canvas.drawPath(_jitterPath, _beamPaint);
  }
}
