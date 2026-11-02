import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../core/utils/math_utils.dart';
import '../hemisphere_state.dart';

class DividerPainter {
  static final Paint _dividerPaint = Paint()..style = PaintingStyle.stroke;
  static final Path _dividerPath = Path();

  // Pre-cached TextPainters for watermark to avoid per-frame layout() calculations
  static final Map<String, TextPainter> _watermarkCache = {};

  static TextPainter _getWatermarkPainter(String label) {
    return _watermarkCache.putIfAbsent(label, () {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: SplitPalette.hazardCrimson.withOpacity(0.4),
            fontSize: 72,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            letterSpacing: 4.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    });
  }

  static void paint({
    required Canvas canvas,
    required Size size,
    required HemisphereState hemisphereState,
    required double survivalTime,
  }) {
    final double splitX = hemisphereState.rawSplitPixels;
    final double height = size.height;

    // Amplitude for pre-swap vibration
    double vibrationAmp = 0.0;
    if (hemisphereState.isSwapWarning) {
      final double progress =
          (2.0 - hemisphereState.swapWarningRemaining).clamp(0.0, 2.0) / 2.0;
      vibrationAmp = progress * 14.0;
    }

    _dividerPaint.color =
        (hemisphereState.isSwapWarning
                ? SplitPalette.hazardCrimson
                : hemisphereState.leftFg)
            .withOpacity(0.85);
    _dividerPaint.strokeWidth = hemisphereState.isSwapWarning ? 3.5 : 2.0;

    // Fast-path: straight line when calm (no vibration or swap wave)
    if (vibrationAmp == 0.0 && !hemisphereState.isSwapping) {
      canvas.drawLine(Offset(splitX, 0), Offset(splitX, height), _dividerPaint);
    } else {
      // Build Bezier wave only during active warning or swap transition
      _dividerPath.reset();
      const int segments = 16;
      final double stepY = height / segments;

      _dividerPath.moveTo(splitX, 0);

      for (int i = 1; i <= segments; i++) {
        final double prevY = (i - 1) * stepY;
        final double curY = i * stepY;
        final double midY = (prevY + curY) / 2.0;

        double displaceX = 0.0;
        if (vibrationAmp > 0.0) {
          displaceX =
              vibrationAmp * math.sin(midY * 0.05 + survivalTime * 40.0);
        } else if (hemisphereState.isSwapping) {
          final double delta = 30.0 * (1.0 - hemisphereState.swapProgress);
          displaceX = MathUtils.dampedSpring(
            target: 0.0,
            delta: delta,
            timeElapsed: hemisphereState.swapTransitionElapsed,
          );
        }

        _dividerPath.quadraticBezierTo(splitX + displaceX, midY, splitX, curY);
      }

      canvas.drawPath(_dividerPath, _dividerPaint);
    }

    // Draw Watermark Countdown when warning is active
    if (hemisphereState.isSwapWarning) {
      final int count = hemisphereState.swapWarningRemaining.ceil();
      final String label = count <= 0 ? 'SWAP' : count.toString();
      final TextPainter textPainter = _getWatermarkPainter(label);

      final Offset textOffset = Offset(
        splitX - textPainter.width / 2.0,
        height * 0.45 - textPainter.height / 2.0,
      );

      textPainter.paint(canvas, textOffset);
    }
  }
}
