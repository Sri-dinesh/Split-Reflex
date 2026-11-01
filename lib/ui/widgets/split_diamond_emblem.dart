import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';

/// Kinetic, vector-rendered Split Reflex emblem.
/// Renders an authentic, vibrant cyberpunk split-diamond with dual-hemisphere
/// energy cores, glowing cyber borders, and a central singularity split rift.
class SplitDiamondEmblem extends StatelessWidget {
  final double size;
  final bool animateGlow;

  const SplitDiamondEmblem({
    super.key,
    this.size = 76.0,
    this.animateGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: SplitPalette.nearMissCyan.withOpacity(0.4),
            blurRadius: size * 0.35,
            spreadRadius: 1.0,
            offset: Offset(-size * 0.08, 0),
          ),
          BoxShadow(
            color: SplitPalette.hazardCrimson.withOpacity(0.4),
            blurRadius: size * 0.35,
            spreadRadius: 1.0,
            offset: Offset(size * 0.08, 0),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _SplitDiamondEmblemPainter(),
      ),
    );
  }
}

class _SplitDiamondEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2.0;
    final double cy = size.height / 2.0;
    final double radius = size.width * 0.44;

    // 1. Dark Void Shield Base
    final Rect baseRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius + 2.0);
    final Paint basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF161822),
          const Color(0xFF07070B),
        ],
      ).createShader(baseRect);
    canvas.drawCircle(Offset(cx, cy), radius + 2.0, basePaint);

    // Subtle outer glass ring
    final Paint ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), radius + 2.0, ringPaint);

    // 2. Diamond Geometry Coordinates
    // Top vertex: (cx, cy - radius)
    // Bottom vertex: (cx, cy + radius)
    // Left vertex: (cx - radius, cy)
    // Right vertex: (cx + radius, cy)
    final double riftGap = size.width * 0.025; // Clean central separation

    // --- LEFT HEMISPHERE (CYAN WING) ---
    final Path leftWing = Path()
      ..moveTo(cx - riftGap, cy - radius * 0.9)
      ..lineTo(cx - radius * 0.88, cy)
      ..lineTo(cx - riftGap, cy + radius * 0.9)
      ..close();

    // Left Wing Gradient Fill (Cyan to Diamond White)
    final Paint leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          SplitPalette.nearMissCyan,
          Color(0xFFE0FFFF),
          Colors.white,
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(leftWing.getBounds());
    canvas.drawPath(leftWing, leftPaint);

    // Left Wing Stroke / Edge Highlight
    final Paint leftStroke = Paint()
      ..color = SplitPalette.nearMissCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(leftWing, leftStroke);

    // Left Core Inner Facet
    final Path leftFacet = Path()
      ..moveTo(cx - riftGap * 1.5, cy - radius * 0.5)
      ..lineTo(cx - radius * 0.45, cy)
      ..lineTo(cx - riftGap * 1.5, cy + radius * 0.5)
      ..close();
    final Paint leftFacetPaint = Paint()
      ..color = const Color(0xFF003844).withOpacity(0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftFacet, leftFacetPaint);

    // --- RIGHT HEMISPHERE (CRIMSON WING) ---
    final Path rightWing = Path()
      ..moveTo(cx + riftGap, cy - radius * 0.9)
      ..lineTo(cx + radius * 0.88, cy)
      ..lineTo(cx + riftGap, cy + radius * 0.9)
      ..close();

    // Right Wing Gradient Fill (Crimson to Diamond White)
    final Paint rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          SplitPalette.hazardCrimson,
          Color(0xFFFFB2C0),
          Colors.white,
        ],
        stops: [0.0, 0.65, 1.0],
      ).createShader(rightWing.getBounds());
    canvas.drawPath(rightWing, rightPaint);

    // Right Wing Stroke / Edge Highlight
    final Paint rightStroke = Paint()
      ..color = SplitPalette.hazardCrimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(rightWing, rightStroke);

    // Right Core Inner Facet
    final Path rightFacet = Path()
      ..moveTo(cx + riftGap * 1.5, cy - radius * 0.5)
      ..lineTo(cx + radius * 0.45, cy)
      ..lineTo(cx + riftGap * 1.5, cy + radius * 0.5)
      ..close();
    final Paint rightFacetPaint = Paint()
      ..color = const Color(0xFF4A0012).withOpacity(0.65)
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightFacet, rightFacetPaint);

    // 3. Central Singularity Split Line (Energy Conduit)
    final Paint riftGlow = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx, cy - radius * 0.95),
      Offset(cx, cy + radius * 0.95),
      riftGlow,
    );

    // 4. Center Singularity Spark
    final Paint sparkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 3.0, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
