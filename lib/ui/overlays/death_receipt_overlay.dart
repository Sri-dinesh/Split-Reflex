import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/haptic_choreographer.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../../engine/game_controller.dart';

class DeathReceiptOverlay extends StatefulWidget {
  final DeathAutopsy autopsy;
  final GameController? controller;
  final VoidCallback onRetry;
  final VoidCallback? onReturnToMenu;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback? onOpenSettings;

  const DeathReceiptOverlay({
    super.key,
    required this.autopsy,
    this.controller,
    required this.onRetry,
    this.onReturnToMenu,
    required this.onOpenLeaderboard,
    this.onOpenSettings,
  });

  @override
  State<DeathReceiptOverlay> createState() => _DeathReceiptOverlayState();
}

class _DeathReceiptOverlayState extends State<DeathReceiptOverlay> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    if (_isSharing) return;
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _isSharing = true);

    try {
      final boundary =
          _receiptBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      await _pruneOldReceipts(tempDir);
      final file = File(
        '${tempDir.path}/split_reflex_autopsy_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Split Reflex death receipt',
        text:
            'My reflexes short-circuited in ${widget.autopsy.survivalTime.toStringAsFixed(2)}s at ${widget.autopsy.batteryPct}% battery on Split Reflex. Can you beat ${widget.autopsy.finalScore} pts?',
        sharePositionOrigin: box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      debugPrint('Share failed: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// Deletes receipt PNGs left behind by earlier shares so the cache does not
  /// grow without bound. Best-effort: failures are ignored.
  Future<void> _pruneOldReceipts(Directory tempDir) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final entity in tempDir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('split_reflex_autopsy_')) continue;
        if (!name.endsWith('.png')) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Receipt cache prune failed: $e');
    }
  }

  String _formatTimer(double seconds) {
    final int mins = (seconds / 60).floor();
    final double secs = seconds % 60;
    final String minStr = mins.toString().padLeft(2, '0');
    final String secStr = secs.toStringAsFixed(2).padLeft(5, '0');
    return '$minStr:$secStr';
  }

  @override
  Widget build(BuildContext context) {
    final autopsy = widget.autopsy;
    final isGod = autopsy.batteryPct == 1 && autopsy.wasOverdrive;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // RepaintBoundary for capture
            RepaintBoundary(
              key: _receiptBoundaryKey,
              child: ClipPath(
                clipper: SawtoothReceiptClipper(sawtoothSize: 7.0),
                child: Container(
                  width: math.min(
                    360.0,
                    MediaQuery.of(context).size.width - 48.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 28.0,
                  ),
                  decoration: const BoxDecoration(color: Color(0xFFF9F9F9)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Text(
                        'SPLIT REFLEX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      const Text(
                        'COGNITIVE AUTOPSY REPORT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14.0),
                      _buildReceiptDashedLine(),
                      const SizedBox(height: 14.0),

                      // Primary Metrics (Final Score & Survival Time)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FINAL SCORE',
                                style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                '${autopsy.finalScore}',
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'SURVIVAL TIME',
                                style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                _formatTimer(autopsy.survivalTime),
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14.0),
                      _buildReceiptDashedLine(),
                      const SizedBox(height: 12.0),

                      // Cause of Collapse
                      const Text(
                        'CAUSE OF COLLAPSE',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          '${autopsy.failedHemisphere} Hemisphere // ${autopsy.failedMechanic}\n(+${autopsy.timePostLastMutation.toStringAsFixed(1)}s post-mutation)',
                          style: const TextStyle(
                            color: Color(0xFFFAFAFA),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12.0),

                      // Session & Play Mode Indicators
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 5.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                autopsy.sessionMode == GameSessionMode.duoCoop
                                    ? 'Duo Co-Op'
                                    : 'Solo Run',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF333333),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 5.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEEEEE),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                autopsy.playMode == PlayHandMode.oneHand
                                    ? '1-Hand Survival'
                                    : '2-Hands Strict',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF333333),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Duo Blame Attribution
                      if (autopsy.sessionMode == GameSessionMode.duoCoop) ...[
                        const SizedBox(height: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            border: Border.all(
                              color: const Color(0xFFD32F2F),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 6.0),
                              Expanded(
                                child: Text(
                                  'Fault attribution: ${autopsy.responsibleParty}',
                                  style: const TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10.0),

                      // Hardware Telemetry Stamp
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isGod
                                ? const Color(0xFFD4AF37)
                                : (autopsy.wasOverdrive
                                      ? const Color(0xFFFF1E42)
                                      : Colors.black26),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGod
                                  ? '★ 1% God Mode Verified (10.0x)'
                                  : (autopsy.wasOverdrive
                                        ? '⚡ Overdrive Verified (3.0x)'
                                        : 'Standard Protocol (1.0x)'),
                              style: TextStyle(
                                color: isGod
                                    ? const Color(0xFFB8860B)
                                    : (autopsy.wasOverdrive
                                          ? const Color(0xFFFF1E42)
                                          : const Color(0xFF222222)),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              'Battery at crash: ${autopsy.batteryPct}% [${autopsy.wasOverdrive ? "Unplugged" : "Standard"}]',
                              style: const TextStyle(
                                color: Color(0xFF555555),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12.0),

                      // Thumb Density Sparkline
                      const Text(
                        'THUMB DENSITY (LEFT VS RIGHT)',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 9.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: CustomPaint(
                          painter: SparklinePainter(
                            leftActivity: autopsy.leftActivity,
                            rightActivity: autopsy.rightActivity,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12.0),
                      _buildReceiptDashedLine(),
                      const SizedBox(height: 10.0),

                      // Barcode simulation
                      CustomPaint(
                        size: const Size(double.infinity, 22),
                        painter: BarcodePainter(),
                      ),
                      const SizedBox(height: 6.0),
                      Center(
                        child: Text(
                          'SESSION #${autopsy.finalScore.toString().padLeft(6, "0")}',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20.0),

            // Action Buttons
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Play Again Button (Primary CTA)
                  ElevatedButton.icon(
                    onPressed: () {
                      ProceduralAudioSynth.instance.playSwapTick(
                        isFinal: false,
                      );
                      HapticChoreographer.instance.triggerTap();
                      widget.onRetry();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Play Again',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      elevation: 4.0,
                    ),
                  ),

                  const SizedBox(height: 10.0),

                  // Secondary Action Buttons Row
                  Row(
                    children: [
                      // Share Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareReceipt,
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: Text(
                            _isSharing ? 'Exporting...' : 'Share',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white24,
                              width: 1.0,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.04,),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),

                      // Settings / Preferences Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ProceduralAudioSynth.instance.playTap();
                            HapticChoreographer.instance.triggerTap();
                            if (widget.onOpenSettings != null) {
                              widget.onOpenSettings!();
                            } else if (widget.onReturnToMenu != null) {
                              widget.onReturnToMenu!();
                            }
                          },
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text(
                            'Settings',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white24,
                              width: 1.0,
                            ),
                            backgroundColor: Colors.white.withOpacity(0.04,),
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8.0),

                      // Return to Menu Button
                      if (widget.onReturnToMenu != null)
                        InkWell(
                          onTap: () {
                            ProceduralAudioSynth.instance.playTap();
                            HapticChoreographer.instance.triggerTap();
                            widget.onReturnToMenu!();
                          },
                          borderRadius: BorderRadius.circular(12.0),
                          child: Container(
                            width: 44.0,
                            height: 44.0,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: Colors.white24,
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(
                              Icons.home_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double dashWidth = 5.0;
        const double dashSpace = 3.0;
        final int count = (constraints.maxWidth / (dashWidth + dashSpace))
            .floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1.0,
              color: const Color(0xFFD0D0D0),
            ),
          ),
        );
      },
    );
  }
}

/// Cuts jagged sawtooth edges on top and bottom of receipt paper.
class SawtoothReceiptClipper extends CustomClipper<Path> {
  final double sawtoothSize;
  SawtoothReceiptClipper({this.sawtoothSize = 6.0});

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double step = sawtoothSize * 2.0;

    // Top sawtooth
    path.moveTo(0, sawtoothSize);
    for (double x = 0; x <= size.width + step; x += step) {
      path.lineTo(x + sawtoothSize, 0);
      path.lineTo(x + step, sawtoothSize);
    }

    // Right edge down
    path.lineTo(size.width, size.height - sawtoothSize);

    // Bottom sawtooth (right to left)
    for (double x = size.width; x >= -step; x -= step) {
      path.lineTo(x - sawtoothSize, size.height);
      path.lineTo(x - step, size.height - sawtoothSize);
    }

    // Left edge up
    path.lineTo(0, sawtoothSize);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Draws procedural sparkline graph comparing Left and Right thumb activity density.
class SparklinePainter extends CustomPainter {
  final List<double> leftActivity;
  final List<double> rightActivity;

  SparklinePainter({required this.leftActivity, required this.rightActivity});

  @override
  void paint(Canvas canvas, Size size) {
    if (leftActivity.isEmpty && rightActivity.isEmpty) return;

    final int len = math.max(leftActivity.length, rightActivity.length);
    if (len < 2) return;

    final double stepX = size.width / (len - 1);

    // Find max for scaling
    double maxVal = 1.0;
    for (final v in leftActivity) {
      if (v > maxVal) maxVal = v;
    }
    for (final v in rightActivity) {
      if (v > maxVal) maxVal = v;
    }

    // Left activity line (black)
    final Paint leftPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path leftPath = Path();
    for (int i = 0; i < leftActivity.length; i++) {
      final double x = i * stepX;
      final double y =
          size.height - (leftActivity[i] / maxVal) * (size.height - 8) - 4;
      if (i == 0) {
        leftPath.moveTo(x, y);
      } else {
        leftPath.lineTo(x, y);
      }
    }
    canvas.drawPath(leftPath, leftPaint);

    // Right activity line (crimson)
    final Paint rightPaint = Paint()
      ..color = const Color(0xFFFF1E42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path rightPath = Path();
    for (int i = 0; i < rightActivity.length; i++) {
      final double x = i * stepX;
      final double y =
          size.height - (rightActivity[i] / maxVal) * (size.height - 8) - 4;
      if (i == 0) {
        rightPath.moveTo(x, y);
      } else {
        rightPath.lineTo(x, y);
      }
    }
    canvas.drawPath(rightPath, rightPaint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => true;
}

/// Draws authentic procedural thermal receipt barcode.
class BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint barPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill;

    const List<int> pattern = [
      2,
      1,
      3,
      1,
      1,
      4,
      2,
      1,
      3,
      2,
      1,
      2,
      3,
      1,
      4,
      1,
      2,
      3,
      1,
      1,
      2,
      4,
      2,
      1,
      3,
    ];
    double curX = 10.0;
    for (final width in pattern) {
      canvas.drawRect(
        Rect.fromLTWH(curX, 0, width.toDouble() * 1.5, size.height),
        barPaint,
      );
      curX += (width * 1.5) + 3.0;
      if (curX >= size.width - 10) break;
    }
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) => false;
}
