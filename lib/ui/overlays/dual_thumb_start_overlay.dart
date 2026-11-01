import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/constants/app_icon_data.dart';
import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../../engine/game_controller.dart';

class DualThumbStartOverlay extends StatelessWidget {
  final GameController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLeaderboard;

  const DualThumbStartOverlay({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    required this.onOpenLeaderboard,
  });

  String _getLeftCraftName(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'Gravity Orb';
      case GamePairMode.phaseFlux:
        return 'Phase Core';
      case GamePairMode.pulseReflex:
        return 'Shield Ping';
    }
  }

  String _getLeftInstruction(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'Hold to thrust upward';
      case GamePairMode.phaseFlux:
        return 'Tap to invert polarity';
      case GamePairMode.pulseReflex:
        return 'Tap on impact to deflect';
    }
  }

  String _getRightCraftName(GamePairMode mode) {
    switch (mode) {
      case GamePairMode.classic:
        return 'Rail Dart';
      case GamePairMode.phaseFlux:
        return 'Slalom Drift';
      case GamePairMode.pulseReflex:
        return 'Quantum Warp';
    }
  }

  String _getRightInstruction(GamePairMode mode, bool isGyro) {
    switch (mode) {
      case GamePairMode.classic:
        return isGyro ? 'Tilt phone to steer' : 'Drag horizontally to weave';
      case GamePairMode.phaseFlux:
        return isGyro ? 'Tilt phone to drift' : 'Drag horizontally to drift';
      case GamePairMode.pulseReflex:
        return 'Tap right to hop rails';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 720;
    final battery = controller.batteryState;
    final isGod = battery.isGodMode;
    final isOverdrive = battery.isOverdrive;

    return Stack(
      children: [
        // Frosted Glass Backdrop
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              color: const Color(0xFF07070A).withOpacity(0.78),
            ),
          ),
        ),

        // Main Layout
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: isCompact ? 10.0 : 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Navigation Bar (Header)
                    _buildTopBar(context, isGod, isOverdrive),
                    const Spacer(flex: 1),

                    // 2. Hero Identity (Logo & Title)
                    _buildHeroIdentity(isCompact),
                    const Spacer(flex: 1),

                    // 3. Game Mode Selector
                    _buildModeSelector(),
                    SizedBox(height: isCompact ? 10.0 : 14.0),

                    // 4. Mechanics Briefing Card
                    _buildMechanicsCard(),
                    SizedBox(height: isCompact ? 10.0 : 14.0),

                    // 5. Quick Format Pills (Solo/Duo & 1H/2H)
                    _buildFormatPills(),
                    const Spacer(flex: 2),

                    // 6. Signature Biometric Sensor Pads & Quick Launch
                    _buildBiometricLaunchSection(isCompact),
                    SizedBox(height: isCompact ? 6.0 : 12.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, bool isGod, bool isOverdrive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Battery & Multiplier Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: isGod
                ? SplitPalette.godModeGold.withOpacity(0.12)
                : (isOverdrive ? SplitPalette.hazardCrimson.withOpacity(0.12) : Colors.white.withOpacity(0.06)),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: isGod
                  ? SplitPalette.godModeGold.withOpacity(0.5)
                  : (isOverdrive ? SplitPalette.hazardCrimson.withOpacity(0.5) : Colors.white12),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isGod ? Icons.flash_on_rounded : (isOverdrive ? Icons.bolt_rounded : Icons.battery_charging_full_rounded),
                size: 14.0,
                color: isGod
                    ? SplitPalette.godModeGold
                    : (isOverdrive ? SplitPalette.hazardCrimson : SplitPalette.nearMissCyan),
              ),
              const SizedBox(width: 6.0),
              Text(
                isGod
                    ? '10x GOD MODE'
                    : (isOverdrive
                        ? '${controller.batteryState.scoreMultiplier.toStringAsFixed(1)}x OVERDRIVE'
                        : '${controller.batteryState.batteryLevel}% BATTERY'),
                style: TextStyle(
                  color: isGod
                      ? SplitPalette.godModeGold
                      : (isOverdrive ? SplitPalette.hazardCrimson : Colors.white70),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        // Action Buttons: Leaderboard & Settings
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircularIconButton(
              icon: Icons.emoji_events_outlined,
              tooltip: 'Hall of Records',
              onTap: () {
                ProceduralAudioSynth.instance.playTap();
                HapticChoreographer.instance.triggerTap();
                onOpenLeaderboard();
              },
            ),
            const SizedBox(width: 8.0),
            _buildCircularIconButton(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () {
                ProceduralAudioSynth.instance.playTap();
                HapticChoreographer.instance.triggerTap();
                onOpenSettings();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: Container(
          width: 38.0,
          height: 38.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white12, width: 1.0),
          ),
          child: Icon(icon, color: Colors.white, size: 18.0),
        ),
      ),
    );
  }

  Widget _buildHeroIdentity(bool isCompact) {
    final double iconSize = isCompact ? 68.0 : 82.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Official Split Reflex App Icon with High-Contrast Cyber Framing
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(iconSize * 0.22),
            boxShadow: [
              BoxShadow(
                color: SplitPalette.nearMissCyan.withOpacity(0.35),
                blurRadius: 18.0,
                spreadRadius: 1.0,
                offset: const Offset(-4, 2),
              ),
              BoxShadow(
                color: SplitPalette.hazardCrimson.withOpacity(0.35),
                blurRadius: 18.0,
                spreadRadius: 1.0,
                offset: const Offset(4, 2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 12.0,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(iconSize * 0.21),
            child: Image.memory(
              kAppIconBytes,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 10.0 : 14.0),

        // Title
        const Text(
          'SPLIT REFLEX',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.5,
          ),
        ),
        const SizedBox(height: 4.0),

        // Tagline
        const Text(
          'Dual-Hemisphere Reflex Engine',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 44.0,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white12, width: 1.0),
      ),
      child: Row(
        children: [
          _buildModeTab(
            mode: GamePairMode.classic,
            label: 'Classic',
            accentColor: SplitPalette.nearMissCyan,
          ),
          _buildModeTab(
            mode: GamePairMode.phaseFlux,
            label: 'Phase Flux',
            accentColor: const Color(0xFF00E5FF),
          ),
          _buildModeTab(
            mode: GamePairMode.pulseReflex,
            label: 'Pulse Reflex',
            accentColor: const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required GamePairMode mode,
    required String label,
    required Color accentColor,
  }) {
    final isSelected = controller.gamePairMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.setGamePairMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9.0),
            border: Border.all(
              color: isSelected ? accentColor.withOpacity(0.8) : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white38,
              fontSize: 12.0,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMechanicsCard() {
    final mode = controller.gamePairMode;
    final isGyro = controller.controlMode == ControlMode.gyroTilt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
      ),
      child: Row(
        children: [
          // Left Craft
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7.0,
                      height: 7.0,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SplitPalette.nearMissCyan,
                      ),
                    ),
                    const SizedBox(width: 7.0),
                    Expanded(
                      child: Text(
                        _getLeftCraftName(mode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SplitPalette.nearMissCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3.0),
                Text(
                  _getLeftInstruction(mode),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Clean Center Divider
          Container(
            width: 1.0,
            height: 34.0,
            color: Colors.white12,
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
          ),

          // Right Craft
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7.0,
                      height: 7.0,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SplitPalette.hazardCrimson,
                      ),
                    ),
                    const SizedBox(width: 7.0),
                    Expanded(
                      child: Text(
                        _getRightCraftName(mode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SplitPalette.hazardCrimson,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3.0),
                Text(
                  _getRightInstruction(mode, isGyro),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatPills() {
    return Row(
      children: [
        // Solo vs Duo
        Expanded(
          child: _buildSmallToggle(
            label: controller.sessionMode == GameSessionMode.solo ? 'Solo (1P)' : 'Duo (2P)',
            icon: controller.sessionMode == GameSessionMode.solo ? Icons.person_rounded : Icons.people_rounded,
            isActive: controller.sessionMode == GameSessionMode.duoCoop,
            activeColor: Colors.amberAccent,
            onTap: controller.toggleSessionMode,
          ),
        ),
        const SizedBox(width: 8.0),
        // 2-Hands vs 1-Hand
        Expanded(
          child: _buildSmallToggle(
            label: controller.playMode == PlayHandMode.twoHands ? '2-Hands Strict' : '1-Hand Survival',
            icon: controller.playMode == PlayHandMode.twoHands ? Icons.bolt_rounded : Icons.shield_outlined,
            isActive: controller.playMode == PlayHandMode.oneHand,
            activeColor: SplitPalette.nearMissCyan,
            onTap: controller.togglePlayMode,
          ),
        ),
        const SizedBox(width: 8.0),
        // Steering
        Expanded(
          child: _buildSmallToggle(
            label: controller.controlMode == ControlMode.touchSwipe ? 'Touch' : 'Gyro',
            icon: controller.controlMode == ControlMode.touchSwipe ? Icons.touch_app_rounded : Icons.screen_rotation_rounded,
            isActive: controller.controlMode == ControlMode.gyroTilt,
            activeColor: Colors.purpleAccent,
            onTap: controller.toggleControlMode,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallToggle({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: 36.0,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.5) : Colors.white12,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14.0,
              color: isActive ? activeColor : Colors.white54,
            ),
            const SizedBox(width: 5.0),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricLaunchSection(bool isCompact) {
    final isDuo = controller.sessionMode == GameSessionMode.duoCoop;
    final progress = controller.holdProgress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Start Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: () {
              ProceduralAudioSynth.instance.playSwapTick(isFinal: false);
              HapticChoreographer.instance.triggerTap();
              controller.triggerStartCountdown();
            },
            child: Container(
              height: 52.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 18.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22.0),
                  SizedBox(width: 8.0),
                  Text(
                    'Start Run',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: isCompact ? 10.0 : 14.0),

        // Dual Biometric Touch Pads (Signature Mechanic)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isCompact ? 8.0 : 12.0),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F14).withOpacity(0.9),
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left Pad
              GestureDetector(
                onTapDown: (_) => controller.inputRouter.leftThumbHeld = true,
                onTapUp: (_) => controller.inputRouter.leftThumbHeld = false,
                onTapCancel: () => controller.inputRouter.leftThumbHeld = false,
                child: _SensorPad(
                  label: isDuo ? 'Player 1' : 'Left Thumb',
                  isHeld: controller.inputRouter.leftThumbHeld,
                  progress: progress,
                  accentColor: SplitPalette.nearMissCyan,
                ),
              ),

              // Center Sync Indicator
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 1.0, height: 18.0, color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      progress > 0.0 ? '${(progress * 100).toInt()}%' : 'HOLD',
                      style: TextStyle(
                        color: progress > 0.0 ? SplitPalette.nearMissCyan : Colors.white38,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(width: 1.0, height: 18.0, color: Colors.white12),
                ],
              ),

              // Right Pad
              GestureDetector(
                onTapDown: (_) => controller.inputRouter.rightThumbHeld = true,
                onTapUp: (_) => controller.inputRouter.rightThumbHeld = false,
                onTapCancel: () => controller.inputRouter.rightThumbHeld = false,
                child: _SensorPad(
                  label: isDuo ? 'Player 2' : 'Right Thumb',
                  isHeld: controller.inputRouter.rightThumbHeld,
                  progress: progress,
                  accentColor: SplitPalette.hazardCrimson,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SensorPad extends StatelessWidget {
  final String label;
  final bool isHeld;
  final double progress;
  final Color accentColor;

  const _SensorPad({
    required this.label,
    required this.isHeld,
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 58.0,
          height: 58.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHeld ? accentColor.withOpacity(0.18) : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: isHeld ? accentColor : Colors.white24,
              width: isHeld ? 2.0 : 1.2,
            ),
            boxShadow: isHeld
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.5),
                      blurRadius: 14.0,
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(
            painter: _SensorArcPainter(
              isHeld: isHeld,
              progress: progress,
              accentColor: accentColor,
            ),
            child: Center(
              child: Icon(
                Icons.fingerprint_rounded,
                color: isHeld ? accentColor : Colors.white38,
                size: 26.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5.0),
        Text(
          label,
          style: TextStyle(
            color: isHeld ? accentColor : Colors.white60,
            fontSize: 10.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SensorArcPainter extends CustomPainter {
  final bool isHeld;
  final double progress;
  final Color accentColor;

  _SensorArcPainter({
    required this.isHeld,
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2.0;

    final progressPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _SensorArcPainter oldDelegate) =>
      oldDelegate.isHeld != isHeld || oldDelegate.progress != progress;
}
