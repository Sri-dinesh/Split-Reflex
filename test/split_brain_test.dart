import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_brain/core/constants/physics_constants.dart';
import 'package:split_brain/core/services/battery_telemetry_service.dart';
import 'package:split_brain/core/services/procedural_audio_synth.dart';
import 'package:split_brain/core/utils/math_utils.dart';
import 'package:split_brain/core/utils/seeded_rng.dart';
import 'package:split_brain/engine/entities/dimension_breach_entity.dart';
import 'package:split_brain/engine/entities/obstacle_entity.dart';
import 'package:split_brain/engine/entities/particle_pool.dart';
import 'package:split_brain/engine/entities/tide_lock_entity.dart';
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
      'GamePairMode cycles properly through classic, dimensionBreach, tideLock',
      () {
        final controller = GameController();
        expect(controller.gamePairMode, equals(GamePairMode.classic));

        controller.cycleGamePairMode();
        expect(controller.gamePairMode, equals(GamePairMode.dimensionBreach));
        expect(
          controller.hemisphereState.leftMechanic,
          equals(HemisphereMechanic.breachAlpha),
        );
        expect(
          controller.hemisphereState.rightMechanic,
          equals(HemisphereMechanic.breachBeta),
        );

        controller.cycleGamePairMode();
        expect(controller.gamePairMode, equals(GamePairMode.tideLock));
        expect(
          controller.hemisphereState.leftMechanic,
          equals(HemisphereMechanic.tideSub),
        );
        expect(
          controller.hemisphereState.rightMechanic,
          equals(HemisphereMechanic.tideHarvester),
        );

        controller.cycleGamePairMode();
        expect(controller.gamePairMode, equals(GamePairMode.classic));
      },
    );

    test('DimensionBreach responds to left and right paddle steering inputs', () {
      final breach = DimensionBreachEntity();
      breach.reset(
        initialLeftX: 50.0,
        initialRightX: 350.0,
        splitX: 200.0,
        screenHeight: 800.0,
      );

      // Test bottom space touch mapping
      breach.handleLeftInput(416.0, 800.0); // Top of bottom thumb zone
      expect(breach.paddleLeftTargetY, equals(104.0)); // Top of paddle playfield

      breach.handleRightInput(764.0, 800.0); // Bottom of bottom thumb zone
      expect(breach.paddleRightTargetY, equals(696.0)); // Bottom of paddle playfield

      breach.handleLeftInput(590.0, 800.0); // Center of bottom thumb zone
      expect(breach.paddleLeftTargetY, equals(400.0)); // Center of playfield
    });

    test('Tide Lock valve raises and drains the shared water level', () {
      final tide = TideLockEntity();
      tide.reset(screenHeight: 800.0, initialLevel: 0.4);

      // Valve open: tide rises at tideRiseRate per second.
      tide.update(
        dt: 1.0,
        screenHeight: 800.0,
        subLaneLeft: 0.0,
        subLaneWidth: 200.0,
        buoyLaneLeft: 200.0,
        buoyLaneWidth: 200.0,
        subIsLeft: true,
        subActive: true,
        buoyActive: true,
        valveHeld: true,
        valveAuto: false,
        valveAutoTime: 0.0,
        inverted: false,
        spawnEnabled: false,
        allowDeaths: false,
        attractPilot: false,
        survivalTime: 0.0,
        speedScale: 1.0,
      );
      final double risen = tide.level;
      expect(risen, closeTo(0.4 + PhysicsConstants.tideRiseRate, 1e-6));
      expect(tide.valveOpen, isTrue);

      // Valve released: tide drains at tideDrainRate per second.
      tide.update(
        dt: 1.0,
        screenHeight: 800.0,
        subLaneLeft: 0.0,
        subLaneWidth: 200.0,
        buoyLaneLeft: 200.0,
        buoyLaneWidth: 200.0,
        subIsLeft: true,
        subActive: true,
        buoyActive: true,
        valveHeld: false,
        valveAuto: false,
        valveAutoTime: 0.0,
        inverted: false,
        spawnEnabled: false,
        allowDeaths: false,
        attractPilot: false,
        survivalTime: 0.0,
        speedScale: 1.0,
      );
      expect(tide.level, closeTo(risen - PhysicsConstants.tideDrainRate, 1e-6));
      expect(tide.valveOpen, isFalse);
      expect(tide.level, inInclusiveRange(0.0, 1.0));
    });

    test('Tide Lock sub is crushed when an arch overlaps its flooded depth', () {
      final tide = TideLockEntity();
      tide.reset(screenHeight: 800.0, initialLevel: 0.4);

      // Force a single arch directly on the sub's station with its lip well
      // BELOW the hull depth — the high-riding hull sits inside the slab.
      tide.arches.add(
        TideArch(
          xFactor: 0.5,
          bottomY: tide.subY + 100.0, // lip below the hull → collision
          widthFactor: 0.3,
          direction: -1.0,
        ),
      );

      final events = tide.update(
        dt: 0.016,
        screenHeight: 800.0,
        subLaneLeft: 0.0,
        subLaneWidth: 200.0,
        buoyLaneLeft: 200.0,
        buoyLaneWidth: 200.0,
        subIsLeft: true,
        subActive: true,
        buoyActive: true,
        valveHeld: false,
        valveAuto: false,
        valveAutoTime: 0.0,
        inverted: false,
        spawnEnabled: false,
        allowDeaths: true,
        attractPilot: false,
        survivalTime: 0.0,
        speedScale: 1.0,
      );

      expect(
        events.any((e) => e.type == TideEventType.subCrushed),
        isTrue,
        reason: 'Arch over a high-riding sub must crush it',
      );
      expect(tide.arches, isEmpty, reason: 'Crushing arch is consumed');
    });

    test(
      'Tide Lock buoy feeds bulbs only when the tide lifts the surface to them',
      () {
        final tide = TideLockEntity();
        tide.reset(screenHeight: 800.0, initialLevel: 0.0);

        // Force a bulb exactly where the buoy floats at the current tide.
        final TideBarnacle bulb = tide.barnacles.first;
        bulb.xFactor = 0.5;
        bulb.depthY = tide.buoyY;

        final List<TideEvent> events = tide.update(
          dt: 0.016,
          screenHeight: 800.0,
          subLaneLeft: 0.0,
          subLaneWidth: 200.0,
          buoyLaneLeft: 200.0,
          buoyLaneWidth: 200.0,
          subIsLeft: true,
          subActive: true,
          buoyActive: true,
          valveHeld: false,
          valveAuto: false,
          valveAutoTime: 0.0,
          inverted: false,
          spawnEnabled: false,
          allowDeaths: false,
          attractPilot: false,
          survivalTime: 0.0,
          speedScale: 1.0,
        );

        expect(
          events.any((e) => e.type == TideEventType.bulbFed),
          isTrue,
          reason: 'Bulb at the surface depth must feed the buoy',
        );
        // Respawned bulb must be parked away from the buoy's current tide.
        expect(
          (bulb.depthY - tide.buoyY).abs(),
          greaterThan(800.0 * PhysicsConstants.tideBulbFeedRadiusFactor),
        );
      },
    );

    test('DimensionBreachEntity updates ball physics and handles aperture breaches', () {
      final breach = DimensionBreachEntity();
      breach.reset(
        initialLeftX: 50.0,
        initialRightX: 350.0,
        splitX: 200.0,
        screenHeight: 800.0,
      );

      expect(breach.ballX, greaterThan(50.0));
      expect(breach.ballX, lessThan(200.0));
      expect(breach.ballVx, equals(220.0));

      final events = breach.update(
        dt: 0.05,
        screenWidth: 400.0,
        screenHeight: 800.0,
        splitX: 200.0,
        leftLaneLeft: 0.0,
        leftLaneRight: 200.0,
        rightLaneLeft: 200.0,
        rightLaneRight: 400.0,
        speedScale: 1.0,
        survivalTime: 1.0,
        isLeftAlive: true,
        isRightAlive: true,
        inverted: false,
      );

      expect(events, isNotNull);
      expect(breach.ballX, greaterThan(100.0));
    });

    test('DimensionBreach survives mutation swap smoothly', () {
      final controller = GameController();
      controller.updateDimensions(400.0, 800.0);
      controller.setGamePairMode(GamePairMode.dimensionBreach);
      controller.startRun();

      expect(controller.state, equals(GamePlayState.playing));
      expect(
        controller.hemisphereState.leftMechanic,
        equals(HemisphereMechanic.breachAlpha),
      );
      expect(
        controller.hemisphereState.rightMechanic,
        equals(HemisphereMechanic.breachBeta),
      );

      // Trigger mutation swap
      controller.executeMutation();
      controller.tick(Duration.zero, 0.033);

      // Verify mutation executed without failure
      expect(controller.state, equals(GamePlayState.playing));
      expect(
        controller.hemisphereState.leftMechanic,
        equals(HemisphereMechanic.breachBeta),
      );
      expect(
        controller.hemisphereState.rightMechanic,
        equals(HemisphereMechanic.breachAlpha),
      );
    });

    test('DimensionBreach routes touch to correct paddles before and after mutation swap', () {
      final controller = GameController();
      controller.updateDimensions(400.0, 800.0);
      controller.setGamePairMode(GamePairMode.dimensionBreach);
      controller.startRun();

      // Before swap:
      // Left touch in bottom space must move left paddle
      controller.handleSidePointerDown(true, const Offset(100.0, 416.0));
      expect(controller.dimensionBreach.paddleLeftTargetY, equals(104.0));
      expect(controller.dimensionBreach.paddleRightTargetY, equals(400.0));

      // Right touch in bottom space must move right paddle
      controller.handleSidePointerDown(false, const Offset(300.0, 764.0));
      expect(controller.dimensionBreach.paddleLeftTargetY, equals(104.0));
      expect(controller.dimensionBreach.paddleRightTargetY, equals(696.0));

      // Execute mutation swap (breachBeta is now on left, breachAlpha on right)
      controller.executeMutation();
      expect(
        controller.hemisphereState.leftMechanic,
        equals(HemisphereMechanic.breachBeta),
      );
      expect(
        controller.hemisphereState.rightMechanic,
        equals(HemisphereMechanic.breachAlpha),
      );

      // After swap: Left touch MUST STILL move left paddle!
      controller.handleSidePointerDown(true, const Offset(100.0, 590.0));
      expect(controller.dimensionBreach.paddleLeftTargetY, equals(400.0));
      expect(controller.dimensionBreach.paddleRightTargetY, equals(696.0));

      // Right touch MUST STILL move right paddle!
      controller.handleSidePointerDown(false, const Offset(300.0, 416.0));
      expect(controller.dimensionBreach.paddleLeftTargetY, equals(400.0));
      expect(controller.dimensionBreach.paddleRightTargetY, equals(104.0));

      // Also verify drag movements in bottom space
      controller.handleSidePointerMove(true, 0.0, const Offset(100.0, 764.0));
      expect(controller.dimensionBreach.paddleLeftTargetY, equals(696.0));
      controller.handleSidePointerMove(false, 0.0, const Offset(300.0, 590.0));
      expect(controller.dimensionBreach.paddleRightTargetY, equals(400.0));
    });

    test('DimensionBreach gravity physics reverses accurately on polarity inversion and swap', () {
      final breach = DimensionBreachEntity();

      // 1. Normal (Alpha on Left, Not Inverted):
      // Left realm pulls UPWARD (vy decreases), Right realm pulls DOWNWARD (vy increases)
      breach.reset(initialLeftX: 50.0, initialRightX: 350.0, splitX: 200.0, screenHeight: 800.0);
      breach.ballX = 100.0; // Left side
      breach.ballVy = 0.0;
      breach.update(
        dt: 0.1,
        screenWidth: 400.0,
        screenHeight: 800.0,
        splitX: 200.0,
        leftLaneLeft: 0.0,
        leftLaneRight: 200.0,
        rightLaneLeft: 200.0,
        rightLaneRight: 400.0,
        speedScale: 1.0,
        survivalTime: 5.0,
        isLeftAlive: true,
        isRightAlive: true,
        inverted: false,
        isLeftAlpha: true,
      );
      expect(breach.ballVy, lessThan(0.0), reason: 'Left Alpha should pull upward (negative vy)');

      // 2. Polarity Inverted (Alpha on Left, Inverted = true):
      // Left realm pulls DOWNWARD (vy increases)
      breach.reset(initialLeftX: 50.0, initialRightX: 350.0, splitX: 200.0, screenHeight: 800.0);
      breach.ballX = 100.0; // Left side
      breach.ballVy = 0.0;
      breach.update(
        dt: 0.1,
        screenWidth: 400.0,
        screenHeight: 800.0,
        splitX: 200.0,
        leftLaneLeft: 0.0,
        leftLaneRight: 200.0,
        rightLaneLeft: 200.0,
        rightLaneRight: 400.0,
        speedScale: 1.0,
        survivalTime: 5.0,
        isLeftAlive: true,
        isRightAlive: true,
        inverted: true,
        isLeftAlpha: true,
      );
      expect(breach.ballVy, greaterThan(0.0), reason: 'Left Alpha when inverted should pull downward (positive vy)');

      // 3. Mutation Swapped (Beta on Left, Not Inverted):
      // Left realm (Beta) pulls DOWNWARD (vy increases)
      breach.reset(initialLeftX: 50.0, initialRightX: 350.0, splitX: 200.0, screenHeight: 800.0);
      breach.ballX = 100.0; // Left side
      breach.ballVy = 0.0;
      breach.update(
        dt: 0.1,
        screenWidth: 400.0,
        screenHeight: 800.0,
        splitX: 200.0,
        leftLaneLeft: 0.0,
        leftLaneRight: 200.0,
        rightLaneLeft: 200.0,
        rightLaneRight: 400.0,
        speedScale: 1.0,
        survivalTime: 5.0,
        isLeftAlive: true,
        isRightAlive: true,
        inverted: false,
        isLeftAlpha: false,
      );
      expect(breach.ballVy, greaterThan(0.0), reason: 'Left Beta should pull downward (positive vy)');
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
      'TideLock arch collision during a run triggers hemisphere death',
      () {
        final controller = GameController();
        controller.updateDimensions(400.0, 800.0);
        controller.setGamePairMode(GamePairMode.tideLock);
        controller.startRun();
        controller.tick(Duration.zero, 4.0); // Pass grace period

        // Force an arch straddling the sub's station with its lip below the
        // hull — the high-riding hull cannot clear it.
        final TideArch killerArch = TideArch(
          xFactor: 0.5,
          bottomY: controller.tideLock.subY + 100.0,
          widthFactor: 0.3,
          direction: -1.0,
        );
        controller.tideLock.arches.add(killerArch);
        controller.tick(Duration.zero, 0.016);

        expect(controller.state, equals(GamePlayState.deathSlowmo));
        expect(
          controller.latestAutopsy?.failedMechanic,
          equals('TIDE SUB'),
        );
      },
    );

    test(
      'TideLock urchin contact during a run triggers buoy death',
      () {
        final controller = GameController();
        controller.updateDimensions(400.0, 800.0);
        controller.setGamePairMode(GamePairMode.tideLock);
        controller.startRun();
        controller.tick(Duration.zero, 4.0); // Pass grace period

        // Park an urchin directly under the buoy.
        controller.tideLock.urchins.add(
          TideUrchin(
            xFactor: controller.tideLock.buoyXFactor,
            y: controller.tideLock.buoyY,
            vxFactor: 0.0,
            radius: 10.0,
            spinPhase: 0.0,
          ),
        );
        controller.tick(Duration.zero, 0.016);

        expect(controller.state, equals(GamePlayState.deathSlowmo));
        expect(
          controller.latestAutopsy?.failedMechanic,
          equals('TIDE HARVESTER'),
        );
      },
    );

    test(
      'Tide Lock full-run smoke: valve drain, arch clears, 15s mutation swap',
      () {
        final controller = GameController();
        controller.updateDimensions(400.0, 800.0);
        controller.setGamePairMode(GamePairMode.tideLock);
        controller.startRun();

        // Scripted survival run:
        //  - Valve never opens → tide drains to the basin floor, the sub sits
        //    safely below every arch lip and all arches score on pass.
        //  - The buoy actively dodges urchins flirting with the low surface
        //    (it is ~4x faster than them, exactly as playable in real hands).
        for (int i = 0; i < 940; i++) {
          // ~15s @ 16ms
          final TideLockEntity tide = controller.tideLock;

          // 1-Hemisphere escape law: keep one side of the urchin clear.
          double target = 0.5;
          for (final TideUrchin u in tide.urchins) {
            if ((u.y - tide.buoyY).abs() < 60.0) {
              // Head away from the urchin's projected x.
              target = u.xFactor > tide.buoyXFactor
                  ? PhysicsConstants.tideBuoyMinXFactor
                  : 1.0 - PhysicsConstants.tideBuoyMinXFactor;
            }
          }
          tide.setBuoyTargetXFactor(target);

          controller.tick(
            Duration.zero,
            0.016.clamp(0.001, PhysicsConstants.maxDeltaTime),
          );
        }
        final double scoreBeforeSwap = controller.currentScore;
        expect(scoreBeforeSwap, greaterThan(1000.0));

        // Mutation executed at 15s: hemispheres trade mechanics.
        expect(controller.survivalTime, greaterThanOrEqualTo(15.0));
        expect(
          controller.hemisphereState.leftMechanic,
          equals(HemisphereMechanic.tideHarvester),
        );
        expect(
          controller.hemisphereState.rightMechanic,
          equals(HemisphereMechanic.tideSub),
        );

        // Continue another 5s in the swapped configuration.
        for (int i = 0; i < 310; i++) {
          final TideLockEntity tide = controller.tideLock;
          double target = 0.5;
          for (final TideUrchin u in tide.urchins) {
            if ((u.y - tide.buoyY).abs() < 60.0) {
              target = u.xFactor > tide.buoyXFactor
                  ? PhysicsConstants.tideBuoyMinXFactor
                  : 1.0 - PhysicsConstants.tideBuoyMinXFactor;
            }
          }
          tide.setBuoyTargetXFactor(target);
          controller.tick(
            Duration.zero,
            0.016.clamp(0.001, PhysicsConstants.maxDeltaTime),
          );
        }
        expect(controller.currentScore, greaterThan(scoreBeforeSwap));
        expect(controller.tideLock.level, inInclusiveRange(0.0, 1.0));
        expect(controller.state, equals(GamePlayState.playing));
      },
    );

    test(
      'Tide Lock 1-Hand: sub death leaves an autonomous tide for the buoy',
      () {
        final controller = GameController();
        controller.updateDimensions(400.0, 800.0);
        controller.setGamePairMode(GamePairMode.tideLock);
        controller.setPlayMode(PlayHandMode.oneHand);
        controller.startRun();
        controller.tick(Duration.zero, 4.0); // Pass grace period

        // Sink the sub with a forced arch.
        controller.tideLock.arches.add(
          TideArch(
            xFactor: 0.5,
            bottomY: controller.tideLock.subY + 100.0,
            widthFactor: 0.3,
            direction: -1.0,
          ),
        );
        controller.tick(Duration.zero, 0.016);

        expect(controller.orbAlive, isFalse);
        expect(controller.dartAlive, isTrue);
        expect(controller.state, equals(GamePlayState.playing));

        // The buoy keeps playing under an autonomous tide for 10 more seconds.
        for (int i = 0; i < 625; i++) {
          controller.tick(Duration.zero, 0.016);
          if (controller.state != GamePlayState.playing) break;
        }

        // Either the buoy is still alive under the auto tide, or it was
        // legitimately stung — but the engine must never stall.
        expect(controller.tideLock.level, inInclusiveRange(0.0, 1.0));
        expect(
          controller.state,
          isIn([
            GamePlayState.playing,
            GamePlayState.deathSlowmo,
            GamePlayState.deathReceipt,
          ]),
        );
      },
    );

    test('DimensionBreach disables 1-Hand mode and strictly enforces 2-Hands', () {
      final controller = GameController();
      controller.updateDimensions(400.0, 800.0);
      controller.setGamePairMode(GamePairMode.dimensionBreach);

      // Verify that toggling or setting 1-hand mode is prevented in Dimension Breach
      expect(controller.playMode, equals(PlayHandMode.twoHands));
      controller.togglePlayMode();
      expect(controller.playMode, equals(PlayHandMode.twoHands));
      controller.setPlayMode(PlayHandMode.oneHand);
      expect(controller.playMode, equals(PlayHandMode.twoHands));

      // If another mode was in 1-hand, switching to dimension breach resets to 2-hands
      controller.setGamePairMode(GamePairMode.classic);
      controller.setPlayMode(PlayHandMode.oneHand);
      expect(controller.playMode, equals(PlayHandMode.oneHand));

      controller.setGamePairMode(GamePairMode.dimensionBreach);
      expect(controller.playMode, equals(PlayHandMode.twoHands));

      // Starting run ensures 2-hands
      controller.startRun();
      expect(controller.playMode, equals(PlayHandMode.twoHands));
    });
  });
}
