import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../entities/phase_flux_entity.dart';

class PhaseHemispherePainter {
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  static void paint({
    required Canvas canvas,
    required Size size,
    required PhaseCoreEntity core,
    required List<PolarityWall> walls,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required double survivalTime,
    required bool isOverdrive,
  }) {
    final double laneWidth = laneRight - laneLeft;

    // 1. Draw descending Polarity Walls
    for (final wall in walls) {
      if (wall.absorbed) continue;
      final Color wallColor = wall.color == PolarityColor.cyan ? SplitPalette.nearMissCyan : SplitPalette.hazardCrimson;
      
      // Wall glowing bar
      _fillPaint.color = wallColor.withOpacity(0.35);
      final Rect wallRect = Rect.fromLTWH(laneLeft + 6.0, wall.y, laneWidth - 12.0, wall.height);
      canvas.drawRRect(RRect.fromRectAndRadius(wallRect, const Radius.circular(6.0)), _fillPaint);

      // Bright accent border
      _strokePaint
        ..color = wallColor
        ..strokeWidth = 2.0;
      canvas.drawRRect(RRect.fromRectAndRadius(wallRect, const Radius.circular(6.0)), _strokePaint);

      // Icon / glyph in center
      _fillPaint.color = Colors.white;
      canvas.drawCircle(Offset(laneLeft + laneWidth * 0.5, wall.y + wall.height * 0.5), 3.5, _fillPaint);
    }

    // 2. Draw Phase Core
    final Color coreColor = core.currentColor;
    final double pulse = 1.0 + 0.12 * math.sin(core.pulseTimer * 8.0);
    final double radius = 18.0 * pulse;

    // Aura ring
    _strokePaint
      ..color = coreColor.withOpacity(0.4)
      ..strokeWidth = 3.0;
    canvas.drawCircle(Offset(core.x, core.y), radius + 8.0, _strokePaint);

    // Inner core diamond/circle
    _fillPaint.color = coreColor;
    canvas.drawCircle(Offset(core.x, core.y), radius, _fillPaint);

    // Flip transition flare
    if (core.flipAnimProgress < 1.0) {
      final double flareRadius = radius + (1.0 - core.flipAnimProgress) * 30.0;
      _strokePaint
        ..color = Colors.white.withOpacity(1.0 - core.flipAnimProgress)
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(core.x, core.y), flareRadius, _strokePaint);
    }

    // Directives text watermark at bottom
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'TAP TO FLIP POLARITY',
        style: TextStyle(
          color: Colors.white24,
          fontSize: 9.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(laneLeft + (laneWidth - tp.width) / 2, size.height - 35));
  }
}
