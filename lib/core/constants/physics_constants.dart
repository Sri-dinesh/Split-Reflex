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

  // Tide Lock Mechanic — shared water valve
  static const double tideRiseRate = 0.40; // level/s while valve is held open
  static const double tideDrainRate = 0.50; // level/s while valve is released
  static const double tideSurfaceBaseFactor = 0.840; // surface y at level 0 (780-space: 655)
  static const double tideSurfaceRangeFactor = 0.647; // level 1 lift (780-space: 505)
  static const double tideSubOffsetFactor = 0.059; // hull rides 46/780 below the surface

  // Tide Lock — submarine arches (sub lane)
  static const double tideArchDepthMinFactor = 0.526; // 410/780
  static const double tideArchDepthMaxFactor = 0.641; // 500/780
  static const double tideArchWidthFactor = 0.27; // of lane width (48/178)
  static const double tideArchInitialInterval = 2.40; // seconds
  static const double tideArchMinInterval = 1.55;
  static const double tideArchSpeedBase = 56.0; // px/s in 780-space
  static const double tideArchSpeedGain = 0.70; // px/s of ramp per second survived
  static const double tideArchSpeedCap = 46.0;
  static const double tideArchHullMarginFactor = 0.056; // hull half-width margin (10/178, lane-relative)
  static const double tideArchPassMarginFactor = 0.08;
  static const double tideCollisionSlack = 8.0; // px of forgiveness below arch lip

  // Tide Lock — harvester buoy (buoy lane)
  static const double tideBuoySpeedFactor = 0.32; // of screen height per second (250/780)
  static const double tideBuoyRadiusFactor = 0.012;
  static const double tideBuoyMinXFactor = 0.06; // steering clamp from lane edges
  static const double tideBulbDepth1 = 0.205; // 160/780
  static const double tideBulbDepth2 = 0.276; // 215/780
  static const double tideBulbDepth3 = 0.353; // 275/780
  static const double tideBulbDepth4 = 0.442; // 345/780
  static const double tideBulbFeedRadiusFactor = 0.033; // 26/780 touch radius
  static const double tideBulbSwayFactor = 0.028; // stem sway as lane-width factor
  static const double tideBulbMinXFactor = 0.11; // spawn clamp from lane edges
  static const double tideArchClearedPoints = 45.0;
  static const double tideBulbFedPoints = 30.0;

  // Tide Lock — urchin patrol (buoy lane)
  static const double tideUrchinInitialInterval = 1.60;
  static const double tideUrchinMinInterval = 0.90;
  static const double tideUrchinSpeedBase = 30.0; // px/s in 780-space
  static const double tideUrchinSpeedRange = 32.0;
  static const double tideUrchinYMinFactor = 0.372; // 290/780
  static const double tideUrchinYMaxFactor = 0.846; // 660/780
  static const double tideUrchinRadiusFactor = 0.012;
  static const double tideNearMissClearance = 28.0; // px of sub-to-lip clearance for a near miss


  // Scoring
  static const double nearMissDistanceThreshold = 12.0;
  static const int nearMissBonusPoints = 250;
  static const double basePointsPerSecond = 100.0;
}
