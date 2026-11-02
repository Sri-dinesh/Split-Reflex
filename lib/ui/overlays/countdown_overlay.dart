import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../../engine/game_controller.dart';

class CountdownOverlay extends StatelessWidget {
  final GameController controller;

  const CountdownOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final double remaining = controller.countdownTimer;
    final int displayNum = remaining.ceil().clamp(1, 3);
    final double frac =
        remaining - (displayNum - 1); // 0.0 -> 1.0 within this second
    final double scale = 0.8 + 0.5 * (frac.clamp(0.0, 1.0));
    final double opacity = (frac.clamp(0.0, 1.0)).clamp(0.2, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Tap to bypass countdown immediately
        controller.startRun();
      },
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Text(
                  'SYNCING NEURAL PATHWAYS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    displayNum > 0 ? '$displayNum' : 'GO!',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      color: displayNum == 1
                          ? SplitPalette.hazardCrimson
                          : SplitPalette.nearMissCyan,
                      shadows: [
                        Shadow(
                          color: displayNum == 1
                              ? SplitPalette.hazardCrimson
                              : SplitPalette.nearMissCyan,
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'TAP TO SKIP COUNTDOWN',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
