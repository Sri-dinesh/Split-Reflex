import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../../core/constants/palette.dart';
import '../core/constants/physics_constants.dart';
import '../core/services/battery_telemetry_service.dart';
import '../core/services/haptic_choreographer.dart';
import '../core/services/leaderboard_service.dart';
import '../core/services/preferences_service.dart';
import '../core/services/procedural_audio_synth.dart';
import '../core/utils/seeded_rng.dart';
import 'entities/dart_entity.dart';
import 'entities/dimension_breach_entity.dart';
import 'entities/obstacle_entity.dart';
import 'entities/orb_entity.dart';
import 'entities/particle_pool.dart';
import 'entities/tide_lock_entity.dart';
import 'hemisphere_state.dart';
import 'input_router.dart';

enum GamePlayState { attract, countdown, playing, deathSlowmo, deathReceipt }

class DeathAutopsy {
  final double survivalTime;
  final int finalScore;
  final String failedHemisphere; // 'LEFT' or 'RIGHT'
  final String failedMechanic; // 'ORB' or 'DART'
  final double timePostLastMutation;
  final int batteryPct;
  final bool wasOverdrive;
  final double scoreMultiplier;
  final List<double> leftActivity;
  final List<double> rightActivity;
  final PlayHandMode playMode;
  final GameSessionMode sessionMode;
  final String
  responsibleParty; // 'SOLO', 'PLAYER 1 (LEFT)', or 'PLAYER 2 (RIGHT)'

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
  classic, // Left: Orb (Thrust) | Right: Dart (Steer)
  dimensionBreach, // Zero-G Membrane Ping-Pong (Left: Anti-G | Right: Heavy-G)
  tideLock, // One shared tide: Left: Valve+Sub | Right: Harvester Buoy
}

enum PlayHandMode {
  twoHands, // Strict mode: if either side fails, game over
  oneHand, // Casual/survival mode: if one side fails, the other keeps playing
}

enum GameSessionMode {
  solo, // 1 Player: Dual-hemisphere self challenge
  duoCoop, // 2 Players: 1 phone, P1 Left vs P2 Right, swap hands on mutation
}

enum ControlMode {
  touchSwipe, // Standard touch & drag
  gyroTilt, // Physical phone tilting steers Dart or Slalom!
}

enum CyberTheme {
  monochrome, // High-contrast Cyber Core (default)
  synthwave, // 1984 Retro Neon Magenta & Cyan
  matrix, // Emerald Terminal Scanlines
  cyberGold, // Luxury 24K Gold & Obsidian
}

class GameController extends ChangeNotifier {
  GameController() {
    _restorePreferences();
  }

  GamePlayState state = GamePlayState.attract;
  GamePairMode gamePairMode = GamePairMode.classic;
  PlayHandMode playMode = PlayHandMode.twoHands;
  GameSessionMode sessionMode = GameSessionMode.solo;
  ControlMode controlMode = ControlMode.touchSwipe;
  CyberTheme theme = CyberTheme.monochrome;

  /// Restores the player's saved ruleset so the app opens the way they left it.
  void _restorePreferences() {
    final PreferencesService prefs = PreferencesService.instance;
    if (!prefs.isReady) return;

    gamePairMode = _enumByName(
      GamePairMode.values,
      prefs.pairMode,
      GamePairMode.classic,
    );
    playMode = _enumByName(
      PlayHandMode.values,
      prefs.playMode,
      PlayHandMode.twoHands,
    );
    sessionMode = _enumByName(
      GameSessionMode.values,
      prefs.sessionMode,
      GameSessionMode.solo,
    );
    controlMode = _enumByName(
      ControlMode.values,
      prefs.controlMode,
      ControlMode.touchSwipe,
    );
    theme = _enumByName(CyberTheme.values, prefs.theme, CyberTheme.monochrome);
  }

  /// Restores every gameplay rule to its factory default.
  ///
  /// Used by "Erase all local data" in Settings. Storage is cleared by the
  /// caller through [PreferencesService.clearAll] and
  /// [LeaderboardService.clearAllUserData].
  void resetToFactoryDefaults() {
    gamePairMode = GamePairMode.classic;
    playMode = PlayHandMode.twoHands;
    sessionMode = GameSessionMode.solo;
    controlMode = ControlMode.touchSwipe;
    theme = CyberTheme.monochrome;
    returnToMenu();
    notifyListeners();
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    if (name == null) return fallback;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

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

  // Pair 2: Dimension Breach (Zero-G Membrane Ping-Pong)
  final DimensionBreachEntity dimensionBreach = DimensionBreachEntity();

  // Pair 3: Tide Lock (ONE shared water level between both hemispheres)
  final TideLockEntity tideLock = TideLockEntity();

  final ParticlePool particlePool = ParticlePool();
  final SeededRng rng = SeededRng();

  // Spawners
  double _laserSpawnTimer =
      -3.0; // 3.0s startup grace period for all game modes
  double _monolithSpawnTimer = -3.0;
  double _postSwapGraceTimer = 0.0;
  double _rollingSafeCorridorX = 0.0;
  double _attractAnimTime = 0.0;
  double _tideBubbleTimer = 0.0;

  /// Free-running cosmetic clock for attract/countdown water animation.
  double get waveAnimTime =>
      state == GamePlayState.playing ? survivalTime : _attractAnimTime;

  bool isMechanicAlive(HemisphereMechanic mechanic) {
    switch (mechanic) {
      case HemisphereMechanic.orb:
      case HemisphereMechanic.breachAlpha:
      case HemisphereMechanic.tideSub:
        return orbAlive;
      case HemisphereMechanic.dart:
      case HemisphereMechanic.breachBeta:
      case HemisphereMechanic.tideHarvester:
        return dartAlive;
    }
  }

  // Gameplay Run Metrics
  double survivalTime = 0.0;
  double currentScore = 0.0;
  int nearMissCount = 0;
  double phaseMultiplier = 1.0;
  double lastMutationTimestamp = 0.0;
  double get speedScale => survivalTime >= 45.0 ? 1.35 : 1.0;

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
    if (gamePairMode == GamePairMode.dimensionBreach &&
        mode == PlayHandMode.oneHand) {
      // 1-Hand mode is disabled for Dimension Breach (Dual paddles require 2 hands)
      return;
    }
    playMode = mode;
    PreferencesService.instance.setPlayMode(mode.name).ignore();
    notifyListeners();
  }

  void togglePlayMode() {
    if (gamePairMode == GamePairMode.dimensionBreach) {
      // Dimension Breach is strictly 2-Hands dual paddle control
      ProceduralAudioSynth.instance.playTap();
      HapticChoreographer.instance.triggerTap();
      return;
    }
    playMode = playMode == PlayHandMode.twoHands
        ? PlayHandMode.oneHand
        : PlayHandMode.twoHands;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setSessionMode(GameSessionMode mode) {
    sessionMode = mode;
    PreferencesService.instance.setSessionMode(mode.name).ignore();
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void toggleSessionMode() {
    sessionMode = sessionMode == GameSessionMode.solo
        ? GameSessionMode.duoCoop
        : GameSessionMode.solo;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setControlMode(ControlMode mode) {
    controlMode = mode;
    PreferencesService.instance.setControlMode(mode.name).ignore();
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void toggleControlMode() {
    controlMode = controlMode == ControlMode.touchSwipe
        ? ControlMode.gyroTilt
        : ControlMode.touchSwipe;
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void setTheme(CyberTheme newTheme) {
    theme = newTheme;
    PreferencesService.instance.setTheme(newTheme.name).ignore();
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
    if (mode == GamePairMode.dimensionBreach && playMode == PlayHandMode.oneHand) {
      playMode = PlayHandMode.twoHands;
      PreferencesService.instance.setPlayMode(playMode.name).ignore();
    }
    PreferencesService.instance.setPairMode(mode.name).ignore();
    _initAttractMode();
    ProceduralAudioSynth.instance.playTap();
    HapticChoreographer.instance.triggerTap();
    notifyListeners();
  }

  void cycleGamePairMode() {
    final values = GamePairMode.values;
    final nextIndex = (values.indexOf(gamePairMode) + 1) % values.length;
    gamePairMode = values[nextIndex];
    if (gamePairMode == GamePairMode.dimensionBreach && playMode == PlayHandMode.oneHand) {
      playMode = PlayHandMode.twoHands;
      PreferencesService.instance.setPlayMode(playMode.name).ignore();
    }
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
      case GamePairMode.dimensionBreach:
        leftMech = HemisphereMechanic.breachAlpha;
        rightMech = HemisphereMechanic.breachBeta;
        break;
      case GamePairMode.tideLock:
        leftMech = HemisphereMechanic.tideSub;
        rightMech = HemisphereMechanic.tideHarvester;
        break;
    }

    hemisphereState.reset(
      screenWidth,
      initialLeft: leftMech,
      initialRight: rightMech,
    );
    inputRouter.resetActivity();
    particlePool.clear();

    // 3.5 second startup runway grace period across all modes: 0 obstacles spawn on start
    _laserSpawnTimer = -3.5;
    _monolithSpawnTimer = -3.5;
    _postSwapGraceTimer = 0.0;

    // Clear obstacles
    laserGates.clear();
    monoliths.clear();
    dimensionBreach.mines.clear();
    tideLock.clearSubHazards();
    tideLock.clearBuoyHazards();

    final double leftLaneLeft = hemisphereState.getLaneLeft(
      leftMech,
      screenWidth,
    );
    final double leftLaneRight = hemisphereState.getLaneRight(
      leftMech,
      screenWidth,
    );
    final double rightLaneLeft = hemisphereState.getLaneLeft(
      rightMech,
      screenWidth,
    );
    final double rightLaneRight = hemisphereState.getLaneRight(
      rightMech,
      screenWidth,
    );

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

    // Init Pair 2: Dimension Breach Ping-Pong
    dimensionBreach.reset(
      initialLeftX: leftLaneLeft + 26.0,
      initialRightX: rightLaneRight - 26.0,
      splitX: hemisphereState.rawSplitPixels,
      screenHeight: screenHeight,
    );

    // Init Pair 3: Tide Lock — one shared water level across both hemispheres
    tideLock.reset(screenHeight: screenHeight, initialLevel: 0.4);
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

    if (gamePairMode == GamePairMode.dimensionBreach) {
      playMode = PlayHandMode.twoHands;
    }

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
      cameraShake = Offset(
        math.cos(angle) * _shakeIntensity,
        math.sin(angle) * _shakeIntensity,
      );
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
    final int mutationIndex = (survivalTime / PhysicsConstants.mutationInterval)
        .floor();
    phaseMultiplier = 1.0 + mutationIndex * 0.25;

    // Accumulate score
    final double effectiveBatteryMult = batteryState.scoreMultiplier;
    currentScore +=
        dt *
        PhysicsConstants.basePointsPerSecond *
        phaseMultiplier *
        effectiveBatteryMult;

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
      isMutationEnabled:
          playMode == PlayHandMode.twoHands || (orbAlive && dartAlive),
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
      final double orbLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.orb,
        screenWidth,
      );
      final double orbRight = hemisphereState.getLaneRight(
        HemisphereMechanic.orb,
        screenWidth,
      );
      final double gravity = hemisphereState.isPolarityInverted
          ? -PhysicsConstants.orbDefaultGravity
          : PhysicsConstants.orbDefaultGravity;

      final bool orbIsLeft =
          hemisphereState.leftMechanic == HemisphereMechanic.orb;
      final bool orbHeld = (playMode == PlayHandMode.oneHand && !dartAlive)
          ? (inputRouter.leftThumbHeld || inputRouter.rightThumbHeld)
          : (orbIsLeft
                ? inputRouter.leftThumbHeld
                : inputRouter.rightThumbHeld);
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
            color:
                (orbIsLeft ? hemisphereState.leftFg : hemisphereState.rightFg)
                    .withOpacity(0.6),
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

      final double dartLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.dart,
        screenWidth,
      );
      final double dartRight = hemisphereState.getLaneRight(
        HemisphereMechanic.dart,
        screenWidth,
      );
      if (dartAlive) {
        if (controlMode == ControlMode.gyroTilt) {
          final double alpha = 1.0 - math.exp(-26.0 * dt);
          _filteredGyroTiltX =
              ui.lerpDouble(_filteredGyroTiltX, _rawGyroTiltX, alpha) ??
              _rawGyroTiltX;
          const double tiltRange = 3.0;
          final double normalized = (_filteredGyroTiltX / tiltRange).clamp(
            -1.0,
            1.0,
          );
          final double curved =
              normalized.sign * math.pow(normalized.abs(), 1.1);
          final double laneCenter = (dartLeft + dartRight) / 2.0;
          final double maxTravel = (dartRight - dartLeft) / 2.0 - 18.0;
          dart.targetX = (laneCenter + curved * maxTravel).clamp(
            dartLeft + 16.0,
            dartRight - 16.0,
          );
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
          origin: Offset(
            dart.x,
            dart.railY + (hemisphereState.isPolarityInverted ? -12.0 : 12.0),
          ),
          color: hemisphereState.rightFg.withOpacity(0.7),
          inverted: hemisphereState.isPolarityInverted,
        );
      }
    } else if (gamePairMode == GamePairMode.dimensionBreach) {
      // Pair 2: Dimension Breach Ping-Pong
      final double lLeft = hemisphereState.getLaneLeft(
        hemisphereState.leftMechanic,
        screenWidth,
      );
      final double lRight = hemisphereState.getLaneRight(
        hemisphereState.leftMechanic,
        screenWidth,
      );
      final double rLeft = hemisphereState.getLaneLeft(
        hemisphereState.rightMechanic,
        screenWidth,
      );
      final double rRight = hemisphereState.getLaneRight(
        hemisphereState.rightMechanic,
        screenWidth,
      );

      // Gyro tilt support: tilt shifts paddle vertical bias
      if (controlMode == ControlMode.gyroTilt) {
        final double alpha = 1.0 - math.exp(-26.0 * dt);
        _filteredGyroTiltX =
            ui.lerpDouble(_filteredGyroTiltX, _rawGyroTiltX, alpha) ??
            _rawGyroTiltX;
        final double gyroOffset = (_filteredGyroTiltX * 80.0).clamp(-140.0, 140.0);
        if (dartAlive) {
          dimensionBreach.paddleRightTargetY = (dimensionBreach.paddleRightTargetY + gyroOffset * dt).clamp(
            80.0,
            screenHeight - 80.0,
          );
        }
      }

      final bool isLeftAlpha =
          hemisphereState.leftMechanic == HemisphereMechanic.breachAlpha;
      final bool isLeftAlive = isMechanicAlive(hemisphereState.leftMechanic);
      final bool isRightAlive = isMechanicAlive(hemisphereState.rightMechanic);

      final List<BreachEvent> breachEvents = dimensionBreach.update(
        dt: dt,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        splitX: hemisphereState.rawSplitPixels,
        leftLaneLeft: lLeft,
        leftLaneRight: lRight,
        rightLaneLeft: rLeft,
        rightLaneRight: rRight,
        speedScale: speedScale,
        survivalTime: survivalTime,
        isLeftAlive: isLeftAlive,
        isRightAlive: isRightAlive,
        inverted: hemisphereState.isPolarityInverted,
        isLeftAlpha: isLeftAlpha,
        isPostSwapGrace: _postSwapGraceTimer > 0.0,
      );

      _processBreachEvents(breachEvents);
    } else if (gamePairMode == GamePairMode.tideLock) {
      // Pair 3: Tide Lock — ONE shared water level drives both hemispheres.
      final bool subIsLeft =
          hemisphereState.leftMechanic == HemisphereMechanic.tideSub;
      final bool subAlive = isMechanicAlive(HemisphereMechanic.tideSub);
      final bool buoyAlive = isMechanicAlive(HemisphereMechanic.tideHarvester);

      // Valve input: whichever thumb currently hosts the sub mechanic.
      // In 1-Hand survival with the sub gone, the tide breathes on its own.
      bool valveHeld;
      if (!subAlive && playMode == PlayHandMode.oneHand) {
        valveHeld = false; // entity switches to autonomous tide
      } else if (!buoyAlive && playMode == PlayHandMode.oneHand) {
        valveHeld = inputRouter.leftThumbHeld || inputRouter.rightThumbHeld;
      } else {
        valveHeld = subIsLeft
            ? inputRouter.leftThumbHeld
            : inputRouter.rightThumbHeld;
      }

      // Gyro tilt steers the buoy like the Rail Dart.
      if (controlMode == ControlMode.gyroTilt && buoyAlive) {
        final double alpha = 1.0 - math.exp(-26.0 * dt);
        _filteredGyroTiltX =
            ui.lerpDouble(_filteredGyroTiltX, _rawGyroTiltX, alpha) ??
            _rawGyroTiltX;
        const double tiltRange = 3.0;
        final double normalized = (_filteredGyroTiltX / tiltRange).clamp(
          -1.0,
          1.0,
        );
        final double curved =
            normalized.sign * math.pow(normalized.abs(), 1.1);
        final double buoyLaneLeft = hemisphereState.getLaneLeft(
          HemisphereMechanic.tideHarvester,
          screenWidth,
        );
        final double buoyLaneRight = hemisphereState.getLaneRight(
          HemisphereMechanic.tideHarvester,
          screenWidth,
        );
        final double laneCenter = (buoyLaneLeft + buoyLaneRight) / 2.0;
        final double maxTravel =
            (buoyLaneRight - buoyLaneLeft) / 2.0 *
            (1.0 - 2.0 * PhysicsConstants.tideBuoyMinXFactor);
        final double targetX = laneCenter + curved * maxTravel;
        tideLock.setBuoyTargetXFactor(
          (targetX - buoyLaneLeft) / (buoyLaneRight - buoyLaneLeft),
        );
      }

      final List<TideEvent> tideEvents = _updateTideLock(
        dt: dt,
        valveHeld: valveHeld,
        valveAuto: !subAlive && playMode == PlayHandMode.oneHand,
        subAlive: subAlive,
        buoyAlive: buoyAlive,
        // Shared engine invariant: 3.5s startup runway with zero hazards,
        // same as every other game pair.
        spawnEnabled: survivalTime >= 3.5,
        allowDeaths: _postSwapGraceTimer <= 0.0 && survivalTime >= 3.5,
        attractPilot: false,
        survivalTime: survivalTime,
        speedScale: speedScale,
      );
      _processTideEvents(tideEvents);

      // Valve feedback: bubbling exhaust surface while the tide is filling.
      if (subAlive && tideLock.valveOpen) {
        _tideBubbleTimer += dt;
        if (_tideBubbleTimer >= 0.18) {
          _tideBubbleTimer = 0.0;
          final double sLeft = hemisphereState.getLaneLeft(
            HemisphereMechanic.tideSub,
            screenWidth,
          );
          final double sRight = hemisphereState.getLaneRight(
            HemisphereMechanic.tideSub,
            screenWidth,
          );
          final double subCenterX = sLeft + (sRight - sLeft) * 0.5;
          particlePool.spawnBurst(
            origin: Offset(subCenterX, tideLock.subY),
            count: 2,
            color: (subIsLeft
                    ? hemisphereState.leftFg
                    : hemisphereState.rightFg)
                .withOpacity(0.5),
            speed: 55.0,
          );
        }
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

  /// Computes lane geometry and advances the Tide Lock pair one frame.
  List<TideEvent> _updateTideLock({
    required double dt,
    required bool valveHeld,
    required bool valveAuto,
    required bool subAlive,
    required bool buoyAlive,
    required bool spawnEnabled,
    required bool allowDeaths,
    required bool attractPilot,
    required double survivalTime,
    required double speedScale,
    double valveAutoTime = 0.0,
  }) {
    final bool subIsLeft =
        hemisphereState.leftMechanic == HemisphereMechanic.tideSub;
    final double subLaneLeft = hemisphereState.getLaneLeft(
      HemisphereMechanic.tideSub,
      screenWidth,
    );
    final double subLaneRight = hemisphereState.getLaneRight(
      HemisphereMechanic.tideSub,
      screenWidth,
    );
    final double buoyLaneLeft = hemisphereState.getLaneLeft(
      HemisphereMechanic.tideHarvester,
      screenWidth,
    );
    final double buoyLaneRight = hemisphereState.getLaneRight(
      HemisphereMechanic.tideHarvester,
      screenWidth,
    );

    return tideLock.update(
      dt: dt,
      screenHeight: screenHeight,
      subLaneLeft: subLaneLeft,
      subLaneWidth: math.max(1.0, subLaneRight - subLaneLeft),
      buoyLaneLeft: buoyLaneLeft,
      buoyLaneWidth: math.max(1.0, buoyLaneRight - buoyLaneLeft),
      subIsLeft: subIsLeft,
      subActive: subAlive,
      buoyActive: buoyAlive,
      valveHeld: valveHeld,
      valveAuto: valveAuto,
      valveAutoTime: valveAutoTime,
      inverted: hemisphereState.isPolarityInverted,
      spawnEnabled: spawnEnabled,
      allowDeaths: allowDeaths,
      attractPilot: attractPilot,
      survivalTime: survivalTime,
      speedScale: speedScale,
    );
  }

  void _processTideEvents(List<TideEvent> events) {
    if (events.isEmpty) return;

    final bool subIsLeft =
        hemisphereState.leftMechanic == HemisphereMechanic.tideSub;
    for (final TideEvent event in events) {
      switch (event.type) {
        case TideEventType.archCleared:
          currentScore +=
              PhysicsConstants.tideArchClearedPoints *
              batteryState.scoreMultiplier;
          ProceduralAudioSynth.instance.playNearMiss();
          HapticChoreographer.instance.triggerNearMiss();
          particlePool.spawnBurst(
            origin: event.position,
            count: 10,
            color: SplitPalette.nearMissCyan,
            speed: 150.0,
          );
          _addCameraShake(1.5);
          break;

        case TideEventType.subNearMiss:
          _handleNearMiss(event.position);
          break;

        case TideEventType.bulbFed:
          currentScore +=
              PhysicsConstants.tideBulbFedPoints *
              batteryState.scoreMultiplier;
          ProceduralAudioSynth.instance.playWarp();
          HapticChoreographer.instance.triggerSwapTick();
          particlePool.spawnBurst(
            origin: event.position,
            count: 14,
            color: batteryState.isOverdrive
                ? SplitPalette.goldBright
                : SplitPalette.nearMissCyan,
            speed: 170.0,
          );
          _addCameraShake(2.0);
          break;

        case TideEventType.subCrushed:
          _handleHemisphereFailure(
            failedHemisphere: subIsLeft ? 'LEFT' : 'RIGHT',
            failedMechanic: 'TIDE SUB',
            impactPoint: event.position,
          );
          break;

        case TideEventType.buoyStung:
          _handleHemisphereFailure(
            failedHemisphere: subIsLeft ? 'RIGHT' : 'LEFT',
            failedMechanic: 'TIDE HARVESTER',
            impactPoint: event.position,
          );
          break;
      }
    }
  }

  void _tickAttract(double dt) {
    // In attract mode: simulate calm floating orb and hovering dart
    _attractAnimTime += dt;

    if (gamePairMode == GamePairMode.classic) {
      final double orbLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.orb,
        screenWidth,
      );
      final double orbRight = hemisphereState.getLaneRight(
        HemisphereMechanic.orb,
        screenWidth,
      );
      // Gentle floating based on attract anim timer — survivalTime stays strictly 0.0 until run starts!
      orb.y = screenHeight * 0.5 + 40.0 * math.sin(_attractAnimTime * 2.5);
      orb.x =
          ((orbLeft + orbRight) / 2.0) +
          30.0 * math.cos(_attractAnimTime * 1.5);

      final double dartLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.dart,
        screenWidth,
      );
      final double dartRight = hemisphereState.getLaneRight(
        HemisphereMechanic.dart,
        screenWidth,
      );
      dart.x =
          ((dartLeft + dartRight) / 2.0) +
          40.0 * math.sin(_attractAnimTime * 1.8);
      dart.railY = screenHeight * PhysicsConstants.dartDefaultRailYFactor;
    } else if (gamePairMode == GamePairMode.dimensionBreach) {
      final double lLeft = hemisphereState.getLaneLeft(
        hemisphereState.leftMechanic,
        screenWidth,
      );
      final double lRight = hemisphereState.getLaneRight(
        hemisphereState.leftMechanic,
        screenWidth,
      );
      final double rLeft = hemisphereState.getLaneLeft(
        hemisphereState.rightMechanic,
        screenWidth,
      );
      final double rRight = hemisphereState.getLaneRight(
        hemisphereState.rightMechanic,
        screenWidth,
      );

      // AI auto-tracks the ball in attract mode
      dimensionBreach.paddleLeftTargetY = dimensionBreach.ballY;
      dimensionBreach.paddleRightTargetY = dimensionBreach.ballY;
      dimensionBreach.update(
        dt: dt,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        splitX: hemisphereState.rawSplitPixels,
        leftLaneLeft: lLeft,
        leftLaneRight: lRight,
        rightLaneLeft: rLeft,
        rightLaneRight: rRight,
        speedScale: 0.9,
        survivalTime: 99.0,
        isLeftAlive: true,
        isRightAlive: true,
        inverted: false,
        isLeftAlpha: true,
        isPostSwapGrace: false,
      );
    } else if (gamePairMode == GamePairMode.tideLock) {
      // Attract: the machine breathes on its own — no thumb owns the valve.
      _attractAnimTime += dt;
      final List<TideEvent> tideEvents = _updateTideLock(
        dt: dt,
        valveHeld: false,
        valveAuto: true,
        valveAutoTime: _attractAnimTime,
        subAlive: true,
        buoyAlive: true,
        spawnEnabled: true,
        allowDeaths: false,
        attractPilot: true,
        survivalTime: _attractAnimTime,
        speedScale: 0.9,
      );
      for (final TideEvent event in tideEvents) {
        if (event.type == TideEventType.archCleared) {
          particlePool.spawnBurst(
            origin: event.position,
            count: 8,
            color: SplitPalette.nearMissCyan.withOpacity(0.7),
            speed: 120.0,
          );
        } else if (event.type == TideEventType.bulbFed) {
          particlePool.spawnBurst(
            origin: event.position,
            count: 10,
            color: SplitPalette.goldBright.withOpacity(0.7),
            speed: 130.0,
          );
        }
      }
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
      final double orbLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.orb,
        screenWidth,
      );
      final double orbRight = hemisphereState.getLaneRight(
        HemisphereMechanic.orb,
        screenWidth,
      );
      orb.y = screenHeight * 0.5 + 15.0 * math.sin(countdownTimer * 4.0);
      orb.x = (orbLeft + orbRight) / 2.0;

      final double dartLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.dart,
        screenWidth,
      );
      final double dartRight = hemisphereState.getLaneRight(
        HemisphereMechanic.dart,
        screenWidth,
      );
      dart.x = (dartLeft + dartRight) / 2.0;
      dart.railY = screenHeight * PhysicsConstants.dartDefaultRailYFactor;
    } else if (gamePairMode == GamePairMode.dimensionBreach) {
      dimensionBreach.paddleLeftY = screenHeight * 0.5;
      dimensionBreach.paddleLeftTargetY = screenHeight * 0.5;
      dimensionBreach.paddleRightY = screenHeight * 0.5;
      dimensionBreach.paddleRightTargetY = screenHeight * 0.5;
    } else if (gamePairMode == GamePairMode.tideLock) {
      // Countdown: the machine holds a calm mid-tide with no hazard spawns.
      _attractAnimTime += dt;
      _updateTideLock(
        dt: dt,
        valveHeld: false,
        valveAuto: true,
        valveAutoTime: _attractAnimTime,
        subAlive: true,
        buoyAlive: true,
        spawnEnabled: false,
        allowDeaths: false,
        attractPilot: false,
        survivalTime: 0.0,
        speedScale: 1.0,
      );
      tideLock.setBuoyTargetXFactor(0.5);
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
    deathZoom =
        1.0 + (1.08 - 1.0) * (1.0 - (deathSlowmoTimer / 0.2).clamp(0.0, 1.0));

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
    dimensionBreach.mines.clear();
    tideLock.clearHazardsOnSwap();
    tideLock.setBuoyTargetXFactor(0.5);

    // Cross-translate Pair 1 (Classic)
    final double newOrbLeft = hemisphereState.getLaneLeft(
      HemisphereMechanic.orb,
      screenWidth,
    );
    final double newOrbRight = hemisphereState.getLaneRight(
      HemisphereMechanic.orb,
      screenWidth,
    );
    orb.x = (newOrbLeft + newOrbRight) / 2.0;

    final double newDartLeft = hemisphereState.getLaneLeft(
      HemisphereMechanic.dart,
      screenWidth,
    );
    final double newDartRight = hemisphereState.getLaneRight(
      HemisphereMechanic.dart,
      screenWidth,
    );
    dart.x = (newDartLeft + newDartRight) / 2.0;
    dart.targetX = dart.x;
    _rollingSafeCorridorX = dart.x;

    // Tide Lock: hazards were cleared above; the shared water level, barnacle
    // layout and buoy steering are lane-relative so they translate for free.

    ProceduralAudioSynth.instance.playSwapExecute();
    HapticChoreographer.instance.triggerSwapExecute();
    _addCameraShake(8.0);
  }

  void _updateObstacleSpawners(double dt) {
    // 3.5 second initial runway grace period across ALL game modes: 0 obstacles spawn on start
    if (survivalTime < 3.5) return;

    final double speedScale = survivalTime >= 45.0 ? 1.35 : 1.0;

    if (gamePairMode == GamePairMode.classic) {
      final double orbLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.orb,
        screenWidth,
      );
      final double orbRight = hemisphereState.getLaneRight(
        HemisphereMechanic.orb,
        screenWidth,
      );
      final double dartLeft = hemisphereState.getLaneLeft(
        HemisphereMechanic.dart,
        screenWidth,
      );
      final double dartRight = hemisphereState.getLaneRight(
        HemisphereMechanic.dart,
        screenWidth,
      );

      // --- 1. LASER GATES SPAWNER (Only active if orb is alive) ---
      if (orbAlive) {
        _laserSpawnTimer += dt;
        final double laserInterval = math.max(
          PhysicsConstants.laserGateMinInterval,
          PhysicsConstants.laserGateInitialInterval -
              (survivalTime / 60.0) * 0.9,
        );

        if (_laserSpawnTimer >= laserInterval) {
          _laserSpawnTimer = 0.0;
          final double spawnY = hemisphereState.isPolarityInverted
              ? screenHeight + 20.0
              : -20.0;
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

          if ((!hemisphereState.isPolarityInverted &&
                  gate.y > screenHeight + 40) ||
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
          PhysicsConstants.monolithInitialInterval -
              (survivalTime / 60.0) * 0.37,
        );

        if (_monolithSpawnTimer >= monolithInterval) {
          _monolithSpawnTimer = 0.0;
          final double spawnY = hemisphereState.isPolarityInverted
              ? screenHeight + 40.0
              : -40.0;
          final double fallSpeed =
              (PhysicsConstants.monolithInitialSpeed +
                  (survivalTime / 60.0) *
                      (PhysicsConstants.monolithMaxSpeed -
                          PhysicsConstants.monolithInitialSpeed)) *
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

          if ((!hemisphereState.isPolarityInverted &&
                  m.y > screenHeight + 60) ||
              (hemisphereState.isPolarityInverted && m.y < -60)) {
            monoliths.removeAt(i);
          }
        }
      } else {
        monoliths.clear();
      }
    } else if (gamePairMode == GamePairMode.dimensionBreach) {
      // Dimension Breach manages its own floating hazard mines and ball physics
    } else if (gamePairMode == GamePairMode.tideLock) {
      // Tide Lock self-manages arch / urchin spawn cycles inside TideLockEntity.
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
            orb.y + PhysicsConstants.orbRadius >
                screenHeight - spikeThreshold) {
          _handleHemisphereFailure(
            failedHemisphere:
                hemisphereState.leftMechanic == HemisphereMechanic.orb
                ? 'LEFT'
                : 'RIGHT',
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
              failedHemisphere:
                  hemisphereState.leftMechanic == HemisphereMechanic.orb
                  ? 'LEFT'
                  : 'RIGHT',
              failedMechanic: 'ORB',
              impactPoint: Offset(orb.x, orb.y),
            );
            return;
          }
        }
      }

      // 3. Dart Monoliths Check
      if (dartAlive) {
        final hitboxCircles = dart.getHitboxCircles(
          inverted: hemisphereState.isPolarityInverted,
        );
        for (final m in monoliths) {
          final bool collided = m.checkCollisionWithDartCircles(
            circles: hitboxCircles,
            onNearMiss: () => _handleNearMiss(Offset(dart.x, dart.railY)),
          );
          if (collided) {
            _handleHemisphereFailure(
              failedHemisphere:
                  hemisphereState.leftMechanic == HemisphereMechanic.dart
                  ? 'LEFT'
                  : 'RIGHT',
              failedMechanic: 'DART',
              impactPoint: Offset(dart.x, dart.railY),
            );
            return;
          }
        }
      }
    } else if (gamePairMode == GamePairMode.dimensionBreach) {
      // Dimension Breach collisions and boundary checks are handled dynamically in _processBreachEvents
    } else if (gamePairMode == GamePairMode.tideLock) {
      // Tide Lock collisions emit TideEvents from TideLockEntity.update and
      // are terminalised in _processTideEvents.
    }
  }

  void _handleHemisphereFailure({
    required String failedHemisphere,
    required String failedMechanic,
    required Offset impactPoint,
  }) {
    if (playMode == PlayHandMode.twoHands ||
        gamePairMode == GamePairMode.dimensionBreach) {
      // 2 Hands Mode & Dimension Breach: Any crash terminates run immediately
      _triggerDeath(
        failedHemisphere: failedHemisphere,
        failedMechanic: failedMechanic,
        impactPoint: impactPoint,
      );
    } else {
      // 1 Hand Mode: Eliminate failed side, continue with surviving side
      final bool failureIsLeftOwner =
          failedMechanic == 'ORB' ||
          failedMechanic == 'ZERO-G DEFLECTOR' ||
          failedMechanic == 'TIDE SUB';
      if (failureIsLeftOwner) {
        orbAlive = false;
        laserGates.clear();
        tideLock.clearSubHazards();
      } else {
        dartAlive = false;
        monoliths.clear();
        tideLock.clearBuoyHazards();
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
    currentScore +=
        PhysicsConstants.nearMissBonusPoints * batteryState.scoreMultiplier;
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
          case GamePairMode.dimensionBreach:
            return HemisphereMechanic.breachBeta;
          case GamePairMode.tideLock:
            return HemisphereMechanic.tideHarvester;
        }
      } else if (orbAlive && !dartAlive) {
        switch (gamePairMode) {
          case GamePairMode.classic:
            return HemisphereMechanic.orb;
          case GamePairMode.dimensionBreach:
            return HemisphereMechanic.breachAlpha;
          case GamePairMode.tideLock:
            return HemisphereMechanic.tideSub;
        }
      }
    }
    return isLeft
        ? hemisphereState.leftMechanic
        : hemisphereState.rightMechanic;
  }

  void _processBreachEvents(List<BreachEvent> events) {
    for (final event in events) {
      if (event.scoreDelta > 0.0) {
        currentScore += event.scoreDelta * batteryState.scoreMultiplier;
      }

      switch (event.type) {
        case BreachEventType.breachSuccess:
          nearMissCount++;
          ProceduralAudioSynth.instance.playWarp();
          HapticChoreographer.instance.triggerSwapTick();
          particlePool.spawnBurst(
            origin: event.position,
            count: 14,
            color: SplitPalette.nearMissCyan,
            speed: 160.0,
          );
          particlePool.spawnBurst(
            origin: event.position,
            count: 14,
            color: SplitPalette.hazardCrimson,
            speed: 160.0,
          );
          _addCameraShake(2.0);
          break;

        case BreachEventType.dividerDeflect:
          ProceduralAudioSynth.instance.playTap();
          particlePool.spawnBurst(
            origin: event.position,
            count: 6,
            color: Colors.white,
            speed: 90.0,
          );
          _addCameraShake(1.5);
          break;

        case BreachEventType.leftPaddleHit:
          ProceduralAudioSynth.instance.playShieldPing();
          HapticChoreographer.instance.triggerTap();
          particlePool.spawnBurst(
            origin: event.position,
            count: 10,
            color: SplitPalette.nearMissCyan,
            speed: 130.0,
          );
          _addCameraShake(2.0);
          break;

        case BreachEventType.rightPaddleHit:
          ProceduralAudioSynth.instance.playShieldPing();
          HapticChoreographer.instance.triggerTap();
          particlePool.spawnBurst(
            origin: event.position,
            count: 10,
            color: batteryState.isOverdrive
                ? SplitPalette.overdriveRed
                : SplitPalette.hazardCrimson,
            speed: 130.0,
          );
          _addCameraShake(2.0);
          break;

        case BreachEventType.wallBounce:
          ProceduralAudioSynth.instance.playTap();
          particlePool.spawnBurst(
            origin: event.position,
            count: 5,
            color: Colors.white70,
            speed: 80.0,
          );
          break;

        case BreachEventType.leftMiss:
          final String failedMechanicName =
              hemisphereState.leftMechanic == HemisphereMechanic.breachAlpha
                  ? 'ZERO-G DEFLECTOR'
                  : 'HEAVY-G DEFLECTOR';
          _handleHemisphereFailure(
            failedHemisphere: 'LEFT',
            failedMechanic: failedMechanicName,
            impactPoint: event.position,
          );
          return;

        case BreachEventType.rightMiss:
          final String failedMechanicName =
              hemisphereState.rightMechanic == HemisphereMechanic.breachBeta
                  ? 'HEAVY-G DEFLECTOR'
                  : 'ZERO-G DEFLECTOR';
          _handleHemisphereFailure(
            failedHemisphere: 'RIGHT',
            failedMechanic: failedMechanicName,
            impactPoint: event.position,
          );
          return;
      }
    }
  }

  // Unified Input Routing across dynamic hemisphere swaps
  void handleSidePointerDown(bool isLeft, Offset localPosition) {
    if (state != GamePlayState.playing) return;

    // Dimension Breach: Direct spatial touch binding (Strictly 2-Hands)
    if (gamePairMode == GamePairMode.dimensionBreach) {
      if (isLeft) {
        dimensionBreach.handleLeftInput(localPosition.dy, screenHeight);
      } else {
        dimensionBreach.handleRightInput(localPosition.dy, screenHeight);
      }
      return;
    }

    final mechanic = _resolveTargetMechanic(isLeft);
    if (!isMechanicAlive(mechanic)) return;

    final double laneLeft = hemisphereState.getLaneLeft(mechanic, screenWidth);
    final double laneRight = hemisphereState.getLaneRight(
      mechanic,
      screenWidth,
    );

    final double targetTapX;
    if (playMode == PlayHandMode.oneHand && (!orbAlive || !dartAlive)) {
      final double normalizedX = (localPosition.dx / screenWidth).clamp(
        0.0,
        1.0,
      );
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
          color: (isLeft ? hemisphereState.leftFg : hemisphereState.rightFg)
              .withOpacity(0.5),
          speed: 70.0,
        );
        break;
      case HemisphereMechanic.breachAlpha:
        dimensionBreach.handleLeftInput(localPosition.dy, screenHeight);
        break;
      case HemisphereMechanic.breachBeta:
        dimensionBreach.handleRightInput(localPosition.dy, screenHeight);
        break;
      case HemisphereMechanic.tideSub:
        // The valve is hold-driven via inputRouter thumb state; a fresh press
        // just gives tactile feedback.
        ProceduralAudioSynth.instance.playTap();
        HapticChoreographer.instance.triggerTap();
        break;
      case HemisphereMechanic.dart:
        dart.handleTap(targetTapX, laneLeft: laneLeft, laneRight: laneRight);
        break;
      case HemisphereMechanic.tideHarvester:
        tideLock.setBuoyTargetXFactor(
          ((targetTapX - laneLeft) / (laneRight - laneLeft)).clamp(0.0, 1.0),
        );
        ProceduralAudioSynth.instance.playTap();
        HapticChoreographer.instance.triggerTap();
        break;
    }
  }

  void handleSidePointerMove(bool isLeft, double deltaX, Offset localPosition) {
    if (state != GamePlayState.playing) return;

    // Dimension Breach: Direct spatial touch binding (Strictly 2-Hands)
    if (gamePairMode == GamePairMode.dimensionBreach) {
      if (isLeft) {
        dimensionBreach.handleLeftInput(localPosition.dy, screenHeight);
      } else {
        dimensionBreach.handleRightInput(localPosition.dy, screenHeight);
      }
      return;
    }

    final mechanic = _resolveTargetMechanic(isLeft);
    if (!isMechanicAlive(mechanic)) return;

    final double laneLeft = hemisphereState.getLaneLeft(mechanic, screenWidth);
    final double laneRight = hemisphereState.getLaneRight(
      mechanic,
      screenWidth,
    );

    final double targetTapX;
    if (playMode == PlayHandMode.oneHand && (!orbAlive || !dartAlive)) {
      final double normalizedX = (localPosition.dx / screenWidth).clamp(
        0.0,
        1.0,
      );
      targetTapX = laneLeft + normalizedX * (laneRight - laneLeft);
    } else {
      targetTapX = localPosition.dx;
    }

    switch (mechanic) {
      case HemisphereMechanic.dart:
        dart.handleDragDelta(
          deltaX,
          currentX: targetTapX,
          laneLeft: laneLeft,
          laneRight: laneRight,
        );
        break;
      case HemisphereMechanic.breachAlpha:
        dimensionBreach.handleLeftInput(localPosition.dy, screenHeight);
        break;
      case HemisphereMechanic.breachBeta:
        dimensionBreach.handleRightInput(localPosition.dy, screenHeight);
        break;
      case HemisphereMechanic.tideHarvester:
        tideLock.setBuoyTargetXFactor(
          ((localPosition.dx - laneLeft) / (laneRight - laneLeft)).clamp(
            0.0,
            1.0,
          ),
        );
        break;
      case HemisphereMechanic.tideSub:
      default:
        break;
    }
  }

  void handleLeftAction() => handleSidePointerDown(
    true,
    Offset(screenWidth * 0.25, screenHeight * 0.5),
  );
  void handleRightActionTap(double tapX) =>
      handleSidePointerDown(false, Offset(tapX, screenHeight * 0.5));
  void handleRightActionDrag(double deltaX, double currentX) =>
      handleSidePointerMove(
        false,
        deltaX,
        Offset(currentX, screenHeight * 0.5),
      );
}
