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
    final String r = c.playMode == PlayHandMode.oneHand ? '1-HAND SURVIVAL' : '2-HANDS STRICT';
    final String s = c.controlMode == ControlMode.gyroTilt ? 'GYRO TILT' : 'TOUCH SWIPE';
    return '$pair \u2022 $p \u2022 $r \u2022 $s';
  }

  String _getLeftTitle(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'GRAVITY ORB';
      case GamePairMode.phaseFlux:
        return 'PHASE CORE';
      case GamePairMode.pulseReflex:
        return 'SHIELD PING';
    }
  }

  String _getLeftDesc(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'TAP/HOLD LEFT \u2192 DEFY GRAVITY';
      case GamePairMode.phaseFlux:
        return 'TAP LEFT \u2192 FLIP POLARITY';
      case GamePairMode.pulseReflex:
        return 'TAP ON IMPACT \u2192 DEFLECT BOLTS';
    }
  }

  String _getRightTitle(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'RAIL DART';
      case GamePairMode.phaseFlux:
        return 'SLALOM DRIFT';
      case GamePairMode.pulseReflex:
        return 'QUANTUM WARP';
    }
  }

  String _getRightDesc(GamePairMode mode, bool isGyro) {
    switch (mode) {
      case GamePairMode.classic:
        return isGyro ? 'TILT PHONE \u2192 STEER DART' : 'SLIDE RIGHT \u2192 WEAVE MONOLITHS';
      case GamePairMode.phaseFlux:
        return isGyro ? 'TILT PHONE \u2192 DRIFT CHASM' : 'SLIDE RIGHT \u2192 WEAVE PYLONS';
      case GamePairMode.pulseReflex:
        return 'TAP RIGHT \u2192 HOP TRACKS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 700;

    return Stack(
      children: [
        // 0. Frosted Glass Backdrop Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
            child: Container(
              color: const Color(0xFF07070A).withOpacity(0.72),
            ),
          ),
        ),

        // Scrollable, perfectly spaced Cyber Command Console
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 18.0,
                  vertical: isCompact ? 10.0 : 16.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. BRAND HEADER
                    _buildBrandHeader(),
                    SizedBox(height: isCompact ? 10.0 : 14.0),

                    // 2. GAME MODE PAIR SELECTOR
                    _GamePairSelector(
                      currentPair: controller.gamePairMode,
                      onSelect: (pair) => controller.setGamePairMode(pair),
                    ),
                    const SizedBox(height: 8.0),

                    // 3. HEMISPHERE DIRECTIVES PREVIEW
                    _buildHemisphereDirectives(isCompact),
                    const SizedBox(height: 10.0),

                    // 4. CONFIGURATION CONSOLE (Players, Rules, Steering, Theme)
                    _buildConfigConsole(),
                    const SizedBox(height: 14.0),

                    // 5. PRIMARY START CTA BUTTON
                    _buildStartCtaButton(),
                    SizedBox(height: isCompact ? 12.0 : 16.0),

                    // 6. DUAL THUMB BIOMETRIC PADS
                    _buildBiometricSection(),
                    const SizedBox(height: 10.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 18.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SplitPalette.nearMissCyan,
                    boxShadow: [
                      BoxShadow(color: SplitPalette.nearMissCyan, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'SPLIT REFLEX',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SplitPalette.hazardCrimson,
                    boxShadow: [
                      BoxShadow(color: SplitPalette.hazardCrimson, blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4.0),
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
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHemisphereDirectives(bool isCompact) {
    return Row(
      children: [
        // Left Directive
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F14).withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SplitPalette.nearMissCyan.withOpacity(0.4), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_left_rounded, size: 14, color: SplitPalette.nearMissCyan),
                    Text(
                      _getLeftTitle(controller.gamePairMode),
                      style: const TextStyle(
                        color: SplitPalette.nearMissCyan,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2.0),
                Text(
                  _getLeftDesc(controller.gamePairMode),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8.0,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        // Right Directive
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F14).withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SplitPalette.hazardCrimson.withOpacity(0.4), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _getRightTitle(controller.gamePairMode),
                      style: const TextStyle(
                        color: SplitPalette.hazardCrimson,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Icon(Icons.arrow_right_rounded, size: 14, color: SplitPalette.hazardCrimson),
                  ],
                ),
                const SizedBox(height: 2.0),
                Text(
                  _getRightDesc(controller.gamePairMode, controller.controlMode == ControlMode.gyroTilt),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8.0,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigConsole() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12).withOpacity(0.95),
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
          // Row 1: PLAYERS & RULES
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
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCtaButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        splashColor: SplitPalette.nearMissCyan.withOpacity(0.4),
        onTap: () {
          ProceduralAudioSynth.instance.playSwapTick(isFinal: false);
          HapticChoreographer.instance.triggerTap();
          controller.triggerStartCountdown();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0F1A24).withOpacity(0.96),
                const Color(0xFF0F262C).withOpacity(0.96),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: SplitPalette.nearMissCyan,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: SplitPalette.nearMissCyan.withOpacity(0.4),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: SplitPalette.nearMissCyan,
                  size: 26,
                ),
                SizedBox(width: 8),
                Text(
                  'INITIALIZE RUN [START]',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
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

  Widget _buildBiometricSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF09090D).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left Pad
              GestureDetector(
                onTapDown: (_) => controller.inputRouter.leftThumbHeld = true,
                onTapUp: (_) => controller.inputRouter.leftThumbHeld = false,
                onTapCancel: () => controller.inputRouter.leftThumbHeld = false,
                child: _ThumbTargetRing(
                  isHeld: controller.inputRouter.leftThumbHeld,
                  progress: controller.holdProgress,
                  primaryColor: SplitPalette.lightBg,
                  accentColor: SplitPalette.nearMissCyan,
                  label: controller.sessionMode == GameSessionMode.duoCoop ? 'PLAYER 1' : 'LEFT THUMB',
                ),
              ),

              // Divider / VS
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.holdProgress > 0.0
                        ? '${(controller.holdProgress * 100).toInt()}%'
                        : 'SYNC',
                    style: TextStyle(
                      color: controller.holdProgress > 0.0 ? SplitPalette.nearMissCyan : Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white24,
                  ),
                ],
              ),

              // Right Pad
              GestureDetector(
                onTapDown: (_) => controller.inputRouter.rightThumbHeld = true,
                onTapUp: (_) => controller.inputRouter.rightThumbHeld = false,
                onTapCancel: () => controller.inputRouter.rightThumbHeld = false,
                child: _ThumbTargetRing(
                  isHeld: controller.inputRouter.rightThumbHeld,
                  progress: controller.holdProgress,
                  primaryColor: SplitPalette.darkBg,
                  accentColor: SplitPalette.hazardCrimson,
                  label: controller.sessionMode == GameSessionMode.duoCoop ? 'PLAYER 2' : 'RIGHT THUMB',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            controller.holdProgress > 0.0
                ? 'CALIBRATING SYNAPSES... ${(controller.holdProgress * 100).toInt()}%'
                : 'HOLD BOTH SENSOR PADS FOR BIOMETRIC START',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: controller.holdProgress > 0.0 ? SplitPalette.nearMissCyan : Colors.white38,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
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
            fontSize: 8.0,
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
            fontSize: 8.0,
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
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHeld ? accentColor.withOpacity(0.22) : Colors.transparent,
          ),
          child: CustomPaint(
            size: const Size(68, 68),
            painter: _TargetRingPainter(
              isHeld: isHeld,
              progress: progress,
              primaryColor: primaryColor,
              accentColor: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          label,
          style: TextStyle(
            color: primaryColor.withOpacity(0.8),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
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
    final double radius = size.width / 2 - 3.0;

    // Outer subtle guide circle
    final Paint guidePaint = Paint()
      ..color = isHeld ? accentColor : primaryColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHeld ? 2.2 : 1.2;
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
    canvas.drawCircle(center, isHeld ? 7.0 : 3.5, dotPaint);

    // Radial charging progress arc
    if (progress > 0.0) {
      final Paint progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
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
            fontSize: 8.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4.0),
        Container(
          height: 40,
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
                sublabel: 'THRUST \u2022 WEAVE',
                accentColor: SplitPalette.nearMissCyan,
              ),
              const SizedBox(width: 2.0),
              _buildPairButton(
                mode: GamePairMode.phaseFlux,
                label: 'PHASE FLUX',
                sublabel: 'POLARITY \u2022 DRIFT',
                accentColor: const Color(0xFF00E5FF),
              ),
              const SizedBox(width: 2.0),
              _buildPairButton(
                mode: GamePairMode.pulseReflex,
                label: 'PULSE REFLEX',
                sublabel: 'SHIELD \u2022 WARP',
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
