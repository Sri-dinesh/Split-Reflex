import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../entities/shield_ping_entity.dart';

class ShieldHemispherePainter {
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  static void paint({
    required Canvas canvas,
    required Size size,
    required ShieldPingEntity shield,
    required List<PlasmaBolt> bolts,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required bool isOverdrive,
  }) {
    final double laneWidth = laneRight - laneLeft;
    final double midX = laneLeft + laneWidth * 0.5;

    // 1. Defense Baseline
    _strokePaint
      ..color = fgColor.withOpacity(0.35)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(laneLeft + 10.0, shield.y),
      Offset(laneRight - 10.0, shield.y),
      _strokePaint,
    );

    // 2. Plasma Bolts
    for (final bolt in bolts) {
      if (bolt.deflected) continue;

      // Bolt tail glow
      _strokePaint
        ..color = SplitPalette.hazardCrimson.withOpacity(0.5)
        ..strokeWidth = 3.0;
      canvas.drawLine(
        Offset(midX, bolt.y - 18.0),
        Offset(midX, bolt.y),
        _strokePaint,
      );

      // Bolt plasma head
      _fillPaint.color = Colors.white;
      canvas.drawCircle(Offset(midX, bolt.y), 6.0, _fillPaint);
      _fillPaint.color = SplitPalette.hazardCrimson;
      canvas.drawCircle(Offset(midX, bolt.y), 4.0, _fillPaint);
    }

    // 3. Shield Barrier and Deflection Shockwave
    final double shieldWidth = (laneWidth * 0.70).clamp(40.0, 140.0);
    final Rect shieldRect = Rect.fromCenter(
      center: Offset(midX, shield.y),
      width: shieldWidth,
      height: 10.0,
    );
    _fillPaint.color = isOverdrive
        ? SplitPalette.goldBright
        : SplitPalette.nearMissCyan;
    canvas.drawRRect(
      RRect.fromRectAndRadius(shieldRect, const Radius.circular(5.0)),
      _fillPaint,
    );

    if (shield.shieldPulse > 0.0) {
      final double ringRadius = 15.0 + (1.0 - shield.shieldPulse) * 45.0;
      _strokePaint
        ..color = SplitPalette.nearMissCyan.withOpacity(shield.shieldPulse,)
        ..strokeWidth = 3.0 * shield.shieldPulse;
      canvas.drawCircle(Offset(midX, shield.y), ringRadius, _strokePaint);
    }

    // Directives text watermark
    final TextPainter tp = TextPainter(
      text: const TextSpan(
        text: 'TAP ON IMPACT TO DEFLECT',
        style: TextStyle(
          color: Colors.white24,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(laneLeft + (laneWidth - tp.width) / 2, size.height - 35),
    );
  }
}
