import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/battery_telemetry_service.dart';

class PostProcessPainter {
  static final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _scanlinePaint = Paint()
    ..color = Colors.black.withOpacity(0.12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _vignettePaint = Paint();
  static Size _cachedVignetteSize = Size.zero;

  static void paintOverdriveEffects({
    required Canvas canvas,
    required Size size,
    required BatteryTelemetryState batteryState,
    required double survivalTime,
  }) {
    if (!batteryState.isOverdrive) return;

    // 1. Edge Pulse for Overdrive & God Mode
    final double pulse = 0.5 + 0.5 * math.sin(survivalTime * 6.0);
    final double borderAlpha = batteryState.isGodMode ? (0.4 + 0.4 * pulse) : (0.2 + 0.25 * pulse);

    _borderPaint.color = (batteryState.isGodMode ? SplitPalette.godModeGold : SplitPalette.overdriveRed)
        .withOpacity(borderAlpha);
    _borderPaint.strokeWidth = batteryState.isGodMode ? 6.0 : 4.0;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _borderPaint);

    // 2. Scanlines & Vignette in 1% GOD MODE
    if (batteryState.isGodMode) {
      _paintScanlines(canvas, size, survivalTime);
      _paintVignette(canvas, size);
    }
  }

  static void paintThemeVisualShaders({
    required Canvas canvas,
    required Size size,
    required String themeName,
    required double survivalTime,
  }) {
    if (themeName == 'synthwave') {
      _paintSynthwaveGrid(canvas, size, survivalTime);
    } else if (themeName == 'matrix') {
      _paintMatrixScanlines(canvas, size, survivalTime);
    } else if (themeName == 'cyberGold') {
      _paintCyberGoldBorder(canvas, size, survivalTime);
    }
  }

  static void _paintSynthwaveGrid(Canvas canvas, Size size, double time) {
    final Paint gridPaint = Paint()
      ..color = SplitPalette.synthwavePink.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Moving horizontal grid lines
    const double step = 28.0;
    final double offset = (time * 40.0) % step;
    for (double y = offset; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Subtle perspective vertical grid lines
    for (double x = 0; x < size.width; x += 40.0) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  static void _paintMatrixScanlines(Canvas canvas, Size size, double time) {
    final Paint matrixPaint = Paint()
      ..color = SplitPalette.matrixGreen.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const double step = 6.0;
    final double offsetY = (time * 80.0) % step;
    for (double y = offsetY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), matrixPaint);
    }
  }

  static void _paintCyberGoldBorder(Canvas canvas, Size size, double time) {
    final double pulse = 0.5 + 0.5 * math.sin(time * 3.0);
    final Paint goldPaint = Paint()
      ..color = SplitPalette.goldBright.withOpacity(0.15 + 0.15 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), goldPaint);
  }

  static void _paintScanlines(Canvas canvas, Size size, double time) {
    const double step = 8.0;
    final double offsetY = (time * 60.0) % step;
    for (double y = offsetY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _scanlinePaint);
    }
  }

  static void _paintVignette(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    if (_cachedVignetteSize != size) {
      _cachedVignetteSize = size;
      _vignettePaint.shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.45),
        ],
        stops: const [0.65, 1.0],
      ).createShader(rect);
    }

    canvas.drawRect(rect, _vignettePaint);
  }
}
