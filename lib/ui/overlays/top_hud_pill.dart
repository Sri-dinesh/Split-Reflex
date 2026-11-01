import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../../engine/game_controller.dart';

class TopHudPill extends StatelessWidget {
  final GameController controller;
  final VoidCallback onOpenLeaderboard;
  final VoidCallback onToggleSimulation;

  const TopHudPill({
    super.key,
    required this.controller,
    required this.onOpenLeaderboard,
    required this.onToggleSimulation,
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

    Color badgeBg = Colors.black.withOpacity(0.75);
    Color badgeBorder = Colors.white.withOpacity(0.2);
    Color textColor = Colors.white;

    if (isGod) {
      badgeBorder = SplitPalette.godModeGold;
      textColor = SplitPalette.godModeGold;
    } else if (isOverdrive) {
      badgeBorder = SplitPalette.hazardCrimson;
      textColor = SplitPalette.hazardCrimson;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Leaderboard & Telemetry Simulation Trigger
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.leaderboard_outlined, color: Colors.white, size: 22),
                      tooltip: 'Leaderboard',
                      onPressed: onOpenLeaderboard,
                    ),
                    IconButton(
                      icon: Icon(
                        battery.isSimulated ? Icons.battery_charging_full : Icons.battery_std,
                        color: textColor,
                        size: 20,
                      ),
                      tooltip: 'Battery Simulation',
                      onPressed: onToggleSimulation,
                    ),
                  ],
                ),

                // 2. Center Pill (Score & Survival Time)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: badgeBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8.0,
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
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0),
                        width: 1.0,
                        height: 12.0,
                        color: Colors.white30,
                      ),
                      // Timer
                      Text(
                        (controller.state == GamePlayState.attract || controller.state == GamePlayState.countdown)
                            ? '00:00.00'
                            : _formatTimer(controller.survivalTime),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Compact Status Badge (No Overflow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                  decoration: BoxDecoration(
                    color: isGod
                        ? SplitPalette.godModeGold.withOpacity(0.2)
                        : (isOverdrive ? SplitPalette.hazardCrimson.withOpacity(0.2) : Colors.black54),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isGod
                          ? SplitPalette.godModeGold
                          : (isOverdrive ? SplitPalette.hazardCrimson : Colors.white24),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.controlMode == ControlMode.gyroTilt) ...[
                        const Icon(Icons.screen_rotation_rounded, size: 12, color: Colors.purpleAccent),
                        const SizedBox(width: 4.0),
                      ],
                      Text(
                        isGod
                            ? '10x GOD'
                            : (isOverdrive
                                ? '${battery.scoreMultiplier.toStringAsFixed(1)}x'
                                : '${controller.playMode == PlayHandMode.oneHand ? "1H" : "2H"} • ${controller.sessionMode == GameSessionMode.duoCoop ? "DUO" : "SOLO"}'),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Charger Penalty Warning Banner
            if (battery.hasPenalty) ...[
              const SizedBox(height: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: SplitPalette.hazardCrimson,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const Text(
                  'CHARGER PENALTY: MULTIPLIER VOIDED (1.0x)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
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
}
