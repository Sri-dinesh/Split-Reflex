import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';

/// Highly detailed procedural vector illustration of the official Split Reflex emblem.
///
/// Matches the official app icon geometry in full detail:
/// - Squircle obsidian carbon base plate with cyber rim and dual ambient bloom
/// - Left Neon Cyan wing shifted vertically with stepped cyber notches and inner facets
/// - Right Hazard Crimson wing shifted vertically with stepped cyber notches and inner facets
/// - Pure white central singularity split rift with energy beam and apex spark nodes
/// - Supports smooth animation inputs: [dockProgress], [glowIntensity], and [seamIntensity]
class SplitDiamondEmblem extends StatelessWidget {
  final double size;
  final double dockProgress;
  final double glowIntensity;
  final double seamIntensity;

  const SplitDiamondEmblem({
    super.key,
    this.size = 80.0,
    this.dockProgress = 1.0,
    this.glowIntensity = 1.0,
    this.seamIntensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: SplitPalette.nearMissCyan.withOpacity(0.35 * glowIntensity,),
            blurRadius: size * 0.30,
            spreadRadius: 1.0,
            offset: Offset(-size * 0.06, 0),
          ),
          BoxShadow(
            color: SplitPalette.hazardCrimson.withOpacity(0.35 * glowIntensity,),
            blurRadius: size * 0.30,
            spreadRadius: 1.0,
            offset: Offset(size * 0.06, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.85),
            blurRadius: size * 0.20,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _DetailedSplitEmblemPainter(
          dockProgress: dockProgress.clamp(0.0, 1.0),
          glowIntensity: glowIntensity.clamp(0.0, 1.0),
          seamIntensity: seamIntensity.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

class _DetailedSplitEmblemPainter extends CustomPainter {
  final double dockProgress;
  final double glowIntensity;
  final double seamIntensity;

  _DetailedSplitEmblemPainter({
    required this.dockProgress,
    required this.glowIntensity,
    required this.seamIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2.0;
    final double cy = h / 2.0;
    final double radius = w * 0.22;

    // 1. Squircle Base Plate (Carbon Obsidian)
    final RRect outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(radius),
    );

    final Paint basePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: const [Color(0xFF1B1E2B), Color(0xFF0F1118), Color(0xFF07080C)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(outerRRect.outerRect);
    canvas.drawRRect(outerRRect, basePaint);

    // Subtle outer metallic cyber rim
    final Paint rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x6600F0FF), Color(0x22FFFFFF), Color(0x66FF1E42)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(outerRRect.outerRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(outerRRect, rimPaint);

    // 2. Ambient Bilateral Bloom
    if (glowIntensity > 0.01) {
      final Paint cyanBloom = Paint()
        ..color = SplitPalette.nearMissCyan.withOpacity(0.20 * glowIntensity,)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18);
      canvas.drawCircle(
        Offset(cx - w * 0.18, cy - h * 0.08),
        w * 0.22,
        cyanBloom,
      );

      final Paint crimsonBloom = Paint()
        ..color = SplitPalette.hazardCrimson.withOpacity(0.20 * glowIntensity,)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18);
      canvas.drawCircle(
        Offset(cx + w * 0.18, cy + h * 0.08),
        w * 0.22,
        crimsonBloom,
      );
    }

    // Docking animation separation offset
    final double sep = 1.0 - dockProgress;
    final double leftDx = -w * 0.18 * sep;
    final double leftDy = -h * 0.10 * sep;
    final double rightDx = w * 0.18 * sep;
    final double rightDy = h * 0.10 * sep;

    final double riftGap = w * 0.018;

    // --- LEFT HEMISPHERE (CYAN WING - SHIFTED UPWARDS) ---
    canvas.save();
    canvas.translate(leftDx, leftDy);

    final Path leftOuter = Path()
      ..moveTo(cx - riftGap, cy - h * 0.40) // Top rift apex
      ..lineTo(cx - w * 0.29, cy - h * 0.16) // Upper slope
      ..lineTo(cx - w * 0.35, cy - h * 0.12) // Outer notch step out
      ..lineTo(cx - w * 0.35, cy - h * 0.02) // Outer notch step vertical
      ..lineTo(cx - w * 0.29, cy + h * 0.02) // Outer notch step in
      ..lineTo(cx - riftGap, cy + h * 0.20) // Bottom slope to rift
      ..close();

    final Paint leftFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF00C8DB),
          SplitPalette.nearMissCyan,
          Color(0xFFE0FFFF),
          Colors.white,
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(leftOuter.getBounds());
    canvas.drawPath(leftOuter, leftFill);

    // Left outer cyber neon stroke
    final Paint leftStroke = Paint()
      ..color = SplitPalette.nearMissCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(leftOuter, leftStroke);

    // Left inner tech facet
    final Path leftInnerFacet = Path()
      ..moveTo(cx - riftGap * 1.5, cy - h * 0.30)
      ..lineTo(cx - w * 0.23, cy - h * 0.13)
      ..lineTo(cx - w * 0.27, cy - h * 0.09)
      ..lineTo(cx - w * 0.23, cy - h * 0.03)
      ..lineTo(cx - riftGap * 1.5, cy + h * 0.12)
      ..close();

    final Paint leftFacetPaint = Paint()
      ..color = const Color(0xFF002B33).withOpacity(0.70)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftInnerFacet, leftFacetPaint);

    final Paint leftFacetBorder = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(leftInnerFacet, leftFacetBorder);

    canvas.restore();

    // --- RIGHT HEMISPHERE (CRIMSON WING - SHIFTED DOWNWARDS) ---
    canvas.save();
    canvas.translate(rightDx, rightDy);

    final Path rightOuter = Path()
      ..moveTo(cx + riftGap, cy - h * 0.20) // Top rift start
      ..lineTo(cx + w * 0.29, cy - h * 0.02) // Upper slope
      ..lineTo(cx + w * 0.35, cy + h * 0.02) // Outer notch step out
      ..lineTo(cx + w * 0.35, cy + h * 0.12) // Outer notch step vertical
      ..lineTo(cx + w * 0.29, cy + h * 0.16) // Outer notch step in
      ..lineTo(cx + riftGap, cy + h * 0.40) // Bottom slope to rift apex
      ..close();

    final Paint rightFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: const [
          Color(0xFFD60029),
          SplitPalette.hazardCrimson,
          Color(0xFFFFD1D8),
          Colors.white,
        ],
        stops: const [0.0, 0.45, 0.85, 1.0],
      ).createShader(rightOuter.getBounds());
    canvas.drawPath(rightOuter, rightFill);

    // Right outer cyber neon stroke
    final Paint rightStroke = Paint()
      ..color = SplitPalette.hazardCrimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(rightOuter, rightStroke);

    // Right inner tech facet
    final Path rightInnerFacet = Path()
      ..moveTo(cx + riftGap * 1.5, cy - h * 0.12)
      ..lineTo(cx + w * 0.23, cy + h * 0.03)
      ..lineTo(cx + w * 0.27, cy + h * 0.09)
      ..lineTo(cx + w * 0.23, cy + h * 0.13)
      ..lineTo(cx + riftGap * 1.5, cy + h * 0.30)
      ..close();

    final Paint rightFacetPaint = Paint()
      ..color = const Color(0xFF400010).withOpacity(0.70)
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightInnerFacet, rightFacetPaint);

    final Paint rightFacetBorder = Paint()
      ..color = const Color(0xFFFF2E55).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(rightInnerFacet, rightFacetBorder);

    canvas.restore();

    // --- CENTRAL SINGULARITY SEAM ---
    if (dockProgress > 0.6 && seamIntensity > 0.01) {
      final double seamAlpha = ((dockProgress - 0.6) / 0.4 * seamIntensity)
          .clamp(0.0, 1.0);

      // Energy Seam Glow
      final Paint seamGlow = Paint()
        ..color = Colors.white.withOpacity(0.6 * seamAlpha)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawLine(
        Offset(cx, cy - h * 0.38),
        Offset(cx, cy + h * 0.38),
        seamGlow,
      );

      // Core Pure White Laser Seam
      final Paint seamCore = Paint()
        ..color = Colors.white.withOpacity(0.95 * seamAlpha)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(cx, cy - h * 0.38),
        Offset(cx, cy + h * 0.38),
        seamCore,
      );

      // Singularity Spark Nodes
      final Paint sparkPaint = Paint()
        ..color = Colors.white.withOpacity(seamAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 2.8, sparkPaint);
      canvas.drawCircle(Offset(cx - riftGap, cy - h * 0.40), 1.8, sparkPaint);
      canvas.drawCircle(Offset(cx + riftGap, cy + h * 0.40), 1.8, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DetailedSplitEmblemPainter oldDelegate) {
    return oldDelegate.dockProgress != dockProgress ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.seamIntensity != seamIntensity;
  }
}
