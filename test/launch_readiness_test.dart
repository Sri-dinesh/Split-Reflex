import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_brain/core/services/battery_telemetry_service.dart';
import 'package:split_brain/core/services/haptic_choreographer.dart';
import 'package:split_brain/core/services/leaderboard_service.dart';
import 'package:split_brain/core/services/preferences_service.dart';
import 'package:split_brain/core/services/procedural_audio_synth.dart';
import 'package:split_brain/engine/game_controller.dart';
import 'package:split_brain/ui/overlays/app_settings_sheet.dart';
import 'package:split_brain/ui/overlays/dual_thumb_start_overlay.dart';

/// Minimal stand-in for the platform battery channel.
class _FakeBattery implements BatterySource {
  int level = 100;

  @override
  Future<int> get batteryLevel async => level;

  @override
  Stream<BatteryState> get onBatteryStateChanged =>
      const Stream<BatteryState>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await PreferencesService.instance.load();
    ProceduralAudioSynth.instance.soundEnabled = false;
    HapticChoreographer.instance.hapticsEnabled = false;
  });

  group('PreferencesService', () {
    test('persists sound, haptics and gameplay rules across reloads', () async {
      final prefs = PreferencesService.instance;

      await prefs.setSoundEnabled(false);
      await prefs.setHapticsEnabled(false);
      await prefs.setTheme(CyberTheme.synthwave.name);
      await prefs.setControlMode(ControlMode.gyroTilt.name);
      await prefs.setPlayMode(PlayHandMode.oneHand.name);
      await prefs.setSessionMode(GameSessionMode.duoCoop.name);
      await prefs.setPairMode(GamePairMode.dimensionBreach.name);

      // Simulate a cold start: drop the cached instance and reload.
      await prefs.load();

      expect(prefs.soundEnabled, isFalse);
      expect(prefs.hapticsEnabled, isFalse);
      expect(prefs.theme, CyberTheme.synthwave.name);
      expect(prefs.controlMode, ControlMode.gyroTilt.name);
      expect(prefs.playMode, PlayHandMode.oneHand.name);
      expect(prefs.sessionMode, GameSessionMode.duoCoop.name);
      expect(prefs.pairMode, GamePairMode.dimensionBreach.name);

      // The runtime singletons follow the persisted flags.
      expect(ProceduralAudioSynth.instance.soundEnabled, isFalse);
      expect(HapticChoreographer.instance.hapticsEnabled, isFalse);
    });

    test('clearAll wipes storage and restores factory defaults', () async {
      final prefs = PreferencesService.instance;
      await prefs.setSoundEnabled(false);
      await prefs.setTheme(CyberTheme.cyberGold.name);

      await prefs.clearAll();
      await prefs.load();

      expect(prefs.soundEnabled, isTrue);
      expect(prefs.hapticsEnabled, isTrue);
      expect(prefs.theme, isNull);
      expect(ProceduralAudioSynth.instance.soundEnabled, isTrue);
      expect(HapticChoreographer.instance.hapticsEnabled, isTrue);
    });
  });

  group('LeaderboardService', () {
    test('sanitizeHandle strips control characters and clamps length', () {
      expect(LeaderboardService.sanitizeHandle(null), 'PILOT');
      expect(LeaderboardService.sanitizeHandle('   '), 'PILOT');
      expect(LeaderboardService.sanitizeHandle('ace\n\tpilot'), 'ACE PILOT');
      expect(
        LeaderboardService.sanitizeHandle('abcdefghijklmnopqrstuvwxyz'),
        'ABCDEFGHIJKLMN',
      );
      expect(LeaderboardService.sanitizeHandle('  ace  '), 'ACE');
    });

    test('caps stored history at maxStoredScores', () async {
      final service = LeaderboardService.instance;
      final now = DateTime.now();

      for (int i = 0; i < LeaderboardService.maxStoredScores + 25; i++) {
        await service.recordScore(
          ScoreEntry(
            id: 'run-$i',
            playerHandle: 'ACE',
            score: i,
            survivalMs: 1000,
            batteryPct: 50,
            wasOverdrive: false,
            failedHemisphere: 'LEFT',
            createdAt: now,
          ),
        );
      }

      final scores = await service.fetchGlobalTopScores();
      expect(scores.length, LeaderboardService.maxStoredScores);
      // The newest run must still be present.
      expect(scores.any((s) => s.id == 'run-224'), isTrue);
      // The oldest runs were evicted.
      expect(scores.any((s) => s.id == 'run-0'), isFalse);
    });

    test('ignores corrupt rows instead of failing the whole leaderboard', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'split_brain_local_scores': <String>[
          'not-json',
          '{"id":"ok","player_handle":"ACE","score":42,"survival_ms":1000,'
              '"battery_pct":50,"was_overdrive":false,'
              '"failed_hemisphere":"LEFT","created_at":"2026-01-01T00:00:00Z"}',
          '{"score":"not-a-number"}',
        ],
      });

      final scores = await LeaderboardService.instance.fetchGlobalTopScores();
      expect(scores, isNotEmpty);
      expect(scores.first.id, 'ok');
      expect(scores.first.score, 42);
    });

    test('rejects negative or absurd telemetry', () async {
      final service = LeaderboardService.instance;
      await service.clearLocalScores();

      await service.recordScore(
        ScoreEntry(
          id: 'bad',
          playerHandle: 'ACE',
          score: -1,
          survivalMs: 1000,
          batteryPct: 50,
          wasOverdrive: false,
          failedHemisphere: 'LEFT',
          createdAt: DateTime.now(),
        ),
      );

      expect(await service.fetchGlobalTopScores(), isEmpty);
    });

    test('clearAllUserData removes callsign, scores and high score', () async {
      final service = LeaderboardService.instance;
      await service.savePlayerHandle('NEO');
      await service.recordScore(
        ScoreEntry(
          id: 'run',
          playerHandle: 'NEO',
          score: 900,
          survivalMs: 5000,
          batteryPct: 50,
          wasOverdrive: false,
          failedHemisphere: 'RIGHT',
          createdAt: DateTime.now(),
        ),
      );

      expect(await service.getLocalHighScore(), 900);

      await service.clearAllUserData();

      expect(await service.getPlayerHandle(), 'PILOT');
      expect(await service.getLocalHighScore(), 0);
      expect(await service.fetchGlobalTopScores(), isEmpty);
    });
  });

  group('BatteryTelemetryService', () {
    test(
      'override applies instantly and clearing it restores telemetry',
      () async {
        final battery = _FakeBattery();
        final service = BatteryTelemetryService(source: battery);
        addTearDown(service.dispose);

        await pumpEventQueue();
        expect(service.state.tier, OverdriveTier.standard);

        service.setSimulationOverride(level: 1, isCharging: false);
        expect(service.state.tier, OverdriveTier.godMode10x);
        expect(service.state.isSimulated, isTrue);

        service.setSimulationOverride(level: 5, isCharging: true);
        expect(service.state.tier, OverdriveTier.chargerPenalty);

        service.clearSimulationOverride();
        await pumpEventQueue();

        expect(service.state.tier, OverdriveTier.standard);
        expect(service.state.batteryLevel, 100);
        expect(service.state.isSimulated, isFalse);
      },
    );

    test(
      'repeated clearSimulationOverride calls are idempotent and leak-free',
      () async {
        final battery = _FakeBattery();
        final service = BatteryTelemetryService(source: battery);
        addTearDown(service.dispose);

        await pumpEventQueue();

        int notifications = 0;
        service.addListener(() => notifications++);

        for (int i = 0; i < 25; i++) {
          service.setSimulationOverride(level: 3, isCharging: false);
          service.clearSimulationOverride();
        }
        await pumpEventQueue();

        // 25 overrides + 1 restore; a leaked timer/subscription would keep
        // pushing notifications after the loop.
        expect(notifications, lessThanOrEqualTo(26));

        final int settled = notifications;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifications, settled);
      },
    );

    test('methods are safe after dispose', () async {
      final service = BatteryTelemetryService(source: _FakeBattery());
      await pumpEventQueue();
      service.dispose();

      expect(
        () => service.setSimulationOverride(level: 1, isCharging: false),
        returnsNormally,
      );
      expect(service.clearSimulationOverride, returnsNormally);
    });
  });

  group('GameController data reset', () {
    test('resetToFactoryDefaults restores every gameplay rule', () async {
      final controller = GameController();
      controller.setTheme(CyberTheme.matrix);
      controller.setControlMode(ControlMode.gyroTilt);
      controller.setPlayMode(PlayHandMode.oneHand);
      controller.setSessionMode(GameSessionMode.duoCoop);
      controller.setGamePairMode(GamePairMode.tideLock);

      controller.resetToFactoryDefaults();

      expect(controller.theme, CyberTheme.monochrome);
      expect(controller.controlMode, ControlMode.touchSwipe);
      expect(controller.playMode, PlayHandMode.twoHands);
      expect(controller.sessionMode, GameSessionMode.solo);
      expect(controller.gamePairMode, GamePairMode.classic);
      expect(controller.state, GamePlayState.attract);
    });
  });

  group('Small-screen layouts', () {
    Future<void> expectNoOverflow(
      WidgetTester tester,
      Size size,
      Widget child,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }

    testWidgets('start overlay fits a 320x480 screen', (tester) async {
      final controller = GameController();
      await expectNoOverflow(
        tester,
        const Size(320, 480),
        DualThumbStartOverlay(
          controller: controller,
          onOpenSettings: () {},
          onOpenLeaderboard: () {},
        ),
      );
      expect(find.text('Start Run'), findsOneWidget);
      expect(find.textContaining('Photosensitivity'), findsOneWidget);
    });

    testWidgets('settings sheet fits a 320x480 screen', (tester) async {
      final controller = GameController();
      await expectNoOverflow(
        tester,
        const Size(320, 480),
        AppSettingsSheet(controller: controller),
      );
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Privacy & Data'), findsOneWidget);
    });

    testWidgets('start overlay fits a tall narrow 360x800 screen', (
      tester,
    ) async {
      final controller = GameController();
      await expectNoOverflow(
        tester,
        const Size(360, 800),
        DualThumbStartOverlay(
          controller: controller,
          onOpenSettings: () {},
          onOpenLeaderboard: () {},
        ),
      );
    });
  });
}
