import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import '../../core/constants/palette.dart';
import '../core/constants/physics_constants.dart';
import '../core/services/battery_telemetry_service.dart';
import '../core/services/haptic_choreographer.dart';
import '../core/services/leaderboard_service.dart';
import '../core/services/procedural_audio_synth.dart';
import '../core/utils/seeded_rng.dart';
import 'entities/dart_entity.dart';
import 'entities/obstacle_entity.dart';
import 'entities/orb_entity.dart';
import 'entities/particle_pool.dart';
import 'entities/phase_flux_entity.dart';
import 'entities/slalom_drift_entity.dart';
import 'entities/shield_ping_entity.dart';
import 'entities/quantum_warp_entity.dart';
import 'hemisphere_state.dart';
import 'input_router.dart';

enum GamePlayState {
  attract,
  countdown,
  playing,
  deathSlowmo,
  deathReceipt,
}

class DeathAutopsy {
  final double survivalTime;
  final int finalScore;
  final String failedHemisphere; // 'LEFT' or 'RIGHT'
  final String failedMechanic;   // 'ORB' or 'DART'
  final double timePostLastMutation;
  final int batteryPct;
  final bool wasOverdrive;
  final double scoreMultiplier;
  final List<double> leftActivity;
  final List<double> rightActivity;
  final PlayHandMode playMode;
  final GameSessionMode sessionMode;
  final String responsibleParty; // 'SOLO', 'PLAYER 1 (LEFT)', or 'PLAYER 2 (RIGHT)'

  DeathAutopsy({
    required this.survivalTime,
    required this.finalScore,
    required this.failedHemisphere,
    required this.failedMechanic,
    required this.timePostLastMutation,
    required this.batteryPct,
    required this.wasOverdrive,
    required this.scoreMultiplier,
    required this.leftActivity,
    required this.rightActivity,
    required this.playMode,
    required this.sessionMode,
    required this.responsibleParty,
  });
}

enum GamePairMode {
  classic,     // Left: Orb (Thrust) | Right: Dart (Steer)
  phaseFlux,   // Left: Phase Core (Flip Polarity) | Right: Slalom (Drift)
  pulseReflex, // Left: Shield (Ping Deflect) | Right: Quantum (Warp Rails)
}

enum PlayHandMode {
  twoHands, // Strict mode: if either side fails, game over
  oneHand,  // Casual/survival mode: if one side fails, the other keeps playing
}

enum GameSessionMode {
  solo,     // 1 Player: Dual-hemisphere self challenge
  duoCoop,  // 2 Players: 1 phone, P1 Left vs P2 Right, swap hands on mutation
}

enum ControlMode {
  touchSwipe, // Standard touch & drag
  gyroTilt,   // Physical phone tilting steers Dart or Slalom!
}

enum CyberTheme {
  monochrome, // High-contrast Cyber Core (default)
  synthwave,  // 1984 Retro Neon Magenta & Cyan
  matrix,     // Emerald Terminal Scanlines
  cyberGold,  // Luxury 24K Gold & Obsidian
}

class GameController extends ChangeNotifier {
  GamePlayState state = GamePlayState.attract;
  GamePairMode gamePairMode = GamePairMode.classic;
  PlayHandMode playMode = PlayHandMode.twoHands;
  GameSessionMode sessionMode = GameSessionMode.solo;
  ControlMode controlMode = ControlMode.touchSwipe;
  CyberTheme theme = CyberTheme.monochrome;

  // High-frequency responsive gyroscope tilt state
  double _rawGyroTiltX = 0.0;
  double _filteredGyroTiltX = 0.0;
  bool isGyroAvailable = false;

  void updateRawTilt(double tilt) {
    _rawGyroTiltX = tilt;
    isGyroAvailable = true;
  }

  // Single-hand survival states
  bool orbAlive = true;
  bool dartAlive = true;

  // Viewport dimensions
  double screenWidth = 390.0;
  double screenHeight = 844.0;

  // Subsystems & Entities
  final HemisphereState hemisphereState = HemisphereState();
  final InputRouter inputRouter = InputRouter();

  // Pair 1: Classic
  final OrbEntity orb = OrbEntity();
  final DartEntity dart = DartEntity();
  final List<LaserGate> laserGates = [];
  final List<Monolith> monoliths = [];

  // Pair 2: Phase Flux
  final PhaseCoreEntity phaseCore = PhaseCoreEntity();
  final SlalomDriftEntity slalomDrift = SlalomDriftEntity();
  final List<PolarityWall> polarityWalls = [];
  final List<SlalomPylon> slalomPylons = [];

  // Pair 3: Pulse Reflex
  final ShieldPingEntity shieldPing = ShieldPingEntity();
  final QuantumWarpEntity quantumWarp = QuantumWarpEntity();
  final List<PlasmaBolt> plasmaBolts = [];
  final List<QuantumBlockade> quantumBlockades = [];

  final ParticlePool particlePool = ParticlePool();
  final SeededRng rng = SeededRng();

  // Spawners
  double _laserSpawnTimer = -3.0; // 3.0s startup grace period for all game modes
  double _monolithSpawnTimer = -3.0;
  double _postSwapGraceTimer = 0.0;
  double _rollingSafeCorridorX = 0.0;
  double _attractAnimTime = 0.0;

  bool isMechanicAlive(HemisphereMechanic mechanic) {
    switch (mechanic) {
      case HemisphereMechanic.orb:
      case HemisphereMechanic.phaseCore:
      case HemisphereMechanic.shieldPing:
        return orbAlive;
      case HemisphereMechanic.dart:
      case HemisphereMechanic.slalomDrift:
      case HemisphereMechanic.quantumWarp:
        return dartAlive;
    }
  }

  // Gameplay Run Metrics
  double survivalTime = 0.0;
  double currentScore = 0.0;
  int nearMissCount = 0;
  double phaseMultiplier = 1.0;
  double lastMutationTimestamp = 0.0;

  // Battery status cached for rendering
  BatteryTelemetryState batteryState = const BatteryTelemetryState(
    batteryLevel: 100,
    batteryState: BatteryState.discharging,
    tier: OverdriveTier.standard,
    scoreMultiplier: 1.0,
  );

  // Biometric Hold-to-Start
  double holdProgress = 0.0;
  static const double holdDuration = 0.8; // 800ms

  // Countdown State
  double countdownTimer = 3.0;
  int _lastCountdownSecond = 3;
  double _orbHoldTimer = 0.0;

  // Death Slow-Mo & Freeze
  double deathSlowmoTimer = 0.0;
  double deathZoom = 1.0;
  Offset deathFocusPoint = Offset.zero;
  DeathAutopsy? latestAutopsy;

  // Camera Shake
  Offset cameraShake = Offset.zero;
  double _shakeIntensity = 0.0;

  void updateDimensions(double width, double height) {
    if (width <= 0 || height <= 0) return;
    if (screenWidth == width && screenHeight == height) return;
    screenWidth = width;
    screenHeight = height;
    if (state == GamePlayState.attract) {
      _initAttractMode();
    }
  }

  void setPlayMode(PlayHandMode mode) {
    playMode = mode;
    notifyListeners();
  }

  void togglePlayMode() {
    playMode = playMode == PlayHandMode.twoHands ? PlayHandMode.oneHand : PlayHandMode.twoHands;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setSessionMode(GameSessionMode mode) {
    sessionMode = mode;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void toggleSessionMode() {
    sessionMode = sessionMode == GameSessionMode.solo ? GameSessionMode.duoCoop : GameSessionMode.solo;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setControlMode(ControlMode mode) {
    controlMode = mode;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void toggleControlMode() {
    controlMode = controlMode == ControlMode.touchSwipe ? ControlMode.gyroTilt : ControlMode.touchSwipe;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setTheme(CyberTheme newTheme) {
    theme = newTheme;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void cycleTheme() {
    final values = CyberTheme.values;
    final nextIndex = (values.indexOf(theme) + 1) % values.length;
    theme = values[nextIndex];
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setGamePairMode(GamePairMode mode) {
    gamePairMode = mode;
    _initAttractMode();
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void cycleGamePairMode() {
    final values = GamePairMode.values;
    final nextIndex = (values.indexOf(gamePairMode) + 1) % values.length;
    gamePairMode = values[nextIndex];
    _initAttractMode();
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void _initAttractMode() {
    survivalTime = 0.0;
    currentScore = 0.0;
    orbAlive = true;
    dartAlive = true;

    // Set initial mechanics based on active pair
    HemisphereMechanic leftMech;
    HemisphereMechanic rightMech;
    switch (gamePairMode) {
      case GamePairMode.classic:
        leftMech = HemisphereMechanic.orb;
        rightMech = HemisphereMechanic.dart;
        break;
      case GamePairMode.phaseFlux:
        leftMech = HemisphereMechanic.phaseCore;
        rightMech = HemisphereMechanic.slalomDrift;
        break;
      case GamePairMode.pulseReflex:
        leftMech = HemisphereMechanic.shieldPing;
        rightMech = HemisphereMechanic.quantumWarp;
        break;
    }

    hemisphereState.reset(screenWidth, initialLeft: leftMech, initialRight: rightMech);
    inputRouter.resetActivity();
    particlePool.clear();

    // 3.5 second startup runway grace period across all modes: 0 obstacles spawn on start
    _laserSpawnTimer = -3.5;
    _monolithSpawnTimer = -3.5;
    _postSwapGraceTimer = 0.0;

    // Clear obstacles
    laserGates.clear();
    monoliths.clear();
    polarityWalls.clear();
    slalomPylons.clear();
    plasmaBolts.clear();
    quantumBlockades.clear();

    final double leftLaneLeft = hemisphereState.getLaneLeft(leftMech, screenWidth);
    final double leftLaneRight = hemisphereState.getLaneRight(leftMech, screenWidth);
    final double rightLaneLeft = hemisphereState.getLaneLeft(rightMech, screenWidth);
    final double rightLaneRight = hemisphereState.getLaneRight(rightMech, screenWidth);

    // Init Pair 1
    orb.reset(
      initialX: (leftLaneLeft + leftLaneRight) / 2.0,
      initialY: screenHeight * 0.5,
    );
    dart.reset(
      initialX: (rightLaneLeft + rightLaneRight) / 2.0,
      initialRailY: screenHeight * PhysicsConstants.dartDefaultRailYFactor,
    );
    _rollingSafeCorridorX = dart.x;

    // Init Pair 2
    phaseCore.reset(
      initialX: (leftLaneLeft + leftLaneRight) / 2.0,
      initialY: screenHeight * 0.65,
    );
    slalomDrift.reset(
      initialX: (rightLaneLeft + rightLaneRight) / 2.0,
      initialY: screenHeight * 0.70,
    );

    // Init Pair 3
    shieldPing.reset(baselineY: screenHeight * 0.72);
    quantumWarp.reset(
      railY: screenHeight * 0.72,
      trackLeftX: rightLaneLeft + (rightLaneRight - rightLaneLeft) * 0.30,
    );
  }

  void returnToMenu() {
    state = GamePlayState.attract;
    survivalTime = 0.0;
    currentScore = 0.0;
    holdProgress = 0.0;
    latestAutopsy = null;
    deathSlowmoTimer = 0.0;
    deathZoom = 1.0;
    _initAttractMode();
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void triggerStartCountdown() {
    state = GamePlayState.countdown;
    countdownTimer = 3.0;
    _lastCountdownSecond = 3;
    holdProgress = 0.0;
    _initAttractMode();
    ProceduralAudioSynth.instance.playSwapTick(isFinal: false);
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void startRun() {
    state = GamePlayState.playing;
    survivalTime = 0.0;
    currentScore = 0.0;
    nearMissCount = 0;
    phaseMultiplier = 1.0;
    lastMutationTimestamp = 0.0;
    deathSlowmoTimer = 0.0;
    deathZoom = 1.0;
    latestAutopsy = null;
    holdProgress = 0.0;

    _initAttractMode();
    HapticChoreographer.instance.triggerSwapExecute();
    ProceduralAudioSynth.instance.playSwapExecute();
    notifyListeners();
  }

  void tick(Duration elapsed, double rawDt) {
    // Delta-time clamping (max 33ms to avoid tunneling during OS stutters)
    final double dt = rawDt.clamp(0.001, PhysicsConstants.maxDeltaTime);

    // Camera shake decay
    if (_shakeIntensity > 0.0) {
      _shakeIntensity = math.max(0.0, _shakeIntensity - dt * 25.0);
      final double angle = rng.nextDouble() * math.pi * 2;
      cameraShake = Offset(math.cos(angle) * _shakeIntensity, math.sin(angle) * _shakeIntensity);
    } else {
      cameraShake = Offset.zero;
    }

    if (state == GamePlayState.attract) {
      _tickAttract(dt);
      notifyListeners();
      return;
    }

    if (state == GamePlayState.countdown) {
      _tickCountdown(dt);
      notifyListeners();
      return;
    }

    if (state == GamePlayState.deathSlowmo) {
      _tickDeathSlowmo(dt);
      notifyListeners();
      return;
    }

    if (state == GamePlayState.deathReceipt) {
      // Passive floating particles
      particlePool.update(dt);
      notifyListeners();
      return;
    }

    // --- ACTIVE PLAYING STATE ---
    survivalTime += dt;
    if (_postSwapGraceTimer > 0.0) {
      _postSwapGraceTimer = math.max(0.0, _postSwapGraceTimer - dt);
    }
    inputRouter.updateActivityTimer(dt);

    // Calculate phase multiplier (+0.25 every 15s mutation)
    final int mutationIndex = (survivalTime / PhysicsConstants.mutationInterval).floor();
    phaseMultiplier = 1.0 + mutationIndex * 0.25;

    // Accumulate score
    final double effectiveBatteryMult = batteryState.scoreMultiplier;
    currentScore += dt * PhysicsConstants.basePointsPerSecond * phaseMultiplier * effectiveBatteryMult;

    // Check for 15s mutation / swap execution
    final double currentInterval = survivalTime < 60.0 ? 15.0 : 10.0;
    if (survivalTime - lastMutationTimestamp >= currentInterval) {
      lastMutationTimestamp = survivalTime;
      // In 1-hand survival mode, keep surviving lane stable once one side has fallen
      if (playMode == PlayHandMode.twoHands || (orbAlive && dartAlive)) {
        executeMutation();
      }
    }

    // Update hemisphere mutation state machine
    hemisphereState.update(
      dt: dt,
      survivalTime: survivalTime,
      screenWidth: screenWidth,
      isOverdrive: batteryState.isOverdrive,
      isGodMode: batteryState.isGodMode,
      themeName: theme.name,
      onSwapWarningTick: (seconds) {
        ProceduralAudioSynth.instance.playSwapTick(isFinal: seconds == 1);
        HapticChoreographer.instance.triggerSwapTick();
        _addCameraShake(3.5);
      },
      onSwapExecuted: () {
        ProceduralAudioSynth.instance.playSwapExecute();
        HapticChoreographer.instance.triggerSwapExecute();
        _addCameraShake(7.0);
      },
    );

    // Update entities according to active game pair
    if (gamePairMode == GamePairMode.classic) {
      final double orbLeft = hemisphereState.getLaneLeft(HemisphereMechanic.orb, screenWidth);
      final double orbRight = hemisphereState.getLaneRight(HemisphereMechanic.orb, screenWidth);
      final double gravity = hemisphereState.isPolarityInverted
          ? -PhysicsConstants.orbDefaultGravity
          : PhysicsConstants.orbDefaultGravity;

      final bool orbIsLeft = hemisphereState.leftMechanic == HemisphereMechanic.orb;
      final bool orbHeld = orbIsLeft ? inputRouter.leftThumbHeld : inputRouter.rightThumbHeld;
      if (orbAlive && orbHeld) {
        _orbHoldTimer += dt;
        if (_orbHoldTimer >= 0.12) {
          _orbHoldTimer = 0.0;
          orb.thrust(inverted: hemisphereState.isPolarityInverted);
          ProceduralAudioSynth.instance.playTap();
          HapticChoreographer.instance.triggerTap();
          particlePool.spawnBurst(
            origin: Offset(orb.x, orb.y),
            count: 3,
            color: (orbIsLeft ? hemisphereState.leftFg : hemisphereState.rightFg).withOpacity(0.6),
            speed: 60.0,
          );
        }
      } else {
        _orbHoldTimer = 0.0;
      }

      if (orbAlive) {
        orb.update(
          dt: dt,
          laneLeft: orbLeft,
          laneRight: orbRight,
          gravity: gravity,
          inverted: hemisphereState.isPolarityInverted,
        );
      }

      final double dartLeft = hemisphereState.getLaneLeft(HemisphereMechanic.dart, screenWidth);
      final double dartRight = hemisphereState.getLaneRight(HemisphereMechanic.dart, screenWidth);
      if (dartAlive) {
        if (controlMode == ControlMode.gyroTilt) {
          final double alpha = 1.0 - math.exp(-26.0 * dt);
          _filteredGyroTiltX = ui.lerpDouble(_filteredGyroTiltX, _rawGyroTiltX, alpha) ?? _rawGyroTiltX;
          const double tiltRange = 3.0;
          final double normalized = (_filteredGyroTiltX / tiltRange).clamp(-1.0, 1.0);
          final double curved = normalized.sign * math.pow(normalized.abs(), 1.1);
          final double laneCenter = (dartLeft + dartRight) / 2.0;
          final double maxTravel = (dartRight - dartLeft) / 2.0 - 18.0;
          dart.targetX = (laneCenter + curved * maxTravel).clamp(dartLeft + 16.0, dartRight - 16.0);
        }

        dart.update(
          dt: dt,
          laneLeft: dartLeft,
          laneRight: dartRight,
          screenHeight: screenHeight,
          inverted: hemisphereState.isPolarityInverted,
          isGyro: controlMode == ControlMode.gyroTilt,
        );

        particlePool.spawnDartThruster(
          origin: Offset(dart.x, dart.railY + (hemisphereState.isPolarityInverted ? -12.0 : 12.0)),
          color: hemisphereState.rightFg.withOpacity(0.7),
          inverted: hemisphereState.isPolarityInverted,
        );
      }
    } else if (gamePairMode == GamePairMode.phaseFlux) {
      // Pair 2: Phase Core & Slalom Drift
      final double pLeft = hemisphereState.getLaneLeft(HemisphereMechanic.phaseCore, screenWidth);
      final double pRight = hemisphereState.getLaneRight(HemisphereMechanic.phaseCore, screenWidth);
      if (orbAlive) {
        phaseCore.update(dt, (pLeft + pRight) / 2.0, screenHeight * 0.65);
      }

      final double sLeft = hemisphereState.getLaneLeft(HemisphereMechanic.slalomDrift, screenWidth);
      final double sRight = hemisphereState.getLaneRight(HemisphereMechanic.slalomDrift, screenWidth);
      if (dartAlive) {
        if (controlMode == ControlMode.gyroTilt) {
          final double alpha = 1.0 - math.exp(-26.0 * dt);
          _filteredGyroTiltX = ui.lerpDouble(_filteredGyroTiltX, _rawGyroTiltX, alpha) ?? _rawGyroTiltX;
          const double tiltRange = 3.0;
          final double normalized = (_filteredGyroTiltX / tiltRange).clamp(-1.0, 1.0);
          final double midX = (sLeft + sRight) / 2.0;
          final double halfW = (sRight - sLeft) / 2.0 - 16.0;
          slalomDrift.targetX = (midX + normalized * halfW).clamp(sLeft + 16.0, sRight - 16.0);
        }

        slalomDrift.update(
          dt: dt,
          laneLeft: sLeft,
          laneRight: sRight,
          screenHeight: screenHeight,
          isGyro: controlMode == ControlMode.gyroTilt,
        );
      }
    } else if (gamePairMode == GamePairMode.pulseReflex) {
      // Pair 3: Shield Ping & Quantum Warp
      if (orbAlive) {
        shieldPing.update(dt);
      }

      final double qLeft = hemisphereState.getLaneLeft(HemisphereMechanic.quantumWarp, screenWidth);
      final double qRight = hemisphereState.getLaneRight(HemisphereMechanic.quantumWarp, screenWidth);
      if (dartAlive) {
        final double trackLeftX = qLeft + (qRight - qLeft) * 0.30;
        final double trackRightX = qLeft + (qRight - qLeft) * 0.70;
        quantumWarp.update(dt, trackLeftX, trackRightX);
      }
    }

    // Update Obstacles & Spawning
    _updateObstacleSpawners(dt);

    // Particle pool update
    particlePool.update(dt);

    // Collision Detection
    _checkCollisions();

    notifyListeners();
  }

  void _tickAttract(double dt) {
    // In attract mode: simulate calm floating orb and hovering dart
    _attractAnimTime += dt;

    if (gamePairMode == GamePairMode.classic) {
      final double orbLeft = hemisphereState.getLaneLeft(HemisphereMechanic.orb, screenWidth);
      final double orbRight = hemisphereState.getLaneRight(HemisphereMechanic.orb, screenWidth);
      // Gentle floating based on attract anim timer — survivalTime stays strictly 0.0 until run starts!
      orb.y = screenHeight * 0.5 + 40.0 * math.sin(_attractAnimTime * 2.5);
      orb.x = ((orbLeft + orbRight) / 2.0) + 30.0 * math.cos(_attractAnimTime * 1.5);

      final double dartLeft = hemisphereState.getLaneLeft(HemisphereMechanic.dart, screenWidth);
      final double dartRight = hemisphereState.getLaneRight(HemisphereMechanic.dart, screenWidth);
      dart.x = ((dartLeft + dartRight) / 2.0) + 40.0 * math.sin(_attractAnimTime * 1.8);
      dart.railY = screenHeight * PhysicsConstants.dartDefaultRailYFactor;
    } else if (gamePairMode == GamePairMode.phaseFlux) {
      final double coreLeft = hemisphereState.getLaneLeft(HemisphereMechanic.phaseCore, screenWidth);
      final double coreRight = hemisphereState.getLaneRight(HemisphereMechanic.phaseCore, screenWidth);
      final double coreMid = (coreLeft + coreRight) / 2.0;
      phaseCore.update(dt, coreMid, screenHeight * 0.70);

      final double slalomLeft = hemisphereState.getLaneLeft(HemisphereMechanic.slalomDrift, screenWidth);
      final double slalomRight = hemisphereState.getLaneRight(HemisphereMechanic.slalomDrift, screenWidth);
      final double slalomMid = (slalomLeft + slalomRight) / 2.0;
      slalomDrift.targetX = slalomMid + 25.0 * math.sin(_attractAnimTime * 2.0);
      slalomDrift.update(
        dt: dt,
        laneLeft: slalomLeft,
        laneRight: slalomRight,
        screenHeight: screenHeight,
        isGyro: false,
      );
    } else if (gamePairMode == GamePairMode.pulseReflex) {
      shieldPing.y = screenHeight * 0.75;
      shieldPing.update(dt);

      final double qLeft = hemisphereState.getLaneLeft(HemisphereMechanic.quantumWarp, screenWidth);
      final double qRight = hemisphereState.getLaneRight(HemisphereMechanic.quantumWarp, screenWidth);
      final double trackLeftX = qLeft + (qRight - qLeft) * 0.30;
      final double trackRightX = qLeft + (qRight - qLeft) * 0.70;
      quantumWarp.y = screenHeight * 0.75;
      quantumWarp.update(dt, trackLeftX, trackRightX);
    }

    particlePool.update(dt);

    // Biometric Dual-Thumb Hold-to-Start check
    if (inputRouter.leftThumbHeld && inputRouter.rightThumbHeld) {
      if (holdProgress == 0.0) {
        ProceduralAudioSynth.instance.playChargeHum();
      }
      final double prevProgress = holdProgress;
      holdProgress += dt / holdDuration;

      // Trigger haptic milestone pulses at 25%, 50%, 75%, 100%
      if ((prevProgress < 0.25 && holdProgress >= 0.25) ||
          (prevProgress < 0.50 && holdProgress >= 0.50) ||
          (prevProgress < 0.75 && holdProgress >= 0.75) ||
          (prevProgress < 1.00 && holdProgress >= 1.00)) {
        HapticChoreographer.instance.triggerTap();
      }

      if (holdProgress >= 1.0) {
        triggerStartCountdown();
      }
    } else {
      holdProgress = math.max(0.0, holdProgress - dt * 2.0);
    }
  }

  void _tickCountdown(double dt) {
    countdownTimer -= dt;
    final int currentSecond = countdownTimer.ceil();
    if (currentSecond != _lastCountdownSecond && currentSecond > 0) {
      _lastCountdownSecond = currentSecond;
      ProceduralAudioSynth.instance.playSwapTick(isFinal: currentSecond == 1);
      HapticChoreographer.instance.triggerTap();
    }

    if (gamePairMode == GamePairMode.classic) {
      final double orbLeft = hemisphereState.getLaneLeft(HemisphereMechanic.orb, screenWidth);
      final double orbRight = hemisphereState.getLaneRight(HemisphereMechanic.orb, screenWidth);
      orb.y = screenHeight * 0.5 + 15.0 * math.sin(countdownTimer * 4.0);
      orb.x = (orbLeft + orbRight) / 2.0;

      final double dartLeft = hemisphereState.getLaneLeft(HemisphereMechanic.dart, screenWidth);
      final double dartRight = hemisphereState.getLaneRight(HemisphereMechanic.dart, screenWidth);
      dart.x = (dartLeft + dartRight) / 2.0;
      dart.railY = screenHeight * PhysicsConstants.dartDefaultRailYFactor;
    } else if (gamePairMode == GamePairMode.phaseFlux) {
      final double coreLeft = hemisphereState.getLaneLeft(HemisphereMechanic.phaseCore, screenWidth);
      final double coreRight = hemisphereState.getLaneRight(HemisphereMechanic.phaseCore, screenWidth);
      phaseCore.update(dt, (coreLeft + coreRight) / 2.0, screenHeight * 0.70);

      final double slalomLeft = hemisphereState.getLaneLeft(HemisphereMechanic.slalomDrift, screenWidth);
      final double slalomRight = hemisphereState.getLaneRight(HemisphereMechanic.slalomDrift, screenWidth);
      slalomDrift.targetX = (slalomLeft + slalomRight) / 2.0;
      slalomDrift.update(
        dt: dt,
        laneLeft: slalomLeft,
        laneRight: slalomRight,
        screenHeight: screenHeight,
        isGyro: false,
      );
    } else if (gamePairMode == GamePairMode.pulseReflex) {
      shieldPing.y = screenHeight * 0.75;
      shieldPing.update(dt);

      final double qLeft = hemisphereState.getLaneLeft(HemisphereMechanic.quantumWarp, screenWidth);
      final double qRight = hemisphereState.getLaneRight(HemisphereMechanic.quantumWarp, screenWidth);
      final double trackLeftX = qLeft + (qRight - qLeft) * 0.30;
      final double trackRightX = qLeft + (qRight - qLeft) * 0.70;
      quantumWarp.y = screenHeight * 0.75;
      quantumWarp.update(dt, trackLeftX, trackRightX);
    }

    particlePool.update(dt);

    if (countdownTimer <= 0.0) {
      startRun();
    }
  }

  void _tickDeathSlowmo(double dt) {
    deathSlowmoTimer -= dt;
    particlePool.update(dt * 0.1); // Slow particles during slow-mo

    // Camera zoom toward failure point
    deathZoom = 1.0 + (1.08 - 1.0) * (1.0 - (deathSlowmoTimer / 0.2).clamp(0.0, 1.0));

    if (deathSlowmoTimer <= 0.0) {
      state = GamePlayState.deathReceipt;
      deathZoom = 1.0;
    }
  }

  void executeMutation() {
    hemisphereState.executeSwap(
      isOverdrive: batteryState.isOverdrive,
      isGodMode: batteryState.isGodMode,
      themeName: theme.name,
    );

    // 1.2 second grace period post-mutation so player can orient without instant collision
    _postSwapGraceTimer = 1.2;
    _laserSpawnTimer = -1.5;
    _monolithSpawnTimer = -1.5;

    // Clear active obstacles on swap to prevent unfair instant collisions across all modes
    laserGates.clear();
    monoliths.clear();
    polarityWalls.clear();
    slalomPylons.clear();
    plasmaBolts.clear();
    quantumBlockades.clear();

    // Cross-translate Pair 1 (Classic)
    final double newOrbLeft = hemisphereState.getLaneLeft(HemisphereMechanic.orb, screenWidth);
    final double newOrbRight = hemisphereState.getLaneRight(HemisphereMechanic.orb, screenWidth);
    orb.x = (newOrbLeft + newOrbRight) / 2.0;

    final double newDartLeft = hemisphereState.getLaneLeft(HemisphereMechanic.dart, screenWidth);
    final double newDartRight = hemisphereState.getLaneRight(HemisphereMechanic.dart, screenWidth);
    dart.x = (newDartLeft + newDartRight) / 2.0;
    dart.targetX = dart.x;
    _rollingSafeCorridorX = dart.x;

    // Cross-translate Pair 2 (Phase Flux)
    final double newPhaseLeft = hemisphereState.getLaneLeft(HemisphereMechanic.phaseCore, screenWidth);
    final double newPhaseRight = hemisphereState.getLaneRight(HemisphereMechanic.phaseCore, screenWidth);
    phaseCore.x = (newPhaseLeft + newPhaseRight) / 2.0;

    final double newSlalomLeft = hemisphereState.getLaneLeft(HemisphereMechanic.slalomDrift, screenWidth);
    final double newSlalomRight = hemisphereState.getLaneRight(HemisphereMechanic.slalomDrift, screenWidth);
    final double introFactor = (survivalTime / 3.5).clamp(0.0, 1.0);
    slalomDrift.x = slalomDrift.getChasmCenter(slalomDrift.y, newSlalomLeft, newSlalomRight, introFactor: introFactor);
    slalomDrift.targetX = slalomDrift.x;

    // Cross-translate Pair 3 (Pulse Reflex)
    final double newQLeft = hemisphereState.getLaneLeft(HemisphereMechanic.quantumWarp, screenWidth);
    final double newQRight = hemisphereState.getLaneRight(HemisphereMechanic.quantumWarp, screenWidth);
    final double trackLeftX = newQLeft + (newQRight - newQLeft) * 0.30;
    final double trackRightX = newQLeft + (newQRight - newQLeft) * 0.70;
    quantumWarp.currentX = quantumWarp.track == QuantumTrack.left ? trackLeftX : trackRightX;
    quantumWarp.targetX = quantumWarp.currentX;

    ProceduralAudioSynth.instance.playSwapExecute();
    HapticChoreographer.instance.triggerSwapExecute();
    _addCameraShake(8.0);
  }

  void _updateObstacleSpawners(double dt) {
    // 3.5 second initial runway grace period across ALL game modes: 0 obstacles spawn on start
    if (survivalTime < 3.5) return;

    final double speedScale = survivalTime >= 45.0 ? 1.35 : 1.0;

    if (gamePairMode == GamePairMode.classic) {
      final double orbLeft = hemisphereState.getLaneLeft(HemisphereMechanic.orb, screenWidth);
      final double orbRight = hemisphereState.getLaneRight(HemisphereMechanic.orb, screenWidth);
      final double dartLeft = hemisphereState.getLaneLeft(HemisphereMechanic.dart, screenWidth);
      final double dartRight = hemisphereState.getLaneRight(HemisphereMechanic.dart, screenWidth);

      // --- 1. LASER GATES SPAWNER (Only active if orb is alive) ---
      if (orbAlive) {
        _laserSpawnTimer += dt;
        final double laserInterval = math.max(
          PhysicsConstants.laserGateMinInterval,
          PhysicsConstants.laserGateInitialInterval - (survivalTime / 60.0) * 0.9,
        );

        if (_laserSpawnTimer >= laserInterval) {
          _laserSpawnTimer = 0.0;
          final double spawnY = hemisphereState.isPolarityInverted ? screenHeight + 20.0 : -20.0;
          final double gapX = rng.nextDoubleInRange(
            orbLeft + PhysicsConstants.laserGateGapWidth / 2.0 + 12.0,
            orbRight - PhysicsConstants.laserGateGapWidth / 2.0 - 12.0,
          );

          laserGates.add(
            LaserGate(
              y: spawnY,
              gapCenterX: gapX,
              speed: PhysicsConstants.laserGateSpeed * speedScale,
            ),
          );
        }

        for (int i = laserGates.length - 1; i >= 0; i--) {
          final gate = laserGates[i];
          gate.update(
            dt: dt,
            laneLeft: orbLeft,
            laneRight: orbRight,
            inverted: hemisphereState.isPolarityInverted,
            shouldOscillate: survivalTime >= 20.0,
          );

          if ((!hemisphereState.isPolarityInverted && gate.y > screenHeight + 40) ||
              (hemisphereState.isPolarityInverted && gate.y < -40)) {
            laserGates.removeAt(i);
          }
        }
      } else {
        laserGates.clear();
      }

      // --- 2. MONOLITHS SPAWNER (Only active if dart is alive) ---
      if (dartAlive) {
        _monolithSpawnTimer += dt;
        final double monolithInterval = math.max(
          PhysicsConstants.monolithMinInterval,
          PhysicsConstants.monolithInitialInterval - (survivalTime / 60.0) * 0.37,
        );

        if (_monolithSpawnTimer >= monolithInterval) {
          _monolithSpawnTimer = 0.0;
          final double spawnY = hemisphereState.isPolarityInverted ? screenHeight + 40.0 : -40.0;
          final double fallSpeed = (PhysicsConstants.monolithInitialSpeed +
                  (survivalTime / 60.0) * (PhysicsConstants.monolithMaxSpeed - PhysicsConstants.monolithInitialSpeed)) *
              speedScale;

          _rollingSafeCorridorX = rng.getNextSafeCorridor(
            prevCorridorX: _rollingSafeCorridorX,
            laneLeft: dartLeft,
            laneRight: dartRight,
          );

          final double mWidth = rng.nextDoubleInRange(32.0, 56.0);
          final double mHeight = rng.nextDoubleInRange(32.0, 64.0);

          double mX = dartLeft + (dartRight - dartLeft) * rng.nextDouble();
          if ((mX - _rollingSafeCorridorX).abs() < 40.0) {
            mX = mX < _rollingSafeCorridorX ? mX - 35.0 : mX + 35.0;
          }
          mX = mX.clamp(dartLeft + mWidth / 2.0, dartRight - mWidth / 2.0);

          monoliths.add(
            Monolith(
              x: mX,
              y: spawnY,
              width: mWidth,
              height: mHeight,
              speed: fallSpeed,
            ),
          );
        }

        for (int i = monoliths.length - 1; i >= 0; i--) {
          final m = monoliths[i];
          m.update(dt: dt, inverted: hemisphereState.isPolarityInverted);

          if ((!hemisphereState.isPolarityInverted && m.y > screenHeight + 60) ||
              (hemisphereState.isPolarityInverted && m.y < -60)) {
            monoliths.removeAt(i);
          }
        }
      } else {
        monoliths.clear();
      }
    } else if (gamePairMode == GamePairMode.phaseFlux) {
      // Pair 2: Polarity Walls & Slalom Pylons
      if (orbAlive) {
        _laserSpawnTimer += dt;
        if (_laserSpawnTimer >= 1.6) {
          _laserSpawnTimer = 0.0;
          final PolarityColor pColor = rng.nextDouble() > 0.5 ? PolarityColor.cyan : PolarityColor.crimson;
          polarityWalls.add(
            PolarityWall(
              y: -30.0,
              color: pColor,
              speed: 210.0 * speedScale,
            ),
          );
        }

        for (int i = polarityWalls.length - 1; i >= 0; i--) {
          final w = polarityWalls[i];
          w.y += w.speed * dt;
          if (w.y > screenHeight + 40) {
            polarityWalls.removeAt(i);
          }
        }
      } else {
        polarityWalls.clear();
      }

      if (dartAlive) {
        _monolithSpawnTimer += dt;
        if (_monolithSpawnTimer >= 1.4) {
          _monolithSpawnTimer = 0.0;
          final double sLeft = hemisphereState.getLaneLeft(HemisphereMechanic.slalomDrift, screenWidth);
          final double sRight = hemisphereState.getLaneRight(HemisphereMechanic.slalomDrift, screenWidth);
          final double introFactor = ((survivalTime - 3.5) / 3.5).clamp(0.0, 1.0);
          final double chasmCenter = slalomDrift.getChasmCenter(0.0, sLeft, sRight, introFactor: introFactor);
          final double offset = (rng.nextDouble() - 0.5) * 40.0;

          slalomPylons.add(
            SlalomPylon(
              x: (chasmCenter + offset).clamp(sLeft + 20.0, sRight - 20.0),
              y: -30.0,
              speed: 220.0 * speedScale,
            ),
          );
        }

        for (int i = slalomPylons.length - 1; i >= 0; i--) {
          final p = slalomPylons[i];
          p.y += p.speed * dt;
          if (p.y > screenHeight + 40) {
            slalomPylons.removeAt(i);
          }
        }
      } else {
        slalomPylons.clear();
      }
    } else if (gamePairMode == GamePairMode.pulseReflex) {
      // Pair 3: Plasma Bolts & Quantum Blockades
      if (orbAlive) {
        _laserSpawnTimer += dt;
        if (_laserSpawnTimer >= 1.3) {
          _laserSpawnTimer = 0.0;
          plasmaBolts.add(
            PlasmaBolt(
              y: -30.0,
              speed: 380.0 * speedScale,
            ),
          );
        }

        for (int i = plasmaBolts.length - 1; i >= 0; i--) {
          final b = plasmaBolts[i];
          b.y += b.speed * dt;
          if (b.y > screenHeight + 40) {
            plasmaBolts.removeAt(i);
          }
        }
      } else {
        plasmaBolts.clear();
      }

      if (dartAlive) {
        _monolithSpawnTimer += dt;
        if (_monolithSpawnTimer >= 1.2) {
          _monolithSpawnTimer = 0.0;
          final QuantumTrack qTrack = rng.nextDouble() > 0.5 ? QuantumTrack.left : QuantumTrack.right;
          quantumBlockades.add(
            QuantumBlockade(
              y: -40.0,
              track: qTrack,
              speed: 310.0 * speedScale,
            ),
          );
        }

        for (int i = quantumBlockades.length - 1; i >= 0; i--) {
          final b = quantumBlockades[i];
          b.y += b.speed * dt;
          if (b.y > screenHeight + 40) {
            quantumBlockades.removeAt(i);
          }
        }
      } else {
        quantumBlockades.clear();
      }
    }
  }

  void _checkCollisions() {
    // If post-swap grace period is active, grant collision invulnerability so mutation doesn't insta-kill
    if (_postSwapGraceTimer > 0.0) return;

    if (gamePairMode == GamePairMode.classic) {
      // 1. Orb Spikes Check
      if (orbAlive) {
        const double spikeThreshold = 14.0;
        if (orb.y - PhysicsConstants.orbRadius < spikeThreshold ||
            orb.y + PhysicsConstants.orbRadius > screenHeight - spikeThreshold) {
          _handleHemisphereFailure(
            failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.orb ? 'LEFT' : 'RIGHT',
            failedMechanic: 'ORB',
            impactPoint: Offset(orb.x, orb.y),
          );
          return;
        }

        // 2. Orb Laser Gates Check
        for (final gate in laserGates) {
          final bool collided = gate.checkCollisionWithOrb(
            orbX: orb.x,
            orbY: orb.y,
            orbRadius: PhysicsConstants.orbRadius,
            onNearMiss: () => _handleNearMiss(Offset(orb.x, orb.y)),
          );
          if (collided) {
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.orb ? 'LEFT' : 'RIGHT',
              failedMechanic: 'ORB',
              impactPoint: Offset(orb.x, orb.y),
            );
            return;
          }
        }
      }

      // 3. Dart Monoliths Check
      if (dartAlive) {
        final hitboxCircles = dart.getHitboxCircles(inverted: hemisphereState.isPolarityInverted);
        for (final m in monoliths) {
          final bool collided = m.checkCollisionWithDartCircles(
            circles: hitboxCircles,
            onNearMiss: () => _handleNearMiss(Offset(dart.x, dart.railY)),
          );
          if (collided) {
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.dart ? 'LEFT' : 'RIGHT',
              failedMechanic: 'DART',
              impactPoint: Offset(dart.x, dart.railY),
            );
            return;
          }
        }
      }
    } else if (gamePairMode == GamePairMode.phaseFlux) {
      // Pair 2 Collisions
      if (orbAlive) {
        for (final w in polarityWalls) {
          if (w.absorbed) continue;
          final double coreTop = phaseCore.y - 18.0;
          final double coreBottom = phaseCore.y + 18.0;
          final double wallTop = w.y;
          final double wallBottom = w.y + w.height;

          // Check vertical intersection
          if (wallBottom >= coreTop && wallTop <= coreBottom) {
            if (w.color == phaseCore.polarity) {
              // Absorbed successfully!
              w.absorbed = true;
              currentScore += 50.0 * batteryState.scoreMultiplier;
              ProceduralAudioSynth.instance.playPhaseAbsorb();
              particlePool.spawnBurst(
                origin: Offset(phaseCore.x, phaseCore.y),
                count: 14,
                color: phaseCore.currentColor,
                speed: 180.0,
              );
            } else {
              // Wrong color collision -> failure
              _handleHemisphereFailure(
                failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.phaseCore ? 'LEFT' : 'RIGHT',
                failedMechanic: 'PHASE CORE',
                impactPoint: Offset(phaseCore.x, phaseCore.y),
              );
              return;
            }
          } else if (wallTop > coreBottom && !w.absorbed) {
            // Breached defense without absorption
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.phaseCore ? 'LEFT' : 'RIGHT',
              failedMechanic: 'PHASE CORE',
              impactPoint: Offset(phaseCore.x, phaseCore.y),
            );
            return;
          }
        }
      }

      if (dartAlive) {
        final double sLeft = hemisphereState.getLaneLeft(HemisphereMechanic.slalomDrift, screenWidth);
        final double sRight = hemisphereState.getLaneRight(HemisphereMechanic.slalomDrift, screenWidth);
        final double laneW = sRight - sLeft;
        final double introFactor = ((survivalTime - 3.5) / 3.5).clamp(0.0, 1.0);
        final double center = slalomDrift.getChasmCenter(slalomDrift.y, sLeft, sRight, introFactor: introFactor);
        final double chasmW = slalomDrift.getChasmWidth(laneW, introFactor: introFactor);

        // Slalom boundary collision (skip initial grace period < 3.5s so player has time to orient)
        if (survivalTime >= 3.5) {
          if (slalomDrift.x < center - chasmW * 0.5 + 8.0 || slalomDrift.x > center + chasmW * 0.5 - 8.0) {
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.slalomDrift ? 'LEFT' : 'RIGHT',
              failedMechanic: 'SLALOM',
              impactPoint: Offset(slalomDrift.x, slalomDrift.y),
            );
            return;
          }
        }

        // Slalom pylon collisions
        for (final p in slalomPylons) {
          final double dx = p.x - slalomDrift.x;
          final double dy = p.y - slalomDrift.y;
          if (math.sqrt(dx * dx + dy * dy) < p.radius + 10.0) {
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.slalomDrift ? 'LEFT' : 'RIGHT',
              failedMechanic: 'SLALOM',
              impactPoint: Offset(slalomDrift.x, slalomDrift.y),
            );
            return;
          }
        }
      }
    } else if (gamePairMode == GamePairMode.pulseReflex) {
      // Pair 3 Collisions
      if (orbAlive) {
        final double shieldLeft = hemisphereState.getLaneLeft(HemisphereMechanic.shieldPing, screenWidth);
        final double shieldRight = hemisphereState.getLaneRight(HemisphereMechanic.shieldPing, screenWidth);
        final double shieldMidX = (shieldLeft + shieldRight) / 2.0;

        for (final bolt in plasmaBolts) {
          if (bolt.deflected) continue;
          if (bolt.y >= shieldPing.y - 20.0 && bolt.y <= shieldPing.y + 20.0) {
            if (shieldPing.isDeflecting) {
              bolt.deflected = true;
              currentScore += 75.0 * batteryState.scoreMultiplier;
              particlePool.spawnBurst(
                origin: Offset(shieldMidX, shieldPing.y),
                count: 16,
                color: SplitPalette.nearMissCyan,
                speed: 220.0,
              );
            } else if (bolt.y > shieldPing.y + 6.0) {
              _handleHemisphereFailure(
                failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.shieldPing ? 'LEFT' : 'RIGHT',
                failedMechanic: 'SHIELD',
                impactPoint: Offset(shieldMidX, shieldPing.y),
              );
              return;
            }
          } else if (bolt.y > shieldPing.y + 20.0 && !bolt.deflected) {
            // Bolt breached shield barrier!
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.shieldPing ? 'LEFT' : 'RIGHT',
              failedMechanic: 'SHIELD',
              impactPoint: Offset(shieldMidX, shieldPing.y),
            );
            return;
          }
        }
      }

      if (dartAlive) {
        final double qLeft = hemisphereState.getLaneLeft(HemisphereMechanic.quantumWarp, screenWidth);
        final double qRight = hemisphereState.getLaneRight(HemisphereMechanic.quantumWarp, screenWidth);
        final double trackLeftX = qLeft + (qRight - qLeft) * 0.30;
        final double trackRightX = qLeft + (qRight - qLeft) * 0.70;

        for (final b in quantumBlockades) {
          final double bx = b.track == QuantumTrack.left ? trackLeftX : trackRightX;
          final bool onSameTrack = (quantumWarp.currentX - bx).abs() < 24.0;
          final bool verticalOverlap = (b.y - quantumWarp.y).abs() < (b.height * 0.5 + 16.0);
          if (onSameTrack && verticalOverlap) {
            _handleHemisphereFailure(
              failedHemisphere: hemisphereState.leftMechanic == HemisphereMechanic.quantumWarp ? 'LEFT' : 'RIGHT',
              failedMechanic: 'QUANTUM',
              impactPoint: Offset(quantumWarp.currentX, quantumWarp.y),
            );
            return;
          }
        }
      }
    }
  }

  void _handleHemisphereFailure({
    required String failedHemisphere,
    required String failedMechanic,
    required Offset impactPoint,
  }) {
    if (playMode == PlayHandMode.twoHands) {
      // 2 Hands Mode: Any crash terminates run immediately
      _triggerDeath(
        failedHemisphere: failedHemisphere,
        failedMechanic: failedMechanic,
        impactPoint: impactPoint,
      );
    } else {
      // 1 Hand Mode: Eliminate failed side, continue with surviving side
      if (failedMechanic == 'ORB' || failedMechanic == 'PHASE CORE' || failedMechanic == 'SHIELD') {
        orbAlive = false;
        laserGates.clear();
        polarityWalls.clear();
        plasmaBolts.clear();
      } else {
        dartAlive = false;
        monoliths.clear();
        slalomPylons.clear();
        quantumBlockades.clear();
      }

      // Explosion effects on the destroyed side
      particlePool.spawnBurst(
        origin: impactPoint,
        count: 45,
        color: SplitPalette.hazardCrimson,
        speed: 280.0,
      );
      _addCameraShake(12.0);
      ProceduralAudioSynth.instance.playDeath();
      HapticChoreographer.instance.triggerDeath();

      // If BOTH sides are now dead, trigger complete game over autopsy
      if (!orbAlive && !dartAlive) {
        _triggerDeath(
          failedHemisphere: failedHemisphere,
          failedMechanic: failedMechanic,
          impactPoint: impactPoint,
        );
      }
    }
  }

  void _handleNearMiss(Offset pos) {
    nearMissCount++;
    currentScore += PhysicsConstants.nearMissBonusPoints * batteryState.scoreMultiplier;
    ProceduralAudioSynth.instance.playNearMiss();
    HapticChoreographer.instance.triggerNearMiss();
    particlePool.spawnBurst(
      origin: pos,
      count: 12,
      color: SplitPalette.nearMissCyan,
      speed: 180.0,
      sides: 2, // cyan sparks
    );
  }

  void _triggerDeath({
    required String failedHemisphere,
    required String failedMechanic,
    required Offset impactPoint,
  }) {
    state = GamePlayState.deathSlowmo;
    deathSlowmoTimer = 0.20; // 200ms slow-mo
    deathFocusPoint = impactPoint;

    // Shatter into 60 procedural polygons
    particlePool.spawnBurst(
      origin: impactPoint,
      count: 60,
      color: SplitPalette.hazardCrimson,
      speed: 320.0,
    );

    _addCameraShake(16.0);
    ProceduralAudioSynth.instance.playDeath();
    HapticChoreographer.instance.triggerDeath();

    // Determine responsible player in duo mode
    String responsible = 'SOLO RUN';
    if (sessionMode == GameSessionMode.duoCoop) {
      final bool failedLeft = failedHemisphere == 'LEFT';
      responsible = failedLeft ? 'PLAYER 1 (LEFT)' : 'PLAYER 2 (RIGHT)';
    }

    final autopsy = DeathAutopsy(
      survivalTime: survivalTime,
      finalScore: currentScore.toInt(),
      failedHemisphere: failedHemisphere,
      failedMechanic: failedMechanic,
      timePostLastMutation: survivalTime - lastMutationTimestamp,
      batteryPct: batteryState.batteryLevel,
      wasOverdrive: batteryState.isOverdrive,
      scoreMultiplier: batteryState.scoreMultiplier,
      leftActivity: List.from(inputRouter.leftActivityHistory),
      rightActivity: List.from(inputRouter.rightActivityHistory),
      playMode: playMode,
      sessionMode: sessionMode,
      responsibleParty: responsible,
    );
    latestAutopsy = autopsy;

    // Save score
    LeaderboardService.instance.getPlayerHandle().then((handle) {
      LeaderboardService.instance.recordScore(
        ScoreEntry(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          playerHandle: handle,
          score: autopsy.finalScore,
          survivalMs: (autopsy.survivalTime * 1000).toInt(),
          batteryPct: autopsy.batteryPct,
          wasOverdrive: autopsy.wasOverdrive,
          failedHemisphere: autopsy.failedHemisphere,
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  void _addCameraShake(double intensity) {
    _shakeIntensity = math.max(_shakeIntensity, intensity);
  }

  HemisphereMechanic _resolveTargetMechanic(bool isLeft) {
    if (playMode == PlayHandMode.oneHand) {
      if (!orbAlive && dartAlive) {
        switch (gamePairMode) {
          case GamePairMode.classic:
            return HemisphereMechanic.dart;
          case GamePairMode.phaseFlux:
            return HemisphereMechanic.slalomDrift;
          case GamePairMode.pulseReflex:
            return HemisphereMechanic.quantumWarp;
        }
      } else if (orbAlive && !dartAlive) {
        switch (gamePairMode) {
          case GamePairMode.classic:
            return HemisphereMechanic.orb;
          case GamePairMode.phaseFlux:
            return HemisphereMechanic.phaseCore;
          case GamePairMode.pulseReflex:
            return HemisphereMechanic.shieldPing;
        }
      }
    }
    return isLeft ? hemisphereState.leftMechanic : hemisphereState.rightMechanic;
  }

  // Unified Input Routing across dynamic hemisphere swaps
  void handleSidePointerDown(bool isLeft, Offset localPosition) {
    if (state != GamePlayState.playing) return;

    final mechanic = _resolveTargetMechanic(isLeft);
    if (!isMechanicAlive(mechanic)) return;

    final double laneLeft = hemisphereState.getLaneLeft(mechanic, screenWidth);
    final double laneRight = hemisphereState.getLaneRight(mechanic, screenWidth);

    final double targetTapX;
    if (playMode == PlayHandMode.oneHand && (!orbAlive || !dartAlive)) {
      final double normalizedX = (localPosition.dx / screenWidth).clamp(0.0, 1.0);
      targetTapX = laneLeft + normalizedX * (laneRight - laneLeft);
    } else {
      targetTapX = localPosition.dx;
    }

    switch (mechanic) {
      case HemisphereMechanic.orb:
        orb.thrust(inverted: hemisphereState.isPolarityInverted);
        ProceduralAudioSynth.instance.playTap();
        HapticChoreographer.instance.triggerTap();
        particlePool.spawnBurst(
          origin: Offset(orb.x, orb.y),
          count: 4,
          color: (isLeft ? hemisphereState.leftFg : hemisphereState.rightFg).withOpacity(0.5),
          speed: 70.0,
        );
        break;
      case HemisphereMechanic.phaseCore:
        phaseCore.flip();
        ProceduralAudioSynth.instance.playPhaseAbsorb();
        HapticChoreographer.instance.triggerTap();
        particlePool.spawnBurst(
          origin: Offset(phaseCore.x, phaseCore.y),
          count: 8,
          color: phaseCore.currentColor,
          speed: 120.0,
        );
        break;
      case HemisphereMechanic.shieldPing:
        shieldPing.triggerPing();
        ProceduralAudioSynth.instance.playShieldPing();
        HapticChoreographer.instance.triggerTap();
        break;
      case HemisphereMechanic.dart:
        dart.handleTap(targetTapX, laneLeft: laneLeft, laneRight: laneRight);
        break;
      case HemisphereMechanic.slalomDrift:
        slalomDrift.targetX = targetTapX.clamp(laneLeft + 16.0, laneRight - 16.0);
        break;
      case HemisphereMechanic.quantumWarp:
        quantumWarp.warp();
        ProceduralAudioSynth.instance.playWarp();
        HapticChoreographer.instance.triggerTap();
        particlePool.spawnBurst(
          origin: Offset(quantumWarp.currentX, quantumWarp.y),
          count: 10,
          color: SplitPalette.nearMissCyan,
          speed: 140.0,
        );
        break;
    }
  }

  void handleSidePointerMove(bool isLeft, double deltaX, Offset localPosition) {
    if (state != GamePlayState.playing) return;

    final mechanic = _resolveTargetMechanic(isLeft);
    if (!isMechanicAlive(mechanic)) return;

    final double laneLeft = hemisphereState.getLaneLeft(mechanic, screenWidth);
    final double laneRight = hemisphereState.getLaneRight(mechanic, screenWidth);

    final double targetTapX;
    if (playMode == PlayHandMode.oneHand && (!orbAlive || !dartAlive)) {
      final double normalizedX = (localPosition.dx / screenWidth).clamp(0.0, 1.0);
      targetTapX = laneLeft + normalizedX * (laneRight - laneLeft);
    } else {
      targetTapX = localPosition.dx;
    }

    switch (mechanic) {
      case HemisphereMechanic.dart:
        dart.handleDragDelta(deltaX, currentX: targetTapX, laneLeft: laneLeft, laneRight: laneRight);
        break;
      case HemisphereMechanic.slalomDrift:
        slalomDrift.targetX = targetTapX.clamp(laneLeft + 16.0, laneRight - 16.0);
        break;
      default:
        break;
    }
  }

  void handleLeftAction() => handleSidePointerDown(true, Offset(screenWidth * 0.25, screenHeight * 0.5));
  void handleRightActionTap(double tapX) => handleSidePointerDown(false, Offset(tapX, screenHeight * 0.5));
  void handleRightActionDrag(double deltaX, double currentX) => handleSidePointerMove(false, deltaX, Offset(currentX, screenHeight * 0.5));
}
