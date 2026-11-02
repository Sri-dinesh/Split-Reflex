class PhysicsConstants {
  // Master Loop
  static const double maxDeltaTime = 0.033; // 33ms clamp

  // Orb Mechanic
  static const double orbRadius = 14.0;
  static const double orbDefaultGravity = 980.0; // px/s²
  static const double orbJumpImpulse = -360.0; // px/s
  static const double orbHorizontalSpeed = 130.0; // px/s
  static const int orbTrailLength = 12;
  static const double orbSquashDuration = 0.12; // 120ms

  // Dart Mechanic
  static const double dartWidth = 28.0;
  static const double dartHeight = 34.0;
  static const double dartDefaultRailYFactor = 0.85; // 85% of screen height
  static const double dartInvertedRailYFactor = 0.15; // 15% of screen height
  static const double dartTrackingSpeed = 28.0; // Lerp exponential rate
  static const double dartBankAngleClamp = 0.40; // radians
  static const double dartTouchSensitivity = 1.25;

  // Obstacle Specifications - Laser Gates
  static const double laserGateGapWidth = 72.0;
  static const double laserGateSpeed = 160.0;
  static const double laserGateInitialInterval = 2.2;
  static const double laserGateMinInterval = 1.3;
  static const double laserOscillationSpeed = 60.0;

  // Obstacle Specifications - Monoliths
  static const double monolithInitialSpeed = 340.0;
  static const double monolithMaxSpeed = 620.0;
  static const double monolithInitialInterval = 0.65;
  static const double monolithMinInterval = 0.28;
  static const double monolithSafeCorridorMaxShift = 0.45;

  // Spikes
  static const double spikeBaseHeight = 14.0;
  static const double spikePulseHeight = 18.0;
  static const double spikeStep = 16.0;

  // Mutation Timeline
  static const double mutationInterval = 15.0; // seconds
  static const double swapWarningDuration = 2.0;
  static const double swapTransitionDuration = 0.35; // 350ms

  // Scoring
  static const double nearMissDistanceThreshold = 12.0;
  static const int nearMissBonusPoints = 250;
  static const double basePointsPerSecond = 100.0;
}
