import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/constants/physics_constants.dart';
import '../entities/tide_lock_entity.dart';

/// Canvas rendering for Tide Lock.
///
/// One shared waterline spans both hemispheres: [paintWater] paints the
/// identical body/crest inside each lane clip so the seam at the divider
/// reads as one continuous sea.
class TideHemispherePainter {
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  static final Path _waterPath = Path();
  static final Path _capsulePath = Path();

  /// Paints the shared water body and animated crest inside one lane clip.
  static void paintWater({
    required Canvas canvas,
    required Size size,
    required double laneLeft,
    required double laneRight,
    required double surfaceY,
    required double animTime,
    required Color fgColor,
  }) {
    double waveAt(double x) =>
        surfaceY + math.sin(x * 0.09 + animTime * 2.4) * 4.0;

    _waterPath.reset();
    _waterPath.moveTo(laneLeft, waveAt(laneLeft));
    for (double x = laneLeft + 6.0; x <= laneRight; x += 6.0) {
      _waterPath.lineTo(x, waveAt(x));
    }
    _waterPath.lineTo(laneRight, size.height);
    _waterPath.lineTo(laneLeft, size.height);
    _waterPath.close();

    _fillPaint.color = fgColor.withOpacity(0.07);
    canvas.drawPath(_waterPath, _fillPaint);

    // Crest line + echo band
    _strokePaint
      ..color = fgColor.withOpacity(0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(laneLeft, waveAt(laneLeft)),
      Offset(laneRight, waveAt(laneRight)),
      _strokePaint,
    );
    _strokePaint.color = fgColor.withOpacity(0.16);
    _strokePaint.strokeWidth = 5.0;
    canvas.drawLine(
      Offset(laneLeft, waveAt(laneLeft) + 5.0),
      Offset(laneRight, waveAt(laneRight) + 5.0),
      _strokePaint,
    );
  }

  /// Left mechanic: hanging arches, tide gauge and the buoyant submarine.
  static void paintValveSub({
    required Canvas canvas,
    required Size size,
    required List<TideArch> arches,
    required double laneLeft,
    required double laneRight,
    required double surfaceY,
    required double subX,
    required double subY,
    required bool valveOpen,
    required double animTime,
    required Color fgColor,
    required Color bgColor,
    required bool isOverdrive,
  }) {
    final double laneWidth = laneRight - laneLeft;

    // 1. Hanging arches (stone slabs with a hazard lip).
    final Color stoneColor = Color.lerp(bgColor, Colors.black, 0.45)!;
    for (final TideArch arch in arches) {
      final double ax = laneLeft + arch.xFactor * laneWidth;
      final double halfW = arch.widthFactor * laneWidth * 0.5;
      final Rect slab = Rect.fromLTRB(ax - halfW, 0.0, ax + halfW, arch.bottomY);

      _fillPaint.color = stoneColor.withOpacity(0.95);
      canvas.drawRect(slab, _fillPaint);

      // Hazard lip + warning under-glow.
      _fillPaint.color = SplitPalette.hazardCrimson.withOpacity(0.75);
      canvas.drawRect(
        Rect.fromLTRB(
          ax - halfW,
          arch.bottomY - 5.0,
          ax + halfW,
          arch.bottomY,
        ),
        _fillPaint,
      );
      _fillPaint.color = SplitPalette.hazardCrimson.withOpacity(0.12);
      canvas.drawRect(
        Rect.fromLTRB(ax - halfW - 4.0, arch.bottomY - 9.0, ax + halfW + 4.0, arch.bottomY),
        _fillPaint,
      );
    }

    // 2. Tide gauge on the lane's outer edge.
    final double gaugeX = laneLeft + 8.0;
    final double gaugeTop =
        size.height *
        (math.max(0.0,
                PhysicsConstants.tideSurfaceBaseFactor -
                    PhysicsConstants.tideSurfaceRangeFactor) -
            0.04);
    final double gaugeBottom = size.height * PhysicsConstants.tideSurfaceBaseFactor;
    _strokePaint
      ..color = fgColor.withOpacity(0.35)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(gaugeX, gaugeTop),
      Offset(gaugeX, gaugeBottom),
      _strokePaint,
    );
    _strokePaint.strokeWidth = 4.0;
    _strokePaint.color = valveOpen
        ? SplitPalette.nearMissCyan
        : fgColor.withOpacity(0.8);
    canvas.drawLine(
      Offset(gaugeX - 4.0, surfaceY),
      Offset(gaugeX + 4.0, surfaceY),
      _strokePaint,
    );

    // 3. Submarine — a buoyant capsule riding just under the crest.
    if (valveOpen) {
      // Charging bloom while the tide is being commanded.
      _fillPaint.color = fgColor.withOpacity(0.08 + 0.05 * math.sin(animTime * 6.0));
      canvas.drawCircle(Offset(subX, subY), 26.0, _fillPaint);
    }

    final double bodyW = laneWidth * 0.15;
    final double bodyH = bodyW * 0.52;
    final Rect hull = Rect.fromCenter(
      center: Offset(subX, subY),
      width: bodyW,
      height: bodyH,
    );
    _capsulePath
      ..reset()
      ..addRRect(
        RRect.fromRectAndRadius(hull, Radius.circular(bodyH * 0.5)),
      );
    _fillPaint.color = isOverdrive
        ? SplitPalette.goldBright
        : SplitPalette.nearMissCyan;
    canvas.drawPath(_capsulePath, _fillPaint);

    // Observation porthole + periscope mast.
    _fillPaint.color = Colors.black87;
    canvas.drawCircle(Offset(subX + bodyW * 0.18, subY), bodyH * 0.22, _fillPaint);
    _fillPaint.color = Colors.white70;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(subX - bodyW * 0.18, subY - bodyH * 0.62),
        width: bodyW * 0.30,
        height: bodyH * 0.30,
      ),
      _fillPaint,
    );

    // 4. Directive watermark.
    paintDirective(
      canvas,
      laneLeft,
      laneWidth,
      size.height,
      valveOpen ? 'HOLD: TIDE RISES ▲' : 'RELEASED: TIDE DRAINS ▼',
    );
  }

  /// Right mechanic: barnacle stems, urchins and the harvester buoy.
  static void paintHarvester({
    required Canvas canvas,
    required Size size,
    required List<TideBarnacle> barnacles,
    required List<TideUrchin> urchins,
    required double laneLeft,
    required double laneRight,
    required double surfaceY,
    required double buoyX,
    required double buoyY,
    required double animTime,
    required Color fgColor,
    required bool isOverdrive,
  }) {
    final double laneWidth = laneRight - laneLeft;

    // 1. Barnacle bulbs hanging on swaying stems.
    for (final TideBarnacle bulb in barnacles) {
      final double bx = laneLeft + (bulb.xFactor + bulb.swayFactor) * laneWidth;
      final double glow = (1.0 - (bulb.depthY - buoyY).abs() / (size.height * 0.12))
          .clamp(0.0, 1.0);

      _strokePaint
        ..color = SplitPalette.matrixGreen.withOpacity(0.35)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(bx, 0.0), Offset(bx, bulb.depthY), _strokePaint);

      _fillPaint.color = SplitPalette.matrixGreen.withOpacity(0.45 + glow * 0.5);
      canvas.drawCircle(Offset(bx, bulb.depthY), 5.5, _fillPaint);
      _fillPaint.color = Colors.white.withOpacity(glow * 0.8);
      canvas.drawCircle(Offset(bx, bulb.depthY - 1.5), 2.0, _fillPaint);
    }

    // 2. Patrolling urchins.
    for (final TideUrchin urchin in urchins) {
      final double ux = laneLeft + urchin.xFactor * laneWidth;
      final double uy = urchin.y;

      _strokePaint
        ..color = SplitPalette.hazardCrimson.withOpacity(0.65)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      for (int k = 0; k < 7; k++) {
        final double angle = (k / 7) * math.pi * 2 + urchin.spinPhase;
        canvas.drawLine(
          Offset(ux + math.cos(angle) * 3.0, uy + math.sin(angle) * 3.0),
          Offset(
            ux + math.cos(angle) * (urchin.radius + 3.0),
            uy + math.sin(angle) * (urchin.radius + 3.0),
          ),
          _strokePaint,
        );
      }
      _fillPaint.color = SplitPalette.hazardCrimson.withOpacity(0.9);
      canvas.drawCircle(Offset(ux, uy), urchin.radius * 0.55, _fillPaint);
    }

    // 3. Harvester buoy — floats exactly on the shared surface.
    final double bob = math.sin(animTime * 3.0 + buoyX * 0.05) * 2.0;
    final double by = buoyY + bob;

    _strokePaint
      ..color = isOverdrive ? SplitPalette.goldBright : Colors.white70
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(buoyX, by), 8.5, _strokePaint);
    _fillPaint.color = isOverdrive
        ? SplitPalette.goldBright
        : SplitPalette.hazardCrimson;
    canvas.drawCircle(Offset(buoyX, by - 3.0), 3.5, _fillPaint);
    _fillPaint.color = fgColor.withOpacity(0.6);
    canvas.drawCircle(Offset(buoyX, by), 2.0, _fillPaint);

    // 4. Directive watermark.
    paintDirective(
      canvas,
      laneLeft,
      laneWidth,
      size.height,
      'STEER · FEED AT HIGH TIDE',
    );
  }

  static void paintDirective(
    Canvas canvas,
    double laneLeft,
    double laneWidth,
    double height,
    String text,
  ) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
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
      Offset(laneLeft + (laneWidth - tp.width) / 2, height - 35),
    );
  }
}
