import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_brain/core/services/haptic_choreographer.dart';
import 'package:split_brain/core/services/leaderboard_service.dart';
import 'package:split_brain/core/services/preferences_service.dart';
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
        expect(find.text('Breach Pong'), findsOneWidget);
        expect(find.text('Tide Lock'), findsOneWidget);
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
      'Pilot stat ribbon shows callsign, best, last run and a fresh-record badge',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final LeaderboardService service = LeaderboardService.instance;
        await service.savePlayerHandle('ACE');

        // First run sets a record; second run does not beat it.
        Future<ScoreEntry> entry(int score) => Future.value(
          ScoreEntry(
            id: 'run-$score',
            playerHandle: 'ACE',
            score: score,
            survivalMs: 10000,
            batteryPct: 80,
            wasOverdrive: false,
            failedHemisphere: 'LEFT',
            createdAt: DateTime.now(),
          ),
        );
        await service.recordScore(await entry(7340));
        await service.recordScore(await entry(5000));

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final controller = GameController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DualThumbStartOverlay(
                controller: controller,
                onOpenSettings: () {},
                onOpenLeaderboard: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ACE'), findsOneWidget);
        expect(find.text('BEST'), findsOneWidget);
        expect(find.text('7,340'), findsOneWidget);
        expect(find.text('LAST'), findsOneWidget);
        expect(find.text('5,000'), findsOneWidget);
        // Last run did not match the best → no fresh-record badge.
        expect(find.text('NEW'), findsNothing);

        // A new record run refreshes the ribbon and gold-lights the badge.
        await service.clearLocalScores();
        controller.toggleSessionMode();
        await tester.pumpAndSettle();
        expect(find.text('—'), findsNWidgets(2));

        await service.recordScore(await entry(9000));
        controller.toggleSessionMode();
        await tester.pumpAndSettle();
        // Best and last run now show the same fresh record: gold BEST value
        // beside the white LAST value, plus the NEW badge.
        expect(
          find.text('9,000'),
          findsNWidgets(2),
        );
        expect(find.text('NEW'), findsOneWidget);
      },
    );

    testWidgets(
      'Quick mute button toggles and persists sound with live icon feedback',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await PreferencesService.instance.load();
        ProceduralAudioSynth.instance.soundEnabled = true;

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DualThumbStartOverlay(
                controller: GameController(),
                onOpenSettings: () {},
                onOpenLeaderboard: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

        // One tap silences the engine and persists the choice.
        await tester.tap(find.byIcon(Icons.volume_up_rounded));
        await tester.pumpAndSettle();
        expect(ProceduralAudioSynth.instance.soundEnabled, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('pref_sound_enabled'), isFalse);
        expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

        // Tapping again unmutes; the settings switch shares the same state.
        await tester.tap(find.byIcon(Icons.volume_off_rounded));
        await tester.pumpAndSettle();
        expect(ProceduralAudioSynth.instance.soundEnabled, isTrue);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'pref_sound_enabled',
          ),
          isTrue,
        );
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
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
