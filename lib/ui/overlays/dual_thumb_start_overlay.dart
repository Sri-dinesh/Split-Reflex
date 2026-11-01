import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../../engine/game_controller.dart';

class DualThumbStartOverlay extends StatelessWidget {
  final GameController controller;

  const DualThumbStartOverlay({super.key, required this.controller});

  String _getModeSummary(GameController c) {
    final String pair = c.gamePairMode == GamePairMode.classic
        ? 'CLASSIC'
        : (c.gamePairMode == GamePairMode.phaseFlux ? 'PHASE FLUX' : 'PULSE REFLEX');
    final String p = c.sessionMode == GameSessionMode.duoCoop ? 'DUO (2P)' : 'SOLO (1P)';
    final String r = c.playMode == PlayHandMode.oneHand ? '1-HAND' : '2-HANDS';
    final String s = c.controlMode == ControlMode.gyroTilt ? 'GYRO' : 'TOUCH';
    return '$pair • $p • $r • $s';
  }

  String _getLeftTitle(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'ORB // THRUST';
      case GamePairMode.phaseFlux:
        return 'PHASE // FLIP';
      case GamePairMode.pulseReflex:
        return 'SHIELD // PING';
    }
  }

  String _getLeftDesc(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'HOLD LEFT\nDEFY GRAVITY';
      case GamePairMode.phaseFlux:
        return 'TAP LEFT\nFLIP POLARITY';
      case GamePairMode.pulseReflex:
        return 'TAP ON IMPACT\nDEFLECT BOLTS';
    }
  }

  String _getRightTitle(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'DART // STEER';
      case GamePairMode.phaseFlux:
        return 'SLALOM // DRIFT';
      case GamePairMode.pulseReflex:
        return 'QUANTUM // WARP';
    }
  }

  String _getRightDesc(GamePairMode mode, bool isGyro) {
    switch (mode) {
      case GamePairMode.classic:
        return isGyro ? 'TILT PHONE\nSTEER DART' : 'TOUCH RIGHT\nSLIDE ON RAIL';
      case GamePairMode.phaseFlux:
        return isGyro ? 'TILT PHONE\nDRIFT CHASM' : 'TOUCH RIGHT\nWEAVE CHASM';
      case GamePairMode.pulseReflex:
        return 'TAP RIGHT\nHOP TRACKS';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        final double leftTargetX = w * 0.25;
        final double rightTargetX = w * 0.75;
        final double targetY = h * 0.77;

        return Stack(
          children: [
            // 0. Frosted Glass Backdrop Blur (blurs the game screen so options and menu are the sole crisp focus)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  color: const Color(0xFF07070A).withOpacity(0.68),
                ),
              ),
            ),

            // 1. High-Contrast Title Banner (100% visible across both hemispheres)
            Positioned(
              top: h * 0.08,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: Colors.white24, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 18.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SPLIT REFLEX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: const Text(
                          'DUAL-HEMISPHERE COGNITIVE OVERLOAD',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Mechanic Directives
            Positioned(
              top: h * 0.20,
              left: 16,
              width: w * 0.5 - 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F12).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _getLeftTitle(controller.gamePairMode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      _getLeftDesc(controller.gamePairMode),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: h * 0.20,
              right: 16,
              width: w * 0.5 - 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F12).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _getRightTitle(controller.gamePairMode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      _getRightDesc(controller.gamePairMode, controller.controlMode == ControlMode.gyroTilt),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Minimal, Clean & Clear Options Menu
            Positioned(
              top: h * 0.31,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E12).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: Colors.white12, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 0: GAME PAIR SELECTION (Classic / Phase Flux / Pulse Reflex)
                        _GamePairSelector(
                          currentPair: controller.gamePairMode,
                          onSelect: (pair) => controller.setGamePairMode(pair),
                        ),
                        const SizedBox(height: 8.0),

                        // Row 1: PLAYERS & RULESET
                        Row(
                          children: [
                            Expanded(
                              child: _SegmentedToggle(
                                label: 'PLAYERS',
                                optionA: 'SOLO (1P)',
                                optionB: 'DUO (2P)',
                                isBSelected: controller.sessionMode == GameSessionMode.duoCoop,
                                accentColor: Colors.amberAccent,
                                onToggle: () => controller.toggleSessionMode(),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: _SegmentedToggle(
                                label: 'RULES',
                                optionA: '1-HAND',
                                optionB: '2-HANDS',
                                isBSelected: controller.playMode == PlayHandMode.twoHands,
                                accentColor: SplitPalette.hazardCrimson,
                                onToggle: () => controller.togglePlayMode(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),

                        // Row 2: STEERING & THEME
                        Row(
                          children: [
                            Expanded(
                              child: _SegmentedToggle(
                                label: 'STEERING',
                                optionA: 'TOUCH',
                                optionB: 'GYRO',
                                isBSelected: controller.controlMode == ControlMode.gyroTilt,
                                accentColor: Colors.purpleAccent,
                                iconA: Icons.touch_app_rounded,
                                iconB: Icons.screen_rotation_rounded,
                                onToggle: () => controller.toggleControlMode(),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: _ThemeToggle(
                                currentTheme: controller.theme,
                                onCycle: () => controller.cycleTheme(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        // Dynamic Mode Summary Tag
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6.0),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            _getModeSummary(controller),
                            style: const TextStyle(
                              color: SplitPalette.nearMissCyan,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Prominent START GAME Button
            Positioned(
              top: h * 0.52,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    splashColor: SplitPalette.nearMissCyan.withOpacity(0.5),
                    onTap: () {
                      controller.triggerStartCountdown();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F12).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: SplitPalette.nearMissCyan,
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SplitPalette.nearMissCyan.withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: SplitPalette.nearMissCyan,
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'START GAME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Left Thumb Interactive Pad
            Positioned(
              left: leftTargetX - 44,
              top: targetY - 44,
              child: GestureDetector(
                onTapDown: (_) {
                  controller.inputRouter.leftThumbHeld = true;
                },
                onTapUp: (_) {
                  controller.inputRouter.leftThumbHeld = false;
                },
                onTapCancel: () {
                  controller.inputRouter.leftThumbHeld = false;
                },
                child: _ThumbTargetRing(
                  isHeld: controller.inputRouter.leftThumbHeld,
                  progress: controller.holdProgress,
                  primaryColor: SplitPalette.lightBg,
                  accentColor: SplitPalette.nearMissCyan,
                  label: controller.sessionMode == GameSessionMode.duoCoop ? 'PLAYER 1 (LEFT)' : 'LEFT THUMB',
                ),
              ),
            ),

            // 6. Right Thumb Interactive Pad
            Positioned(
              left: rightTargetX - 44,
              top: targetY - 44,
              child: GestureDetector(
                onTapDown: (_) {
                  controller.inputRouter.rightThumbHeld = true;
                },
                onTapUp: (_) {
                  controller.inputRouter.rightThumbHeld = false;
                },
                onTapCancel: () {
                  controller.inputRouter.rightThumbHeld = false;
                },
                child: _ThumbTargetRing(
                  isHeld: controller.inputRouter.rightThumbHeld,
                  progress: controller.holdProgress,
                  primaryColor: SplitPalette.darkBg,
                  accentColor: SplitPalette.hazardCrimson,
                  label: controller.sessionMode == GameSessionMode.duoCoop ? 'PLAYER 2 (RIGHT)' : 'RIGHT THUMB',
                ),
              ),
            ),

            // 7. Secondary Instruction Prompt
            Positioned(
              bottom: h * 0.05,
              left: 0,
              right: 0,
              child: Text(
                controller.holdProgress > 0.0
                    ? 'CALIBRATING SYNAPSES... ${(controller.holdProgress * 100).toInt()}%'
                    : 'TAP START GAME OR HOLD BOTH PADS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: controller.holdProgress > 0.0 ? SplitPalette.nearMissCyan : Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final String label;
  final String optionA;
  final String optionB;
  final bool isBSelected;
  final Color accentColor;
  final IconData? iconA;
  final IconData? iconB;
  final VoidCallback onToggle;

  const _SegmentedToggle({
    required this.label,
    required this.optionA,
    required this.optionB,
    required this.isBSelected,
    required this.accentColor,
    this.iconA,
    this.iconB,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4.0),
        GestureDetector(
          onTap: () {
            ProceduralAudioSynth.instance.playTap();
            HapticChoreographer.instance.triggerTap();
            onToggle();
          },
          child: Container(
            height: 32,
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !isBSelected ? SplitPalette.nearMissCyan.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: !isBSelected ? SplitPalette.nearMissCyan : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconA != null) ...[
                            Icon(iconA, size: 11, color: !isBSelected ? SplitPalette.nearMissCyan : Colors.white38),
                            const SizedBox(width: 3.0),
                          ],
                          Text(
                            optionA,
                            style: TextStyle(
                              color: !isBSelected ? Colors.white : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2.0),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isBSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: isBSelected ? accentColor : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconB != null) ...[
                            Icon(iconB, size: 11, color: isBSelected ? accentColor : Colors.white38),
                            const SizedBox(width: 3.0),
                          ],
                          Text(
                            optionB,
                            style: TextStyle(
                              color: isBSelected ? Colors.white : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final CyberTheme currentTheme;
  final VoidCallback onCycle;

  const _ThemeToggle({
    required this.currentTheme,
    required this.onCycle,
  });

  Color _getThemeColor(CyberTheme theme) {
    switch (theme) {
      case CyberTheme.synthwave:
        return SplitPalette.synthwavePink;
      case CyberTheme.matrix:
        return SplitPalette.matrixGreen;
      case CyberTheme.cyberGold:
        return SplitPalette.goldBright;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = _getThemeColor(currentTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'THEME',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4.0),
        GestureDetector(
          onTap: () {
            ProceduralAudioSynth.instance.playTap();
            HapticChoreographer.instance.triggerTap();
            onCycle();
          },
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: themeColor.withOpacity(0.5), width: 1.0),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    currentTheme.name.toUpperCase(),
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThumbTargetRing extends StatelessWidget {
  final bool isHeld;
  final double progress;
  final Color primaryColor;
  final Color accentColor;
  final String label;

  const _ThumbTargetRing({
    required this.isHeld,
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHeld ? accentColor.withOpacity(0.2) : Colors.transparent,
          ),
          child: CustomPaint(
            size: const Size(88, 88),
            painter: _TargetRingPainter(
              isHeld: isHeld,
              progress: progress,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          label,
          style: TextStyle(
            color: primaryColor.withOpacity(0.8),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _TargetRingPainter extends CustomPainter {
  final bool isHeld;
  final double progress;
  final Color primaryColor;
  final Color accentColor;

  _TargetRingPainter({
    required this.isHeld,
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 4.0;

    // Outer subtle guide circle
    final Paint guidePaint = Paint()
      ..color = isHeld ? accentColor : primaryColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHeld ? 2.5 : 1.5;
    canvas.drawCircle(center, radius, guidePaint);

    // Inner concentric ring
    final Paint innerPaint = Paint()
      ..color = isHeld ? accentColor.withOpacity(0.6) : primaryColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.65, innerPaint);

    // Center thumb dot
    final Paint dotPaint = Paint()
      ..color = isHeld ? accentColor : primaryColor.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isHeld ? 8.0 : 4.0, dotPaint);

    // Radial charging progress arc
    if (progress > 0.0) {
      final Paint progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      final Rect rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TargetRingPainter oldDelegate) =>
      oldDelegate.isHeld != isHeld || oldDelegate.progress != progress;
}

class _GamePairSelector extends StatelessWidget {
  final GamePairMode currentPair;
  final ValueChanged<GamePairMode> onSelect;

  const _GamePairSelector({
    required this.currentPair,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'GAME MODE PAIR',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          height: 38,
          padding: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              _buildPairButton(
                mode: GamePairMode.classic,
                label: 'CLASSIC',
                sublabel: 'THRUST/DART',
                accentColor: SplitPalette.nearMissCyan,
              ),
              const SizedBox(width: 2.0),
              _buildPairButton(
                mode: GamePairMode.phaseFlux,
                label: 'PHASE FLUX',
                sublabel: 'POLARITY/DRIFT',
                accentColor: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 2.0),
              _buildPairButton(
                mode: GamePairMode.pulseReflex,
                label: 'PULSE REFLEX',
                sublabel: 'SHIELD/WARP',
                accentColor: const Color(0xFFFFD700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPairButton({
    required GamePairMode mode,
    required String label,
    required String sublabel,
    required Color accentColor,
  }) {
    final bool isSelected = currentPair == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ProceduralAudioSynth.instance.playTap();
          HapticChoreographer.instance.triggerTap();
          onSelect(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: isSelected ? accentColor : Colors.white24,
                    fontSize: 6.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

