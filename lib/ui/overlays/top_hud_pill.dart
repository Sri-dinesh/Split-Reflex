import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../../engine/game_controller.dart';

class TopHudPill extends StatelessWidget {
  final GameController controller;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onToggleSimulation;
  final VoidCallback? onReturnToMenu;
  final VoidCallback? onOpenSettings;

  const TopHudPill({
    super.key,
    required this.controller,
    required this.onOpenLeaderboard,
    required this.onToggleSimulation,
    this.onReturnToMenu,
    this.onOpenSettings,
  });

  String _formatTimer(double seconds) {
    final int mins = (seconds / 60).floor();
    final double secs = seconds % 60;
    final String minStr = mins.toString().padLeft(2, '0');
    final String secStr = secs.toStringAsFixed(2).padLeft(5, '0');
    return '$minStr:$secStr';
  }

  @override
  Widget build(BuildContext context) {
    final battery = controller.batteryState;
    final isGod = battery.isGodMode;
    final isOverdrive = battery.isOverdrive;
    final isPlaying = controller.state == GamePlayState.playing;
    final bool isOneLaneOffline = controller.playMode == PlayHandMode.oneHand &&
        (!controller.orbAlive || !controller.dartAlive) &&
        (controller.orbAlive != controller.dartAlive);

    Color badgeBg = const Color(0xFF0C0C10).withOpacity(0.9);
    Color badgeBorder = Colors.white.withOpacity(0.12);
    Color textColor = Colors.white;

    if (isGod) {
      badgeBorder = SplitPalette.godModeGold.withOpacity(0.7);
      textColor = SplitPalette.godModeGold;
    } else if (isOverdrive) {
      badgeBorder = SplitPalette.hazardCrimson.withOpacity(0.7);
      textColor = SplitPalette.hazardCrimson;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Left Action Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPlaying) ...[
                      // In-Game Abort / Exit Button
                      _buildGlassIcon(
                        icon: Icons.close_rounded,
                        tooltip: 'Abort Run',
                        onTap: () {
                          ProceduralAudioSynth.instance.playTap();
                          HapticChoreographer.instance.triggerTap();
                          if (onReturnToMenu != null) {
                            onReturnToMenu!();
                          } else {
                            controller.returnToMenu();
                          }
                        },
                      ),
                      const SizedBox(width: 8.0),
                      _buildGlassIcon(
                        icon: battery.isSimulated ? Icons.battery_charging_full_rounded : Icons.bolt_rounded,
                        tooltip: 'Battery Simulation',
                        iconColor: isGod
                            ? SplitPalette.godModeGold
                            : (isOverdrive ? SplitPalette.hazardCrimson : Colors.white70),
                        onTap: () {
                          ProceduralAudioSynth.instance.playTap();
                          HapticChoreographer.instance.triggerTap();
                          onToggleSimulation();
                        },
                      ),
                    ] else ...[
                      // In Menu (Attract) state
                      _buildGlassIcon(
                        icon: Icons.emoji_events_outlined,
                        tooltip: 'Hall of Records',
                        onTap: () {
                          ProceduralAudioSynth.instance.playTap();
                          HapticChoreographer.instance.triggerTap();
                          onOpenLeaderboard();
                        },
                      ),
                      const SizedBox(width: 8.0),
                      if (onOpenSettings != null)
                        _buildGlassIcon(
                          icon: Icons.tune_rounded,
                          tooltip: 'Settings',
                          onTap: () {
                            ProceduralAudioSynth.instance.playTap();
                            HapticChoreographer.instance.triggerTap();
                            onOpenSettings!();
                          },
                        ),
                    ],
                  ],
                ),

                // 2. Center Telemetry HUD (Score & Time)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(22.0),
                    border: Border.all(color: badgeBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 14.0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Score
                      Text(
                        '${controller.currentScore.toInt()}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                        width: 1.0,
                        height: 14.0,
                        color: Colors.white24,
                      ),
                      // Timer
                      Text(
                        (controller.state == GamePlayState.attract || controller.state == GamePlayState.countdown)
                            ? '00:00.00'
                            : _formatTimer(controller.survivalTime),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Multiplier / Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: isGod
                        ? SplitPalette.godModeGold.withOpacity(0.15)
                        : (isOverdrive ? SplitPalette.hazardCrimson.withOpacity(0.15) : Colors.white.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isGod
                          ? SplitPalette.godModeGold.withOpacity(0.6)
                          : (isOverdrive ? SplitPalette.hazardCrimson.withOpacity(0.6) : Colors.white12),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    isGod
                        ? '10x GOD'
                        : (isOverdrive
                            ? '${battery.scoreMultiplier.toStringAsFixed(1)}x'
                            : (controller.playMode == PlayHandMode.oneHand ? '1-HAND' : '2-HANDS')),
                    style: TextStyle(
                      color: isGod
                          ? SplitPalette.godModeGold
                          : (isOverdrive ? SplitPalette.hazardCrimson : Colors.white70),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            // One Lane Offline Survival Alert (Subtle, non-disruptive)
            if (isOneLaneOffline && isPlaying) ...[
              const SizedBox(height: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: SplitPalette.hazardCrimson.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: Colors.white30, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: SplitPalette.hazardCrimson.withOpacity(0.3),
                      blurRadius: 10.0,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: Colors.white),
                    SizedBox(width: 6.0),
                    Text(
                      '1 LANE DOWN • RECOVERY ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Charger Penalty Warning Banner
            if (battery.hasPenalty) ...[
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: SplitPalette.hazardCrimson,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: const Text(
                  'CHARGER CONNECTED • MULTIPLIER VOIDED (1.0x)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlassIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.0),
        child: Container(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white12, width: 1.0),
          ),
          child: Icon(icon, color: iconColor ?? Colors.white, size: 18.0),
        ),
      ),
    );
  }
}
