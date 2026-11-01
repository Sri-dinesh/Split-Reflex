import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/palette.dart';
import '../../engine/game_controller.dart';

class DeathReceiptOverlay extends StatefulWidget {
  final DeathAutopsy autopsy;
  final GameController? controller;
  final VoidCallback onRetry;
  final VoidCallback? onReturnToMenu;
  final VoidCallback onOpenLeaderboard;

  const DeathReceiptOverlay({
    super.key,
    required this.autopsy,
    this.controller,
    required this.onRetry,
    this.onReturnToMenu,
    required this.onOpenLeaderboard,
  });

  @override
  State<DeathReceiptOverlay> createState() => _DeathReceiptOverlayState();
}

class _DeathReceiptOverlayState extends State<DeathReceiptOverlay> {
  final GlobalKey _receiptBoundaryKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final boundary = _receiptBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/split_brain_autopsy_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My reflexes short-circuited in ${widget.autopsy.survivalTime.toStringAsFixed(2)}s at ${widget.autopsy.batteryPct}% battery on Split Reflex. Can you beat ${widget.autopsy.finalScore} pts?',
      );
    } catch (e) {
      debugPrint('Share failed: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _formatTimer(double seconds) {
    final int mins = (seconds / 60).floor();
    final double secs = seconds % 60;
    final String minStr = mins.toString().padLeft(2, '0');
    final String secStr = secs.toStringAsFixed(2).padLeft(5, '0');
    return '$minStr:$secStr';
  }

  String _getPairLabel(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'CLASSIC (THRUST / DART)';
      case GamePairMode.phaseFlux:
        return 'PHASE FLUX (POLARITY / DRIFT)';
      case GamePairMode.pulseReflex:
        return 'PULSE REFLEX (SHIELD / WARP)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final autopsy = widget.autopsy;
    final isGod = autopsy.batteryPct == 1 && autopsy.wasOverdrive;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // RepaintBoundary for capture
            RepaintBoundary(
              key: _receiptBoundaryKey,
              child: ClipPath(
                clipper: SawtoothReceiptClipper(sawtoothSize: 7.0),
                child: Container(
                  width: math.min(360.0, MediaQuery.of(context).size.width - 48.0),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F8F8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Text(
                        'SPLIT REFLEX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF121212),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      const Text(
                        'COGNITIVE AUTOPSY REPORT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      _buildReceiptDashedLine(),
                      const SizedBox(height: 14.0),

                      // Primary Metrics
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                '${autopsy.finalScore}',
                                style: const TextStyle(
                                  color: Color(0xFF121212),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                _formatTimer(autopsy.survivalTime),
                                style: const TextStyle(
                                  color: Color(0xFF121212),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14.0),
                      _buildReceiptDashedLine(),
                      const SizedBox(height: 12.0),

                      // Failure Autopsy Details
                      const Text(
                        'CAUSE OF COLLAPSE:',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                        child: Text(
                          '${autopsy.failedHemisphere} HEMISPHERE // ${autopsy.failedMechanic}\n(+${autopsy.timePostLastMutation.toStringAsFixed(1)}s POST-MUTATION)',
                          style: const TextStyle(
                            color: Color(0xFFF8F8F8),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            height: 1.3,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14.0),

                      // Session & Play Mode Indicators
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                              margin: const EdgeInsets.only(bottom: 8.0, right: 4.0),
                              decoration: BoxDecoration(
                                color: autopsy.sessionMode == GameSessionMode.duoCoop
                                    ? const Color(0xFFFFF8E1)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                              child: Text(
                                autopsy.sessionMode == GameSessionMode.duoCoop
                                    ? 'DUO CO-OP'
                                    : 'SOLO RUN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: autopsy.sessionMode == GameSessionMode.duoCoop
                                      ? const Color(0xFFB78103)
                                      : const Color(0xFF424242),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                              margin: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                              decoration: BoxDecoration(
                                color: autopsy.playMode == PlayHandMode.oneHand
                                    ? const Color(0xFFE0F7FA)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                              child: Text(
                                autopsy.playMode == PlayHandMode.oneHand
                                    ? '1-HAND SURVIVAL'
                                    : '2-HANDS STRICT',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: autopsy.playMode == PlayHandMode.oneHand
                                      ? const Color(0xFF00695C)
                                      : const Color(0xFFC62828),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Duo Co-Op Blame / Attribution Stamp
                      if (autopsy.sessionMode == GameSessionMode.duoCoop) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F).withOpacity(0.12),
                            border: Border.all(color: const Color(0xFFD32F2F), width: 1.0),
                            borderRadius: BorderRadius.circular(2.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD32F2F)),
                              const SizedBox(width: 6.0),
                              Expanded(
                                child: Text(
                                  'COLLAPSE CAUSED BY: ${autopsy.responsibleParty}',
                                  style: const TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Hardware Telemetry Stamp
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isGod ? const Color(0xFFD4AF37) : (autopsy.wasOverdrive ? const Color(0xFFFF1E42) : Colors.black26),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGod
                                  ? '★ 1% GOD MODE VERIFIED (10.0x) ★'
                                  : (autopsy.wasOverdrive ? '⚡ OVERDRIVE VERIFIED (3.0x)' : 'STANDARD PROTOCOL (1.0x)'),
                              style: TextStyle(
                                color: isGod
                                    ? const Color(0xFFB8860B)
                                    : (autopsy.wasOverdrive ? const Color(0xFFFF1E42) : const Color(0xFF121212)),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              'BATTERY AT CRASH: ${autopsy.batteryPct}% [${autopsy.wasOverdrive ? "UNPLUGGED" : "SECURE"}]',
                              style: const TextStyle(
                                color: Color(0xFF444444),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14.0),

                      // Thumb Activity Density Sparkline
                      const Text(
                        'THUMB DENSITY SPARKLINE (L vs R):',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECECEC),
                          borderRadius: BorderRadius.circular(3.0),
                        ),
                        child: CustomPaint(
                          painter: SparklinePainter(
                            leftActivity: autopsy.leftActivity,
                            rightActivity: autopsy.rightActivity,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14.0),
                      _buildReceiptDashedLine(),
                      const SizedBox(height: 10.0),

                      // Barcode simulation
                      CustomPaint(
                        size: const Size(double.infinity, 24),
                        painter: BarcodePainter(),
                      ),
                      const SizedBox(height: 6.0),
                      Center(
                        child: Text(
                          'SESSION: #${autopsy.finalScore.toString().padLeft(6, "0")}',
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quick Config Panel (Allows changing settings directly on Game Over screen)
            if (widget.controller != null) ...[
              const SizedBox(height: 16.0),
              Container(
                width: math.min(360.0, MediaQuery.of(context).size.width - 48.0),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF141419).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.white24, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10.0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NEXT RUN CONFIG',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (widget.onReturnToMenu != null)
                          GestureDetector(
                            onTap: widget.onReturnToMenu,
                            child: const Text(
                              'ALL SETTINGS >',
                              style: TextStyle(
                                color: SplitPalette.nearMissCyan,
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    // Game Pair Mode Cycler Chip
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          widget.controller!.cycleGamePairMode();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        margin: const EdgeInsets.only(bottom: 6.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: widget.controller!.gamePairMode == GamePairMode.classic
                                ? SplitPalette.nearMissCyan
                                : (widget.controller!.gamePairMode == GamePairMode.phaseFlux
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFFFFD700)),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 13,
                              color: widget.controller!.gamePairMode == GamePairMode.classic
                                  ? SplitPalette.nearMissCyan
                                  : (widget.controller!.gamePairMode == GamePairMode.phaseFlux
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFFFFD700)),
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              'MODE: ${_getPairLabel(widget.controller!.gamePairMode)}',
                              style: TextStyle(
                                color: widget.controller!.gamePairMode == GamePairMode.classic
                                    ? SplitPalette.nearMissCyan
                                    : (widget.controller!.gamePairMode == GamePairMode.phaseFlux
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFFFFD700)),
                                fontSize: 9.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickConfigChip(
                            label: widget.controller!.sessionMode == GameSessionMode.duoCoop ? 'DUO (2P)' : 'SOLO (1P)',
                            isActive: widget.controller!.sessionMode == GameSessionMode.duoCoop,
                            activeColor: Colors.amberAccent,
                            onTap: () {
                              setState(() {
                                widget.controller!.toggleSessionMode();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: _QuickConfigChip(
                            label: widget.controller!.playMode == PlayHandMode.twoHands ? '2-HANDS' : '1-HAND',
                            isActive: widget.controller!.playMode == PlayHandMode.twoHands,
                            activeColor: SplitPalette.hazardCrimson,
                            onTap: () {
                              setState(() {
                                widget.controller!.togglePlayMode();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: _QuickConfigChip(
                            label: widget.controller!.controlMode == ControlMode.gyroTilt ? 'GYRO' : 'TOUCH',
                            isActive: widget.controller!.controlMode == ControlMode.gyroTilt,
                            activeColor: Colors.purpleAccent,
                            onTap: () {
                              setState(() {
                                widget.controller!.toggleControlMode();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: _QuickConfigChip(
                            label: widget.controller!.theme.name.toUpperCase(),
                            isActive: true,
                            activeColor: SplitPalette.nearMissCyan,
                            onTap: () {
                              setState(() {
                                widget.controller!.cycleTheme();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16.0),

            // Action Buttons
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text(
                    'RETRY RUN',
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
                if (widget.onReturnToMenu != null)
                  ElevatedButton.icon(
                    onPressed: widget.onReturnToMenu,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text(
                      'SETTINGS',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22222A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _shareReceipt,
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(
                    _isSharing ? 'EXPORTING...' : 'SHARE',
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SplitPalette.hazardCrimson,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
              ],
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
        final int count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dashWidth, height: 1.0, color: const Color(0xFFCCCCCC)),
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
      ..color = const Color(0xFF121212)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path leftPath = Path();
    for (int i = 0; i < leftActivity.length; i++) {
      final double x = i * stepX;
      final double y = size.height - (leftActivity[i] / maxVal) * (size.height - 8) - 4;
      if (i == 0) {
        leftPath.moveTo(x, y);
      } else {
        leftPath.lineTo(x, y);
      }
    }
    canvas.drawPath(leftPath, leftPaint);

    // Right activity line (red)
    final Paint rightPaint = Paint()
      ..color = const Color(0xFFFF1E42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path rightPath = Path();
    for (int i = 0; i < rightActivity.length; i++) {
      final double x = i * stepX;
      final double y = size.height - (rightActivity[i] / maxVal) * (size.height - 8) - 4;
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
      ..color = const Color(0xFF121212)
      ..style = PaintingStyle.fill;

    const List<int> pattern = [2, 1, 3, 1, 1, 4, 2, 1, 3, 2, 1, 2, 3, 1, 4, 1, 2, 3, 1, 1, 2, 4, 2, 1, 3];
    double curX = 10.0;
    for (final width in pattern) {
      canvas.drawRect(Rect.fromLTWH(curX, 0, width.toDouble() * 1.5, size.height), barPaint);
      curX += (width * 1.5) + 3.0;
      if (curX >= size.width - 10) break;
    }
  }

  @override
  bool shouldRepaint(covariant BarcodePainter oldDelegate) => false;
}

class _QuickConfigChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _QuickConfigChip({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.18) : Colors.black45,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isActive ? activeColor : Colors.white12,
            width: 1.0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 9.0,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
