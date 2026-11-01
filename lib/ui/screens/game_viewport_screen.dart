import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/constants/palette.dart';
import '../../core/services/battery_telemetry_service.dart';
import '../../core/services/haptic_choreographer.dart';
import '../../core/services/leaderboard_service.dart';
import '../../core/services/procedural_audio_synth.dart';
import '../../engine/game_controller.dart';
import '../../engine/painters/master_game_painter.dart';
import '../overlays/app_settings_sheet.dart';
import '../overlays/countdown_overlay.dart';
import '../overlays/death_receipt_overlay.dart';
import '../overlays/dual_thumb_start_overlay.dart';
import '../overlays/leaderboard_sheet.dart';
import '../overlays/top_hud_pill.dart';
import 'cinematic_splash_screen.dart';

class GameViewportScreen extends ConsumerStatefulWidget {
  const GameViewportScreen({super.key});

  @override
  ConsumerState<GameViewportScreen> createState() => _GameViewportScreenState();
}

class _GameViewportScreenState extends ConsumerState<GameViewportScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _controller;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  StreamSubscription? _accelerometerSubscription;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _controller = GameController();

    // Initialize in-memory procedural audio and haptics
    ProceduralAudioSynth.instance.init();
    HapticChoreographer.instance.init();
    LeaderboardService.instance.init();

    // Listen to device tilt / accelerometer for Physical Gyro Tilt mode with low-latency game interval
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          // In portrait orientation, tilting left/right alters the 'x' axis (-9.8 to +9.8)
          // Negative x = tilted right, positive x = tilted left
          _controller.updateRawTilt(-event.x);
        },
        onError: (err) {
          _controller.isGyroAvailable = false;
        },
      );
    } catch (_) {
      _controller.isGyroAvailable = false;
    }

    // Ticker master game loop
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final double rawDt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
      _lastElapsed = elapsed;

      // Sync battery telemetry state into controller
      final batteryService = ref.read(batteryServiceProvider);
      _controller.batteryState = batteryService.state;

      _controller.tick(elapsed, rawDt);
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _ticker.dispose();
    _controller.dispose();
    ProceduralAudioSynth.instance.dispose();
    super.dispose();
  }

  void _openLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LeaderboardSheet(),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSettingsSheet(controller: _controller),
    );
  }

  void _showBatterySimulationSheet() {
    final batteryService = ref.read(batteryServiceProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.0))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BATTERY OVERDRIVE SIMULATOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6.0),
                const Text(
                  'Test real-time hardware reactive Overdrive & 1% God Mode without draining battery.',
                  style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 16.0),
                ListTile(
                  tileColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  leading: const Icon(Icons.flash_on, color: SplitPalette.godModeGold),
                  title: const Text('1% UNPLUGGED (10.0x GOD MODE)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  onTap: () {
                    batteryService.setSimulationOverride(level: 1, isCharging: false);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8.0),
                ListTile(
                  tileColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  leading: const Icon(Icons.bolt, color: SplitPalette.hazardCrimson),
                  title: const Text('5% UNPLUGGED (3.0x OVERDRIVE)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  onTap: () {
                    batteryService.setSimulationOverride(level: 5, isCharging: false);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8.0),
                ListTile(
                  tileColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  leading: const Icon(Icons.power, color: Colors.orangeAccent),
                  title: const Text('5% PLUGGED IN (CHARGER PENALTY 1.0x)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  onTap: () {
                    batteryService.setSimulationOverride(level: 5, isCharging: true);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 8.0),
                ListTile(
                  tileColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  leading: const Icon(Icons.refresh, color: Colors.white70),
                  title: const Text('USE REAL HARDWARE TELEMETRY', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                  onTap: () {
                    batteryService.clearSimulationOverride();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch battery service
    ref.watch(batteryServiceProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        // High-precision raw pointer arena bypassing standard GestureDetector theft
        onPointerDown: (e) {
          _controller.inputRouter.handlePointerDown(
            event: e,
            splitX: _controller.hemisphereState.rawSplitPixels,
            onPointerDown: _controller.handleSidePointerDown,
          );
        },
        onPointerMove: (e) {
          _controller.inputRouter.handlePointerMove(
            event: e,
            splitX: _controller.hemisphereState.rawSplitPixels,
            onPointerMove: _controller.handleSidePointerMove,
          );
        },
        onPointerUp: (e) {
          _controller.inputRouter.handlePointerUp(
            event: e,
            splitX: _controller.hemisphereState.rawSplitPixels,
          );
        },
        onPointerCancel: (e) {
          _controller.inputRouter.handlePointerCancel(
            event: e,
            splitX: _controller.hemisphereState.rawSplitPixels,
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Master Canvas Render Pass (Isolated GPU Layer via RepaintBoundary)
            RepaintBoundary(
              child: CustomPaint(
                painter: MasterGamePainter(controller: _controller),
                size: Size.infinite,
              ),
            ),

            // 2. Reactive UI Overlays Layer
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Active HUD Pill
                    if (_controller.state != GamePlayState.deathReceipt)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: TopHudPill(
                          controller: _controller,
                          onOpenLeaderboard: _openLeaderboard,
                          onToggleSimulation: _showBatterySimulationSheet,
                          onReturnToMenu: _controller.returnToMenu,
                          onOpenSettings: _openSettings,
                        ),
                      ),

                    // Dual Thumb Start Overlay (in attract mode)
                    if (_controller.state == GamePlayState.attract)
                      DualThumbStartOverlay(
                        controller: _controller,
                        onOpenSettings: _openSettings,
                        onOpenLeaderboard: _openLeaderboard,
                      ),

                    // Countdown Sequence (3... 2... 1... GO!)
                    if (_controller.state == GamePlayState.countdown)
                      CountdownOverlay(controller: _controller),

                    // Death Receipt Card (viral share autopsy modal)
                    if (_controller.state == GamePlayState.deathReceipt && _controller.latestAutopsy != null)
                      Container(
                        color: Colors.black.withOpacity(0.85),
                        child: DeathReceiptOverlay(
                          autopsy: _controller.latestAutopsy!,
                          controller: _controller,
                          onRetry: _controller.triggerStartCountdown,
                          onReturnToMenu: _controller.returnToMenu,
                          onOpenLeaderboard: _openLeaderboard,
                          onOpenSettings: _openSettings,
                        ),
                      ),
                  ],
                );
              },
            ),

            // 3. Cinematic Procedural Splash Screen
            if (_showSplash)
              Positioned.fill(
                child: CinematicSplashScreen(
                  onComplete: () {
                    if (mounted) {
                      setState(() {
                        _showSplash = false;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
