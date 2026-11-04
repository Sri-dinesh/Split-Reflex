import 'package:flutter/material.dart';

import '../entities/particle_pool.dart';
import '../game_controller.dart';
import '../hemisphere_state.dart';
import 'dart_hemisphere_painter.dart';
import 'dimension_breach_painter.dart';
import 'divider_painter.dart';
import 'orb_hemisphere_painter.dart';
import 'shield_hemisphere_painter.dart';
import 'quantum_hemisphere_painter.dart';
import 'post_process_painter.dart';

class MasterGamePainter extends CustomPainter {
  final GameController controller;

  static final Paint _leftBgPaint = Paint();
  static final Paint _rightBgPaint = Paint();
  static final Paint _particleFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _particleLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final Path _triPath = Path();

  MasterGamePainter({required this.controller}) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    controller.updateDimensions(size.width, size.height);

    canvas.save();

    // 1. Camera Screen Shake
    if (controller.cameraShake != Offset.zero) {
      canvas.translate(controller.cameraShake.dx, controller.cameraShake.dy);
    }

    // 2. Death Zoom toward failure focal point
    if (controller.state == GamePlayState.deathSlowmo &&
        controller.deathZoom > 1.0) {
      canvas.translate(
        controller.deathFocusPoint.dx,
        controller.deathFocusPoint.dy,
      );
      canvas.scale(controller.deathZoom);
      canvas.translate(
        -controller.deathFocusPoint.dx,
        -controller.deathFocusPoint.dy,
      );
    }

    final double splitX = controller.hemisphereState.rawSplitPixels;
    final Rect leftRect = Rect.fromLTWH(0, 0, splitX, size.height);
    final Rect rightRect = Rect.fromLTWH(
      splitX,
      0,
      size.width - splitX,
      size.height,
    );

    // 3. Render Left Hemisphere
    canvas.save();
    canvas.clipRect(leftRect);
    _leftBgPaint.color = controller.hemisphereState.leftBg;
    canvas.drawRect(leftRect, _leftBgPaint);
    _paintHemisphereContent(
      canvas: canvas,
      size: size,
      mechanic: controller.hemisphereState.leftMechanic,
      isLeft: true,
      laneLeft: 0.0,
      laneRight: splitX,
      fgColor: controller.hemisphereState.leftFg,
      bgColor: controller.hemisphereState.leftBg,
    );
    canvas.restore();

    // 4. Render Right Hemisphere
    canvas.save();
    canvas.clipRect(rightRect);
    _rightBgPaint.color = controller.hemisphereState.rightBg;
    canvas.drawRect(rightRect, _rightBgPaint);
    _paintHemisphereContent(
      canvas: canvas,
      size: size,
      mechanic: controller.hemisphereState.rightMechanic,
      isLeft: false,
      laneLeft: splitX,
      laneRight: size.width,
      fgColor: controller.hemisphereState.rightFg,
      bgColor: controller.hemisphereState.rightBg,
    );
    canvas.restore();

    // 5. Render Object-Pooled Particles (Rendered across divider without clipping)
    _paintParticles(canvas, controller.particlePool);

    // 6. Render The Corpus Callosum (Center Divider)
    DividerPainter.paint(
      canvas: canvas,
      size: size,
      hemisphereState: controller.hemisphereState,
      survivalTime: controller.survivalTime,
    );

    // 6.1 Render Dimension Breach Center Slit Window & Singularity Orb (across divider)
    if (controller.gamePairMode == GamePairMode.dimensionBreach) {
      final bool isLeftAlpha =
          controller.hemisphereState.leftMechanic == HemisphereMechanic.breachAlpha;
      DimensionBreachPainter.paintBreachWindowAndOrb(
        canvas: canvas,
        size: size,
        breach: controller.dimensionBreach,
        splitX: splitX,
        survivalTime: controller.survivalTime,
        isOverdrive: controller.batteryState.isOverdrive,
        isLeftAlpha: isLeftAlpha,
      );
    }

    // 7. Render Post-Process Shader / Overdrive / Scanline Effects
    PostProcessPainter.paintThemeVisualShaders(
      canvas: canvas,
      size: size,
      themeName: controller.theme.name,
      survivalTime: controller.survivalTime,
    );

    PostProcessPainter.paintOverdriveEffects(
      canvas: canvas,
      size: size,
      batteryState: controller.batteryState,
      survivalTime: controller.survivalTime,
    );

    canvas.restore();
  }

  void _paintHemisphereContent({
    required Canvas canvas,
    required Size size,
    required HemisphereMechanic mechanic,
    required bool isLeft,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
  }) {
    final bool isAlive = controller.isMechanicAlive(mechanic);

    if (isAlive) {
      switch (mechanic) {
        case HemisphereMechanic.orb:
          OrbHemispherePainter.paint(
            canvas: canvas,
            size: size,
            orb: controller.orb,
            laserGates: controller.laserGates,
            laneLeft: laneLeft,
            laneRight: laneRight,
            fgColor: fgColor,
            bgColor: bgColor,
            survivalTime: controller.survivalTime,
            isOverdrive: controller.batteryState.isOverdrive,
          );
          break;
        case HemisphereMechanic.dart:
          DartHemispherePainter.paint(
            canvas: canvas,
            size: size,
            dart: controller.dart,
            monoliths: controller.monoliths,
            laneLeft: laneLeft,
            laneRight: laneRight,
            fgColor: fgColor,
            bgColor: bgColor,
            inverted: controller.hemisphereState.isPolarityInverted,
            isOverdrive: controller.batteryState.isOverdrive,
          );
          break;
        case HemisphereMechanic.breachAlpha:
        case HemisphereMechanic.breachBeta:
          DimensionBreachPainter.paintHemisphere(
            canvas: canvas,
            size: size,
            breach: controller.dimensionBreach,
            isLeft: isLeft,
            mechanic: mechanic,
            inverted: controller.hemisphereState.isPolarityInverted,
            laneLeft: laneLeft,
            laneRight: laneRight,
            fgColor: fgColor,
            bgColor: bgColor,
            survivalTime: controller.survivalTime,
            isAlive: isAlive,
            isOverdrive: controller.batteryState.isOverdrive,
          );
          break;
        case HemisphereMechanic.shieldPing:
          ShieldHemispherePainter.paint(
            canvas: canvas,
            size: size,
            shield: controller.shieldPing,
            bolts: controller.plasmaBolts,
            laneLeft: laneLeft,
            laneRight: laneRight,
            fgColor: fgColor,
            bgColor: bgColor,
            isOverdrive: controller.batteryState.isOverdrive,
          );
          break;
        case HemisphereMechanic.quantumWarp:
          QuantumHemispherePainter.paint(
            canvas: canvas,
            size: size,
            warpEntity: controller.quantumWarp,
            blockades: controller.quantumBlockades,
            laneLeft: laneLeft,
            laneRight: laneRight,
            fgColor: fgColor,
            bgColor: bgColor,
            isOverdrive: controller.batteryState.isOverdrive,
          );
          break;
      }
    }

    // If this hemisphere is destroyed in 1 Hand mode, draw decommissioned static banner
    if (!isAlive) {
      _paintDestroyedHemisphere(
        canvas,
        laneLeft,
        laneRight,
        size.height,
        fgColor,
      );
    }
  }

  void _paintDestroyedHemisphere(
    Canvas canvas,
    double laneLeft,
    double laneRight,
    double height,
    Color fgColor,
  ) {
    final Rect rect = Rect.fromLTWH(laneLeft, 0, laneRight - laneLeft, height);
    final Paint darkOverlay = Paint()
      ..color = Colors.black.withOpacity(0.65);
    canvas.drawRect(rect, darkOverlay);

    // Hazard stripes
    final Paint stripePaint = Paint()
      ..color = Colors.red.withOpacity(0.25)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    for (double y = -100; y < height + 100; y += 40) {
      canvas.drawLine(
        Offset(laneLeft, y),
        Offset(laneRight, y + 40),
        stripePaint,
      );
    }

    final tp = TextPainter(
      text: const TextSpan(
        text: 'HEMISPHERE\nOFFLINE',
        style: TextStyle(
          color: Colors.redAccent,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 3.0,
          height: 1.4,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        (laneLeft + laneRight) / 2.0 - tp.width / 2.0,
        height * 0.5 - tp.height / 2.0,
      ),
    );
  }

  void _paintParticles(Canvas canvas, ParticlePool pool) {
    for (int i = 0; i < ParticlePool.poolCapacity; i++) {
      final p = pool.particles[i];
      if (!p.active || p.alpha <= 0.0) continue;

      final Color c = p.color.withOpacity(p.alpha.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(p.x, p.y);
      if (p.angle != 0.0) canvas.rotate(p.angle);

      if (p.sides == 2) {
        // Spark line
        _particleLinePaint.color = c;
        canvas.drawLine(
          Offset(-p.size, 0),
          Offset(p.size, 0),
          _particleLinePaint,
        );
      } else if (p.sides == 3) {
        // Procedural triangle
        _particleFillPaint.color = c;
        _triPath.reset();
        _triPath.moveTo(0, -p.size);
        _triPath.lineTo(p.size, p.size);
        _triPath.lineTo(-p.size, p.size);
        _triPath.close();
        canvas.drawPath(_triPath, _particleFillPaint);
      } else {
        // Procedural rect shard
        _particleFillPaint.color = c;
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          _particleFillPaint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MasterGamePainter oldDelegate) => true;
}
