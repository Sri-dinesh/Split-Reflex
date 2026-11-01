import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../entities/dart_entity.dart';
import '../entities/obstacle_entity.dart';

class DartHemispherePainter {
  static final Paint _railPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _hullPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _cutoutPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _corePointPaint = Paint()..style = PaintingStyle.fill;

  static final Paint _monolithOuterPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _monolithWireframePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Paint _monolithGuideLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static void paint({
    required Canvas canvas,
    required Size size,
    required DartEntity dart,
    required List<Monolith> monoliths,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required bool inverted,
    required bool isOverdrive,
  }) {
    // 1. Draw Subtle Movement Guide Rail
    _railPaint.color = fgColor.withOpacity(0.18);
    canvas.drawLine(
      Offset(laneLeft, dart.railY),
      Offset(laneRight, dart.railY),
      _railPaint,
    );

    // 2. Draw Brutalist Monoliths
    _paintMonoliths(
      canvas: canvas,
      monoliths: monoliths,
      railY: dart.railY,
      fgColor: fgColor,
      bgColor: bgColor,
      isOverdrive: isOverdrive,
    );

    // 3. Draw Vector Dart Entity
    canvas.save();
    canvas.translate(dart.x, dart.railY);
    // Banking tilt
    canvas.rotate(dart.bankAngle);

    // Outer Hull
    _hullPaint.color = fgColor;
    final Path hullPath = dart.createHullPath(inverted: inverted);
    canvas.drawPath(hullPath, _hullPaint);

    // Inner Inset Cutout
    _cutoutPaint.color = isOverdrive ? SplitPalette.hazardCrimson : bgColor;
    final Path cutoutPath = dart.createInnerCutoutPath(inverted: inverted);
    canvas.drawPath(cutoutPath, _cutoutPaint);

    // Cockpit / Core point
    _corePointPaint.color = isOverdrive ? SplitPalette.godModeGold : fgColor;
    canvas.drawCircle(Offset(0, inverted ? -3.0 : 3.0), 2.0, _corePointPaint);

    canvas.restore();
  }

  static void _paintMonoliths({
    required Canvas canvas,
    required List<Monolith> monoliths,
    required double railY,
    required Color fgColor,
    required Color bgColor,
    required bool isOverdrive,
  }) {
    _monolithOuterPaint.color = fgColor;
    _monolithWireframePaint.color = isOverdrive ? SplitPalette.hazardCrimson : bgColor;
    _monolithGuideLinePaint.color = fgColor.withOpacity(0.08);

    for (final m in monoliths) {
      final Rect rect = m.rect;

      // Drop-shadow / Fair warning vertical trajectory guide line to rail
      canvas.drawLine(
        Offset(rect.center.dx, rect.bottom),
        Offset(rect.center.dx, railY),
        _monolithGuideLinePaint,
      );

      // Outer Frame
      canvas.drawRect(rect, _monolithOuterPaint);

      // Inner Wireframe: Inset Rect.deflate(5) with diagonal X-bracing
      final Rect insetRect = rect.deflate(5.0);
      if (insetRect.width > 4 && insetRect.height > 4) {
        canvas.drawRect(insetRect, _monolithWireframePaint);

        // X-Bracing lines
        canvas.drawLine(insetRect.topLeft, insetRect.bottomRight, _monolithWireframePaint);
        canvas.drawLine(insetRect.topRight, insetRect.bottomLeft, _monolithWireframePaint);
      }
    }
  }
}
