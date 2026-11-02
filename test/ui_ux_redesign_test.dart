import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_brain/core/services/haptic_choreographer.dart';
import 'package:split_brain/core/services/leaderboard_service.dart';
import 'package:split_brain/core/services/procedural_audio_synth.dart';
import 'package:split_brain/engine/game_controller.dart';
import 'package:split_brain/ui/overlays/app_settings_sheet.dart';
import 'package:split_brain/ui/overlays/dual_thumb_start_overlay.dart';
import 'package:split_brain/ui/overlays/leaderboard_sheet.dart';
import 'package:split_brain/ui/widgets/split_diamond_emblem.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProceduralAudioSynth.instance.soundEnabled = false;
    HapticChoreographer.instance.hapticsEnabled = false;
  });

  group('UI/UX Redesign & Dummy Data Verification', () {
    test('LeaderboardService contains zero mock/benchmark dummy scores when fresh', () async {
      final global = await LeaderboardService.instance.fetchGlobalTopScores();
      final onePercent = await LeaderboardService.instance
          .fetchOnePercentClubScores();

      expect(
        global,
        isEmpty,
        reason:
            'Must not contain fake players like SYNAPSE_X, NEURO_SLICER, etc.',
      );
      expect(
        onePercent,
        isEmpty,
        reason: 'Must not contain fake players like ZERO_HERO',
      );
    });

    test(
      'LeaderboardService clearLocalScores resets all stored records',
      () async {
        final entry = ScoreEntry(
          id: 'test-1',
          playerHandle: 'ACE',
          score: 12000,
          survivalMs: 25000,
          batteryPct: 80,
          wasOverdrive: false,
          failedHemisphere: 'LEFT',
          createdAt: DateTime.now(),
        );

        await LeaderboardService.instance.recordScore(entry);
        var scores = await LeaderboardService.instance.fetchGlobalTopScores();
        expect(scores.length, 1);
        expect(scores.first.playerHandle, 'ACE');

        await LeaderboardService.instance.clearLocalScores();
        scores = await LeaderboardService.instance.fetchGlobalTopScores();
        expect(scores, isEmpty);
      },
    );

    testWidgets(
      'LeaderboardSheet displays clean empty state without crashing',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: LeaderboardSheet())),
        );

        await tester.pumpAndSettle();

        expect(find.text('Hall of Records'), findsOneWidget);
        expect(find.text('No records yet'), findsOneWidget);
      },
    );

    testWidgets('AppSettingsSheet allows toggling controls and theme', (
      tester,
    ) async {
      final controller = GameController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppSettingsSheet(controller: controller)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Procedural Audio Synth'), findsOneWidget);
      expect(find.text('Tactile Haptics'), findsOneWidget);

      // Tap Gyro Tilt
      await tester.tap(find.text('Gyro Tilt'));
      await tester.pump();
      expect(controller.controlMode, ControlMode.gyroTilt);

      // Tap Touch Drag
      await tester.tap(find.text('Touch Drag'));
      await tester.pump();
      expect(controller.controlMode, ControlMode.touchSwipe);

      // Scroll down to Visual Theme section
      await tester.scrollUntilVisible(find.text('Synthwave 84'), 100);
      await tester.pumpAndSettle();

      // Tap Synthwave 84 theme
      await tester.tap(find.text('Synthwave 84'));
      await tester.pump();
      expect(controller.theme, CyberTheme.synthwave);
    });

    testWidgets(
      'DualThumbStartOverlay renders without layout overflow and triggers start',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = GameController();
        bool settingsOpened = false;
        bool leaderboardOpened = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DualThumbStartOverlay(
                controller: controller,
                onOpenSettings: () => settingsOpened = true,
                onOpenLeaderboard: () => leaderboardOpened = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('SPLIT REFLEX'), findsOneWidget);
        expect(find.text('Dual-Hemisphere Reflex Engine'), findsOneWidget);
        expect(
          find.byType(Image),
          findsOneWidget,
          reason: 'Must display original app icon above app name',
        );
        expect(find.text('Classic'), findsOneWidget);
        expect(find.text('Phase Flux'), findsOneWidget);
        expect(find.text('Pulse Reflex'), findsOneWidget);
        expect(find.text('Start Run'), findsOneWidget);

        // Tap Settings icon
        await tester.tap(find.byIcon(Icons.tune_rounded));
        expect(settingsOpened, isTrue);

        // Tap Leaderboard icon
        await tester.tap(find.byIcon(Icons.emoji_events_outlined));
        expect(leaderboardOpened, isTrue);

        // Tap Start Run
        await tester.tap(find.text('Start Run'));
        expect(controller.state, GamePlayState.countdown);
      },
    );

    testWidgets(
      'SplitDiamondEmblem renders with custom animated convergence and bloom',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: SplitDiamondEmblem(
                  size: 96.0,
                  dockProgress: 0.5,
                  glowIntensity: 0.8,
                  seamIntensity: 0.7,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SplitDiamondEmblem), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );
  });
}
