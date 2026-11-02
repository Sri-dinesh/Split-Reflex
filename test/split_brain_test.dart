import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_brain/core/services/battery_telemetry_service.dart';
import 'package:split_brain/core/services/procedural_audio_synth.dart';
import 'package:split_brain/core/utils/math_utils.dart';
import 'package:split_brain/core/utils/seeded_rng.dart';
import 'package:split_brain/engine/entities/obstacle_entity.dart';
import 'package:split_brain/engine/entities/particle_pool.dart';
import 'package:split_brain/engine/entities/phase_flux_entity.dart';
import 'package:split_brain/engine/entities/shield_ping_entity.dart';
import 'package:split_brain/engine/entities/slalom_drift_entity.dart';
import 'package:split_brain/engine/entities/quantum_warp_entity.dart';
import 'package:split_brain/engine/game_controller.dart';
import 'package:split_brain/engine/hemisphere_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  ProceduralAudioSynth.instance.soundEnabled = false;

  group('Zero External Asset Verification', () {
    test('pubspec.yaml declares 0 image, sprite, font, or audio files', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final content = pubspecFile.readAsStringSync();
      expect(
        content.contains('assets:'),
        isFalse,
        reason: 'Game must have 100% procedural assets and 0 assets declared in pubspec.yaml',
      );
    });
  });

  group('Procedural In-Memory Audio Synthesizer', () {
    test('buildWavBytes generates valid 44-byte RIFF/WAVE header and 16-bit PCM bytes', () {
      final List<double> testSamples = [0.0, 0.5, 1.0, -0.5, -1.0];
      final bytes = ProceduralAudioSynth.buildWavBytes(
        testSamples,
        sampleRate: 44100,
      );

      // Verify RIFF header
      expect(bytes.length, equals(44 + testSamples.length * 2));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      expect(String.fromCharCodes(bytes.sublist(12, 16)), equals('fmt '));
      expect(String.fromCharCodes(bytes.sublist(36, 40)), equals('data'));

      // Verify sample rate 44100
      final byteData = bytes.buffer.asByteData();
      expect(byteData.getUint32(24, Endian.little), equals(44100));
      expect(byteData.getUint16(34, Endian.little), equals(16)); // 16-bit PCM
    });

    test(
      'Synthesizes all game sound effects in memory without crashing',
      () async {
        final synth = ProceduralAudioSynth.instance;
        await synth.init();
        expect(synth.tapWav.length, greaterThan(44));
        expect(synth.nearMissWav.length, greaterThan(44));
        expect(synth.swapTickWav.length, greaterThan(44));
        expect(synth.swapExecuteWav.length, greaterThan(44));
        expect(synth.deathShatterWav.length, greaterThan(44));
        expect(synth.chargeHumWav.length, greaterThan(44));
      },
    );
  });

  group('Geometric Math & Collision Calculations', () {
    test('Circle to AABB intersection detection', () {
      const aabb = Rect.fromLTWH(50, 50, 40, 40);

      // Circle intersecting AABB
      expect(
        MathUtils.circleIntersectsAABB(cx: 45, cy: 60, radius: 10, aabb: aabb),
        isTrue,
      );

      // Circle completely outside AABB
      expect(
        MathUtils.circleIntersectsAABB(cx: 10, cy: 10, radius: 10, aabb: aabb),
        isFalse,
      );
    });

    test('Damped harmonic spring snaps smoothly to target', () {
      final val0 = MathUtils.dampedSpring(
        target: 100,
        delta: 30,
        timeElapsed: 0.0,
      );
      expect(val0, closeTo(130.0, 0.001));

      final valLate = MathUtils.dampedSpring(
        target: 100,
        delta: 30,
        timeElapsed: 2.0,
      );
      expect(valLate, closeTo(100.0, 0.5));
    });

    test('SeededRng generates guaranteed reachable safe corridor', () {
      final rng = SeededRng(42);
      double corridorX = 100.0;
      for (int i = 0; i < 50; i++) {
        final newX = rng.getNextSafeCorridor(
          prevCorridorX: corridorX,
          laneLeft: 0.0,
          laneRight: 200.0,
        );
        expect(newX, greaterThanOrEqualTo(35.0));
        expect(newX, lessThanOrEqualTo(165.0));
        corridorX = newX;
      }
    });
  });

  group('1% Hero Battery Overdrive System & Anti-Cheat', () {
    test(
      'Telemetry triggers Overdrive 3x at 10% unplugged and God Mode 10x at 1%',
      () {
        final service = BatteryTelemetryService();

        // Standard 100%
        service.setSimulationOverride(level: 100, isCharging: false);
        expect(service.state.tier, equals(OverdriveTier.standard));
        expect(service.state.scoreMultiplier, equals(1.0));

        // Overdrive 3x (5% unplugged)
        service.setSimulationOverride(level: 5, isCharging: false);
        expect(service.state.tier, equals(OverdriveTier.overdrive3x));
        expect(service.state.scoreMultiplier, equals(3.0));
        expect(service.state.isOverdrive, isTrue);

        // 1% God Mode (1% unplugged)
        service.setSimulationOverride(level: 1, isCharging: false);
        expect(service.state.tier, equals(OverdriveTier.godMode10x));
        expect(service.state.scoreMultiplier, equals(10.0));
        expect(service.state.isGodMode, isTrue);

        // Charger Penalty Anti-Cheat: Plugging in reverts multiplier to 1.0x
        service.setSimulationOverride(level: 1, isCharging: true);
        expect(service.state.tier, equals(OverdriveTier.chargerPenalty));
        expect(service.state.scoreMultiplier, equals(1.0));
        expect(service.state.hasPenalty, isTrue);
      },
    );
  });

  group('Cognitive Mutation Engine & Game Loop', () {
    test('Initializes with Calibration Phase (00s-15s) and 50/50 split', () {
      final controller = GameController();
      controller.updateDimensions(400, 800);
      expect(controller.hemisphereState.splitX, equals(0.5));
      expect(
        controller.hemisphereState.leftMechanic,
        equals(HemisphereMechanic.orb),
      );
      expect(
        controller.hemisphereState.rightMechanic,
        equals(HemisphereMechanic.dart),
      );
    });

    test(
      'Swaps hemispheres and cross-translates mechanics at 15s mutation',
      () {
        final state = HemisphereState();
        state.reset(400.0);
        expect(state.leftMechanic, equals(HemisphereMechanic.orb));
        expect(state.rightMechanic, equals(HemisphereMechanic.dart));

        // Execute 15s mutation swap
        state.executeSwap(isOverdrive: false, isGodMode: false);
        expect(state.leftMechanic, equals(HemisphereMechanic.dart));
        expect(state.rightMechanic, equals(HemisphereMechanic.orb));
      },
    );

    test('Inverts polarity at 45s mutation', () {
      final state = HemisphereState();
      state.reset(400.0);

      // Advance survival time past 45s
      state.update(
        dt: 0.033,
        survivalTime: 46.0,
        screenWidth: 400.0,
        isOverdrive: false,
        isGodMode: false,
        onSwapWarningTick: (_) {},
        onSwapExecuted: () {},
      );

      expect(state.isPolarityInverted, isTrue);
    });

    test(
      'Zero heap allocation particle pool spawns and recycles particles',
      () {
        final pool = ParticlePool();
        expect(pool.particles.length, equals(200));

        pool.spawnBurst(
          origin: const Offset(100, 100),
          count: 50,
          color: Colors.red,
          speed: 200.0,
        );

        int activeCount = pool.particles.where((p) => p.active).length;
        expect(activeCount, equals(50));

        // Simulate 5 seconds to decay particles
        pool.update(5.0);
        activeCount = pool.particles.where((p) => p.active).length;
        expect(activeCount, equals(0));
      },
    );

    test('2 Hands Mode (Strict): Either hemisphere failing triggers immediate game over', () {
      final controller = GameController();
      controller.updateDimensions(400, 800);
      controller.setPlayMode(PlayHandMode.twoHands);
      controller.startRun();
      expect(controller.state, equals(GamePlayState.playing));
      expect(controller.orbAlive, isTrue);
      expect(controller.dartAlive, isTrue);

      // Force orb out of bounds (spike collision)
      controller.orb.y = 5.0; // below spikeThreshold of 14.0
      controller.tick(Duration.zero, 0.016);

      // In 2 Hands mode, run ends immediately
      expect(controller.state, equals(GamePlayState.deathSlowmo));
    });

    test('1 Hand Mode (Survival): One hemisphere failing allows surviving side to continue', () {
      final controller = GameController();
      controller.updateDimensions(400, 800);
      controller.setPlayMode(PlayHandMode.oneHand);
      controller.startRun();
      expect(controller.state, equals(GamePlayState.playing));
      expect(controller.orbAlive, isTrue);
      expect(controller.dartAlive, isTrue);

      // Force orb out of bounds (spike collision)
      controller.orb.y = 5.0;
      controller.tick(Duration.zero, 0.016);

      // In 1 Hand mode, orb is dead, but dart is alive and run continues
      expect(controller.orbAlive, isFalse);
      expect(controller.dartAlive, isTrue);
      expect(controller.state, equals(GamePlayState.playing));

      // Now force dart to hit a monolith
      controller.monoliths.add(
        Monolith(
          x: controller.dart.x,
          y: controller.dart.railY,
          width: 50,
          height: 50,
          speed: 100,
        ),
      );
      controller.tick(Duration.zero, 0.016);

      // Both sides dead -> game over autopsy triggered
      expect(controller.dartAlive, isFalse);
      expect(controller.state, equals(GamePlayState.deathSlowmo));
    });

    test(
      'Duo Co-op Mode correctly attributes responsible party on collapse',
      () {
        final controller = GameController();
        controller.updateDimensions(400, 800);
        controller.setSessionMode(GameSessionMode.duoCoop);
        controller.startRun();

        // Force orb out of bounds on LEFT hemisphere
        controller.orb.y = 5.0;
        controller.tick(Duration.zero, 0.016);

        // Autopsy should record DUO mode and attribute collapse to Player 1
        expect(controller.latestAutopsy, isNotNull);
        expect(
          controller.latestAutopsy!.sessionMode,
          equals(GameSessionMode.duoCoop),
        );
        expect(
          controller.latestAutopsy!.responsibleParty,
          contains('PLAYER 1'),
        );
      },
    );

    test('ControlMode.gyroTilt steers Dart via updateRawTilt', () {
      final controller = GameController();
      controller.updateDimensions(400, 800);
      controller.setControlMode(ControlMode.gyroTilt);
      controller.startRun();

      final double initialDartTargetX = controller.dart.targetX;
      // Simulate tilting phone to the right
      controller.updateRawTilt(3.0);
      controller.tick(Duration.zero, 0.016);

      expect(controller.dart.targetX, isNot(equals(initialDartTargetX)));
    });

    test('Procedural CyberTheme cycles correctly through 4 variants', () {
      final controller = GameController();
      expect(controller.theme, equals(CyberTheme.monochrome));

      controller.cycleTheme();
      expect(controller.theme, equals(CyberTheme.synthwave));

      controller.cycleTheme();
      expect(controller.theme, equals(CyberTheme.matrix));

      controller.cycleTheme();
      expect(controller.theme, equals(CyberTheme.cyberGold));

      controller.cycleTheme();
      expect(controller.theme, equals(CyberTheme.monochrome));
    });

    test('Attract mode keeps survivalTime at 0.0 and returnToMenu resets correctly', () {
      final controller = GameController();
      controller.updateDimensions(400, 800);
      expect(controller.state, equals(GamePlayState.attract));
      expect(controller.survivalTime, equals(0.0));

      // Simulate 5 seconds ticking in attract mode
      for (int i = 0; i < 300; i++) {
        controller.tick(Duration.zero, 0.016);
      }
      expect(controller.survivalTime, equals(0.0));
      expect(controller.currentScore, equals(0.0));

      // Start run and tick
      controller.startRun();
      expect(controller.state, equals(GamePlayState.playing));
      controller.tick(Duration.zero, 1.0);
      expect(controller.survivalTime, greaterThan(0.0));

      // Return to menu
      controller.returnToMenu();
      expect(controller.state, equals(GamePlayState.attract));
      expect(controller.survivalTime, equals(0.0));
      expect(controller.currentScore, equals(0.0));
    });

    test(
      'GamePairMode cycles properly through classic, phaseFlux, pulseReflex',
      () {
        final controller = GameController();
        expect(controller.gamePairMode, equals(GamePairMode.classic));

        controller.cycleGamePairMode();
        expect(controller.gamePairMode, equals(GamePairMode.phaseFlux));
        expect(
          controller.hemisphereState.leftMechanic,
          equals(HemisphereMechanic.phaseCore),
        );
        expect(
          controller.hemisphereState.rightMechanic,
          equals(HemisphereMechanic.slalomDrift),
        );

        controller.cycleGamePairMode();
        expect(controller.gamePairMode, equals(GamePairMode.pulseReflex));
        expect(
          controller.hemisphereState.leftMechanic,
          equals(HemisphereMechanic.shieldPing),
        );
        expect(
          controller.hemisphereState.rightMechanic,
          equals(HemisphereMechanic.quantumWarp),
        );

        controller.cycleGamePairMode();
        expect(controller.gamePairMode, equals(GamePairMode.classic));
      },
    );

    test('PhaseCore flips polarity and absorbs matching walls', () {
      final core = PhaseCoreEntity();
      expect(core.polarity, equals(PolarityColor.cyan));
      core.flip();
      expect(core.polarity, equals(PolarityColor.crimson));
      core.flip();
      expect(core.polarity, equals(PolarityColor.cyan));
    });

    test('ShieldPing triggers precision deflection window and cools down', () {
      final shield = ShieldPingEntity();
      expect(shield.isDeflecting, isFalse);
      shield.triggerPing();
      expect(shield.isDeflecting, isTrue);
      // After duration expires
      shield.update(0.35);
      expect(shield.isDeflecting, isFalse);
    });

    test('QuantumWarp hops tracks instantaneously between left and right', () {
      final warp = QuantumWarpEntity();
      expect(warp.track, equals(QuantumTrack.left));
      warp.warp();
      expect(warp.track, equals(QuantumTrack.right));
      warp.warp();
      expect(warp.track, equals(QuantumTrack.left));
    });

    test(
      'SlalomDriftEntity provides straight centered runway at introFactor 0.0',
      () {
        final glider = SlalomDriftEntity();
        const double laneLeft = 200.0;
        const double laneRight = 400.0;
        glider.reset(initialX: 300.0, initialY: 500.0);

        // At start (introFactor = 0.0), chasm center must be exactly lane midpoint (300.0)
        final centerAtStart = glider.getChasmCenter(
          500.0,
          laneLeft,
          laneRight,
          introFactor: 0.0,
        );
        expect(centerAtStart, equals(300.0));

        // Chasm width is wider during intro
        final normalW = glider.getChasmWidth(200.0, introFactor: 1.0);
        final introW = glider.getChasmWidth(200.0, introFactor: 0.0);
        expect(introW, greaterThan(normalW));
      },
    );

    test('PhaseFlux and PulseReflex survive mutation swap smoothly without collision', () {
      final controller = GameController();
      controller.updateDimensions(400.0, 800.0);
      controller.setGamePairMode(GamePairMode.phaseFlux);
      controller.startRun();

      expect(controller.state, equals(GamePlayState.playing));
      expect(
        controller.hemisphereState.leftMechanic,
        equals(HemisphereMechanic.phaseCore),
      );
      expect(
        controller.hemisphereState.rightMechanic,
        equals(HemisphereMechanic.slalomDrift),
      );

      // Trigger mutation swap
      controller.executeMutation();
      controller.tick(Duration.zero, 0.033);

      // Verify mutation executed without instant failure
      expect(controller.state, equals(GamePlayState.playing));
      expect(
        controller.hemisphereState.leftMechanic,
        equals(HemisphereMechanic.slalomDrift),
      );
      expect(
        controller.hemisphereState.rightMechanic,
        equals(HemisphereMechanic.phaseCore),
      );

      // Verify Slalom was cross-translated into the new left lane (0 - 200)
      expect(controller.slalomDrift.x, lessThan(200.0));
      expect(controller.slalomDrift.x, greaterThan(0.0));
      expect(controller.phaseCore.x, greaterThan(200.0));
    });

    test('1-Hand Mode: Surviving side crashing triggers game over autopsy', () {
      final controller = GameController();
      controller.updateDimensions(400.0, 800.0);
      controller.setPlayMode(PlayHandMode.oneHand);
      controller.startRun();
      controller.tick(Duration.zero, 4.0); // Pass grace period

      // Kill Left (Orb)
      controller.orb.y = 5.0; // spikes
      controller.tick(Duration.zero, 0.016);

      // Orb is dead, Dart is alive
      expect(controller.orbAlive, isFalse);
      expect(controller.dartAlive, isTrue);
      expect(controller.state, equals(GamePlayState.playing));

      // Now crash Dart into a monolith
      controller.monoliths.add(
        Monolith(
          x: controller.dart.x,
          y: controller.dart.railY - 5.0,
          width: 40.0,
          height: 40.0,
          speed: 100.0,
        ),
      );
      controller.tick(Duration.zero, 0.016);

      // Both sides are now dead, triggers death
      expect(controller.dartAlive, isFalse);
      expect(controller.state, equals(GamePlayState.deathSlowmo));
    });

    test(
      'PulseReflex missed plasma bolt breaches shield and triggers death',
      () {
        final controller = GameController();
        controller.updateDimensions(400.0, 800.0);
        controller.setGamePairMode(GamePairMode.pulseReflex);
        controller.startRun();
        controller.tick(Duration.zero, 4.0); // Pass grace period

        // Add a plasma bolt that has passed shield without deflection
        controller.plasmaBolts.add(
          PlasmaBolt(y: controller.shieldPing.y + 25.0, speed: 380.0),
        );
        controller.tick(Duration.zero, 0.016);

        expect(controller.state, equals(GamePlayState.deathSlowmo));
      },
    );
  });
}
