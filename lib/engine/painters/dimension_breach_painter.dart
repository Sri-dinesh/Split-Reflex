import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../entities/dimension_breach_entity.dart';
import '../hemisphere_state.dart';

class DimensionBreachPainter {
  static final Paint _paddlePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _paddleGlowPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _ballCorePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _ballGlowPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _slitBracketPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;
  static final Paint _slitFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _minePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _mineBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  /// Paints the hemisphere-specific content (paddle, gravity vector field, mines).
  static void paintHemisphere({
    required Canvas canvas,
    required Size size,
    required DimensionBreachEntity breach,
    required bool isLeft,
    required HemisphereMechanic mechanic,
    required bool inverted,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required double survivalTime,
    required bool isAlive,
    required bool isOverdrive,
  }) {
    // 1. Subtle Gravity Flux Field
    // breachAlpha is Zero-G (pulls up unless inverted).
    // breachBeta is Heavy-G (pulls down unless inverted).
    final bool isAlpha = mechanic == HemisphereMechanic.breachAlpha;
    final bool isUpward = isAlpha ^ inverted;
    _paintGravityVectorField(
      canvas: canvas,
      laneLeft: laneLeft,
      laneRight: laneRight,
      height: size.height,
      isUpward: isUpward,
      survivalTime: survivalTime,
      color: fgColor.withOpacity(0.08),
    );

    // 2. Hazard Mines strictly within this lane
    for (final mine in breach.mines) {
      if (mine.x >= laneLeft && mine.x < laneRight) {
        _paintHazardMine(canvas, mine, survivalTime);
      }
    }

    // 3. Paddle Deflector (Fixed to the outer edge of this hemisphere)
    if (isAlive) {
      final double paddleX = isLeft
          ? laneLeft + 26.0
          : laneRight - 26.0;
      final double paddleY = isLeft ? breach.paddleLeftY : breach.paddleRightY;
      final Color paddleColor = isAlpha
          ? SplitPalette.nearMissCyan
          : (isOverdrive ? SplitPalette.overdriveRed : SplitPalette.hazardCrimson);

      _paintPaddle(
        canvas: canvas,
        x: paddleX,
        y: paddleY,
        width: DimensionBreachEntity.paddleWidth,
        height: DimensionBreachEntity.paddleHeight,
        color: paddleColor,
        isLeft: isLeft,
      );

      // 4. Dedicated Bottom Space Thumb Control Guide Rail
      _paintBottomThumbControlRail(
        canvas: canvas,
        size: size,
        breach: breach,
        isLeft: isLeft,
        laneLeft: laneLeft,
        laneRight: laneRight,
        color: paddleColor,
        fgColor: fgColor,
      );
    } else {
      // Offline Emergency Forcefield Mesh
      final double wallX = isLeft ? laneLeft + 26.0 : laneRight - 26.0;
      _paintOfflineEmergencyBarrier(canvas, wallX, size.height, survivalTime);
    }
  }

  /// Paints the shared global elements across the center divider:
  /// The moving Breach Slit Window, and the Singularity Orb with Comet Tail.
  static void paintBreachWindowAndOrb({
    required Canvas canvas,
    required Size size,
    required DimensionBreachEntity breach,
    required double splitX,
    required double survivalTime,
    required bool isOverdrive,
    bool isLeftAlpha = true,
  }) {
    // 1. Draw Breach Slit Brackets & Aperture
    final double slitY = breach.slitY;
    final double halfH = breach.slitHalfHeight;

    // Glowing Aperture Fill (with explicit colorStops to prevent length mismatch error)
    final Rect slitRect = Rect.fromCenter(
      center: Offset(splitX, slitY),
      width: 16.0,
      height: halfH * 2.0,
    );
    _slitFillPaint.shader = ui.Gradient.linear(
      Offset(splitX, slitY - halfH),
      Offset(splitX, slitY + halfH),
      [
        SplitPalette.nearMissCyan.withOpacity(0.35),
        Colors.white.withOpacity(0.55),
        SplitPalette.hazardCrimson.withOpacity(0.35),
      ],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slitRect, const Radius.circular(8.0)),
      _slitFillPaint,
    );

    // Top & Bottom Slit Brackets
    _slitBracketPaint.color = isLeftAlpha ? SplitPalette.nearMissCyan : SplitPalette.hazardCrimson;
    _slitBracketPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawLine(
      Offset(splitX - 18.0, slitY - halfH),
      Offset(splitX + 18.0, slitY - halfH),
      _slitBracketPaint,
    );
    _slitBracketPaint.color = isLeftAlpha ? SplitPalette.hazardCrimson : SplitPalette.nearMissCyan;
    canvas.drawLine(
      Offset(splitX - 18.0, slitY + halfH),
      Offset(splitX + 18.0, slitY + halfH),
      _slitBracketPaint,
    );
    _slitBracketPaint.maskFilter = null;

    // Center Singularity Diamond Pip
    final Paint diamondPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Path diamondPath = Path()
      ..moveTo(splitX, slitY - 7.0)
      ..lineTo(splitX + 6.0, slitY)
      ..lineTo(splitX, slitY + 7.0)
      ..lineTo(splitX - 6.0, slitY)
      ..close();
    canvas.drawPath(diamondPath, diamondPaint);

    // 2. Draw Singularity Orb Comet Tail
    if (breach.trail.isNotEmpty) {
      for (int i = 0; i < breach.trail.length; i++) {
        final double alpha = (i + 1) / breach.trail.length;
        final double radius = DimensionBreachEntity.ballRadius * (0.35 + 0.65 * alpha);
        final pos = breach.trail[i];
        final bool isPosAlpha = (pos.dx < splitX) ? isLeftAlpha : !isLeftAlpha;
        final Color trailColor = isPosAlpha
            ? SplitPalette.nearMissCyan
            : SplitPalette.hazardCrimson;

        final Paint trailPaint = Paint()
          ..color = trailColor.withOpacity(0.30 * alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, radius, trailPaint);
      }
    }

    // 3. Draw The Singularity Orb Core (Ultra High Visibility)
    final Offset ballPos = Offset(breach.ballX, breach.ballY);
    final bool isBallAlpha = (breach.ballX < splitX) ? isLeftAlpha : !isLeftAlpha;
    final Color auraColor = isBallAlpha
        ? SplitPalette.nearMissCyan
        : (isOverdrive ? SplitPalette.overdriveRed : SplitPalette.hazardCrimson);

    // Outer Bloom Glow
    _ballGlowPaint.color = auraColor.withOpacity(0.5);
    _ballGlowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawCircle(ballPos, DimensionBreachEntity.ballRadius * 2.2, _ballGlowPaint);
    _ballGlowPaint.maskFilter = null;

    // Radiant Color Ring
    _ballGlowPaint.color = auraColor;
    canvas.drawCircle(ballPos, DimensionBreachEntity.ballRadius * 1.25, _ballGlowPaint);

    // Pure White Dense Core
    _ballCorePaint.color = Colors.white;
    canvas.drawCircle(ballPos, DimensionBreachEntity.ballRadius * 0.7, _ballCorePaint);

    // Dynamic Trajectory Heading Pointer Arrow
    final double speed = math.sqrt(breach.ballVx * breach.ballVx + breach.ballVy * breach.ballVy);
    if (speed > 10.0) {
      final double ndx = breach.ballVx / speed;
      final double ndy = breach.ballVy / speed;
      final Paint pointerPaint = Paint()
        ..color = Colors.white.withOpacity(0.65)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        ballPos + Offset(ndx * 14.0, ndy * 14.0),
        ballPos + Offset(ndx * 26.0, ndy * 26.0),
        pointerPaint,
      );
    }
  }

  static void _paintPaddle({
    required Canvas canvas,
    required double x,
    required double y,
    required double width,
    required double height,
    required Color color,
    required bool isLeft,
  }) {
    final Rect paddleRect = Rect.fromCenter(
      center: Offset(x, y),
      width: width,
      height: height,
    );
    final RRect paddleRRect = RRect.fromRectAndRadius(
      paddleRect,
      const Radius.circular(8.0),
    );

    // Outer Glow
    _paddleGlowPaint.color = color.withOpacity(0.6);
    _paddleGlowPaint.strokeWidth = 3.0;
    _paddleGlowPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawRRect(paddleRRect, _paddleGlowPaint);
    _paddleGlowPaint.maskFilter = null;

    // Body
    _paddlePaint.color = color;
    canvas.drawRRect(paddleRRect, _paddlePaint);

    // Center Core Laser Line
    final Paint corePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(x, y - height * 0.35),
      Offset(x, y + height * 0.35),
      corePaint,
    );

    // Grip Nodes
    final Paint gripPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = -3; i <= 3; i++) {
      final double gy = y + i * 8.0;
      canvas.drawLine(Offset(x - 3.5, gy), Offset(x + 3.5, gy), gripPaint);
    }
  }

  static void _paintGravityVectorField({
    required Canvas canvas,
    required double laneLeft,
    required double laneRight,
    required double height,
    required bool isUpward,
    required double survivalTime,
    required Color color,
  }) {
    final Paint chevronPaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final double midX = (laneLeft + laneRight) * 0.5;
    const double spacing = 90.0;
    final double flowOffset = (survivalTime * (isUpward ? -80.0 : 80.0)) % spacing;

    for (double y = -spacing; y < height + spacing; y += spacing) {
      final double cy = y + flowOffset;
      final Path chevron = Path();
      if (isUpward) {
        // Upward chevron (^)
        chevron.moveTo(midX - 14.0, cy + 6.0);
        chevron.lineTo(midX, cy - 6.0);
        chevron.lineTo(midX + 14.0, cy + 6.0);
      } else {
        // Downward chevron (v)
        chevron.moveTo(midX - 14.0, cy - 6.0);
        chevron.lineTo(midX, cy + 6.0);
        chevron.lineTo(midX + 14.0, cy - 6.0);
      }
      canvas.drawPath(chevron, chevronPaint);
    }
  }

  static void _paintHazardMine(
    Canvas canvas,
    BreachHazardMine mine,
    double survivalTime,
  ) {
    canvas.save();
    canvas.translate(mine.x, mine.y);
    canvas.rotate(mine.pulseAngle);

    final double r = mine.radius;
    final Path diamond = Path()
      ..moveTo(0, -r)
      ..lineTo(r, 0)
      ..lineTo(0, r)
      ..lineTo(-r, 0)
      ..close();

    _minePaint.color = const Color(0xFF140306);
    canvas.drawPath(diamond, _minePaint);

    _mineBorderPaint.color = SplitPalette.hazardCrimson;
    _mineBorderPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(diamond, _mineBorderPaint);
    _mineBorderPaint.maskFilter = null;
    canvas.drawPath(diamond, _mineBorderPaint);

    // Center Alert Node
    final Paint nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 3.0, nodePaint);

    canvas.restore();
  }

  static void _paintOfflineEmergencyBarrier(
    Canvas canvas,
    double x,
    double height,
    double survivalTime,
  ) {
    final Paint linePaint = Paint()
      ..color = SplitPalette.hazardCrimson.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x, height), linePaint);
  }

  static void _paintBottomThumbControlRail({
    required Canvas canvas,
    required Size size,
    required DimensionBreachEntity breach,
    required bool isLeft,
    required double laneLeft,
    required double laneRight,
    required Color color,
    required Color fgColor,
  }) {
    final double zoneTop = size.height * DimensionBreachEntity.bottomZoneTopFactor;
    final double zoneBottom = size.height - DimensionBreachEntity.bottomZoneBottomMargin;
    final double zoneHeight = zoneBottom - zoneTop;

    const double minMargin = 60.0;
    final double minPaddleY = minMargin + DimensionBreachEntity.paddleHeight * 0.5;
    final double maxPaddleY = size.height - minMargin - DimensionBreachEntity.paddleHeight * 0.5;
    final double currentPaddleY = isLeft ? breach.paddleLeftY : breach.paddleRightY;
    final double normalized =
        ((currentPaddleY - minPaddleY) / (maxPaddleY - minPaddleY)).clamp(0.0, 1.0);

    // Place the guide rail in the natural thumb resting area of this hemisphere
    final double railX = isLeft
        ? laneLeft + (laneRight - laneLeft) * 0.45
        : laneLeft + (laneRight - laneLeft) * 0.55;
    final double sliderY = zoneTop + normalized * zoneHeight;

    // 1. Vertical Guide Rail Line (matching Dart's rail styling)
    final Paint railPaint = Paint()
      ..color = fgColor.withOpacity(0.14)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(railX, zoneTop), Offset(railX, zoneBottom), railPaint);

    // 2. Rail End Brackets & Midpoint Tick
    final Paint bracketPaint = Paint()
      ..color = fgColor.withOpacity(0.28)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(railX - 8.0, zoneTop), Offset(railX + 8.0, zoneTop), bracketPaint);
    canvas.drawLine(Offset(railX - 8.0, zoneBottom), Offset(railX + 8.0, zoneBottom), bracketPaint);

    final double midY = (zoneTop + zoneBottom) * 0.5;
    canvas.drawLine(Offset(railX - 4.0, midY), Offset(railX + 4.0, midY), bracketPaint);

    // 3. Glowing Slider Grip Capsule
    final Rect gripRect = Rect.fromCenter(
      center: Offset(railX, sliderY),
      width: 18.0,
      height: 28.0,
    );
    final RRect gripRRect = RRect.fromRectAndRadius(gripRect, const Radius.circular(6.0));

    // Outer Glow
    final Paint gripGlowPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(gripRRect, gripGlowPaint);

    // Capsule Fill
    final Paint gripFillPaint = Paint()
      ..color = const Color(0xFF0C0C12).withOpacity(0.88)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(gripRRect, gripFillPaint);

    // Capsule Border
    final Paint gripBorderPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(gripRRect, gripBorderPaint);

    // Center Laser Core Notch
    final Paint notchPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(railX - 4.0, sliderY), Offset(railX + 4.0, sliderY), notchPaint);
  }
}
