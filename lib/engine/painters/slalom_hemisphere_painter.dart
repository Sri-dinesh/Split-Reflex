import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../entities/slalom_drift_entity.dart';

class SlalomHemispherePainter {
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  static final Path _leftWallPath = Path();
  static final Path _rightWallPath = Path();
  static final Path _shipPath = Path();

  static void paint({
    required Canvas canvas,
    required Size size,
    required SlalomDriftEntity glider,
    required List<SlalomPylon> pylons,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required double survivalTime,
    required bool isOverdrive,
  }) {
    final double introFactor = (survivalTime / 3.5).clamp(0.0, 1.0);
    final double laneWidth = laneRight - laneLeft;
    final double chasmWidth = glider.getChasmWidth(laneWidth, introFactor: introFactor);

    // 1. Draw Undulating Chasm Boundary Ribbon
    _leftWallPath.reset();
    _rightWallPath.reset();

    const double stepY = 24.0;
    bool first = true;
    for (double y = 0; y <= size.height + stepY; y += stepY) {
      final double center = glider.getChasmCenter(y, laneLeft, laneRight, introFactor: introFactor);
      final double lx = center - chasmWidth * 0.5;
      final double rx = center + chasmWidth * 0.5;

      if (first) {
        _leftWallPath.moveTo(lx, y);
        _rightWallPath.moveTo(rx, y);
        first = false;
      } else {
        _leftWallPath.lineTo(lx, y);
        _rightWallPath.lineTo(rx, y);
      }
    }

    // Outer hazard field
    _strokePaint
      ..color = fgColor.withOpacity(0.4)
      ..strokeWidth = 2.0;
    canvas.drawPath(_leftWallPath, _strokePaint);
    canvas.drawPath(_rightWallPath, _strokePaint);

    // 2. Draw Drift Pylons
    for (final pylon in pylons) {
      _fillPaint.color = SplitPalette.hazardCrimson.withOpacity(0.8);
      canvas.drawCircle(Offset(pylon.x, pylon.y), pylon.radius, _fillPaint);
      _strokePaint
        ..color = Colors.white
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(pylon.x, pylon.y), pylon.radius, _strokePaint);
    }

    // 3. Draw Slalom Hover-Glider
    canvas.save();
    canvas.translate(glider.x, glider.y);
    canvas.rotate(glider.tiltAngle);

    _shipPath.reset();
    _shipPath.moveTo(0, -16.0); // nose
    _shipPath.lineTo(12.0, 14.0); // right wing
    _shipPath.lineTo(0, 8.0);     // center notch
    _shipPath.lineTo(-12.0, 14.0); // left wing
    _shipPath.close();

    _fillPaint.color = isOverdrive ? SplitPalette.hazardCrimson : fgColor;
    canvas.drawPath(_shipPath, _fillPaint);

    _strokePaint
      ..color = Colors.white
      ..strokeWidth = 1.5;
    canvas.drawPath(_shipPath, _strokePaint);

    // Thruster glow
    _fillPaint.color = SplitPalette.nearMissCyan;
    canvas.drawCircle(const Offset(0, 12.0), 3.0, _fillPaint);

    canvas.restore();
  }
}
