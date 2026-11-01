import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../entities/quantum_warp_entity.dart';

class QuantumHemispherePainter {
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;

  static void paint({
    required Canvas canvas,
    required Size size,
    required QuantumWarpEntity warpEntity,
    required List<QuantumBlockade> blockades,
    required double laneLeft,
    required double laneRight,
    required Color fgColor,
    required Color bgColor,
    required bool isOverdrive,
  }) {
    final double laneWidth = laneRight - laneLeft;
    final double trackLeftX = laneLeft + laneWidth * 0.30;
    final double trackRightX = laneLeft + laneWidth * 0.70;

    // 1. Draw Dual Quantum Guide Rails
    _strokePaint
      ..color = fgColor.withOpacity(0.25)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(trackLeftX, 0), Offset(trackLeftX, size.height), _strokePaint);
    canvas.drawLine(Offset(trackRightX, 0), Offset(trackRightX, size.height), _strokePaint);

    // 2. Draw Quantum Blockades
    for (final blockade in blockades) {
      final double bx = blockade.track == QuantumTrack.left ? trackLeftX : trackRightX;
      final Rect bRect = Rect.fromCenter(center: Offset(bx, blockade.y), width: 32.0, height: blockade.height);

      _fillPaint.color = SplitPalette.hazardCrimson.withOpacity(0.85);
      canvas.drawRRect(RRect.fromRectAndRadius(bRect, const Radius.circular(6.0)), _fillPaint);

      _strokePaint
        ..color = Colors.white
        ..strokeWidth = 1.5;
      canvas.drawRRect(RRect.fromRectAndRadius(bRect, const Radius.circular(6.0)), _strokePaint);
    }

    // 3. Draw Quantum Hopper Node
    final double qx = warpEntity.currentX;
    final double qy = warpEntity.y;

    // Warp streak
    if (warpEntity.warpAnim < 1.0) {
      _strokePaint
        ..color = SplitPalette.nearMissCyan.withOpacity(1.0 - warpEntity.warpAnim)
        ..strokeWidth = 3.0;
      canvas.drawLine(Offset(warpEntity.targetX, qy), Offset(qx, qy), _strokePaint);
    }

    // Node body (futuristic diamond)
    final Path diamond = Path()
      ..moveTo(qx, qy - 14.0)
      ..lineTo(qx + 12.0, qy)
      ..lineTo(qx, qy + 14.0)
      ..lineTo(qx - 12.0, qy)
      ..close();

    _fillPaint.color = isOverdrive ? SplitPalette.goldBright : (warpEntity.track == QuantumTrack.left ? SplitPalette.nearMissCyan : Colors.purpleAccent);
    canvas.drawPath(diamond, _fillPaint);

    _strokePaint
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawPath(diamond, _strokePaint);

    // Core spark
    _fillPaint.color = Colors.white;
    canvas.drawCircle(Offset(qx, qy), 3.5, _fillPaint);
  }
}
