import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/physics_constants.dart';

/// Events emitted by the Tide Lock pair during [TideLockEntity.update].
enum TideEventType {
  /// An arch was successfully cleared by the sub (score event).
  archCleared,

  /// A barnacle bulb was fed to the harvester buoy (score event).
  bulbFed,

  /// The submarine rammed a hanging arch (terminal for the sub hemisphere).
  subCrushed,

  /// The harvester buoy was stung by a patrolling urchin (terminal for the
  /// harvester hemisphere).
  buoyStung,

  /// The sub shaved past an arch with almost no clearance (near-miss bonus).
  subNearMiss,
}

class TideEvent {
  final TideEventType type;
  final Offset position;

  const TideEvent({required this.type, required this.position});
}

/// A hanging stone arch the submarine must dive under.
///
/// Horizontal position is stored as a factor of the **lane width** it travels
/// in, so hemisphere swaps that rescale lanes stay consistent for free.
class TideArch {
  double xFactor;
  double bottomY;
  double widthFactor;

  /// -1.0 = travels toward the lane's outer edge, +1.0 = toward the divider.
  double direction;
  bool scored;
  bool nearMissed;

  TideArch({
    required this.xFactor,
    required this.bottomY,
    required this.widthFactor,
    required this.direction,
  }) : scored = false,
       nearMissed = false;
}

/// A barnacle bulb dangling on a stem at a fixed depth. Feeds the buoy only
/// while the shared tide lifts the water high enough to touch it.
class TideBarnacle {
  double xFactor;
  double depthY;
  final double phase;
  double swayFactor;

  TideBarnacle({
    required this.xFactor,
    required this.depthY,
    required this.phase,
  }) : swayFactor = 0.0;
}

/// A patrolling urchin roaming the water column between the surface rigs.
class TideUrchin {
  double xFactor;
  double y;
  double vxFactor;
  double radius;
  double spinPhase;

  TideUrchin({
    required this.xFactor,
    required this.y,
    required this.vxFactor,
    required this.radius,
    required this.spinPhase,
  });
}

/// Tide Lock — the device has ONE shared water level and two opposite tenants.
///
/// The tide level is owned here and survives mutations, hemisphere swaps and
/// even the death of the valve mechanic (in 1-Hand mode the tide then breathes
/// autonomously so the surviving harvester keeps a fair game).
///
/// All horizontal state is stored as a factor of the travelling lane's width
/// ([0..1] where 0 = outer edge boundary of the original lane and 1 = divider
/// edge on fresh assignment), which makes cross-translation during swaps a
/// no-op: the same factor squares into the new lane geometry.
class TideLockEntity {
  TideLockEntity({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  // Shared tide state (0 = bone dry basin floor, 1 = full flood at 0.192H).
  double level = 0.4;
  bool valveOpen = false;

  // Live surface geometry, refreshed every update.
  double surfaceY = 0.0;
  double subY = 0.0;
  double buoyY = 0.0;

  // Sub lane elements.
  final List<TideArch> arches = [];
  double _archTimer = 2.2;

  // Buoy lane elements.
  final List<TideBarnacle> barnacles = [];
  final List<TideUrchin> urchins = [];
  double _urchinTimer = 1.9;

  // Buoy horizontal steering (factor of the buoy lane width).
  double buoyXFactor = 0.5;
  double buoyTargetXFactor = 0.5;

  /// Installs the entity for a fresh run / attract session.
  void reset({required double screenHeight, required double initialLevel}) {
    level = initialLevel;
    arches.clear();
    urchins.clear();
    _archTimer = 2.2;
    _urchinTimer = 1.9;

    barnacles.clear();
    final List<double> depthFactors = [
      PhysicsConstants.tideBulbDepth1,
      PhysicsConstants.tideBulbDepth2,
      PhysicsConstants.tideBulbDepth3,
      PhysicsConstants.tideBulbDepth4,
    ];
    for (int i = 0; i < depthFactors.length; i++) {
      barnacles.add(
        TideBarnacle(
          xFactor: PhysicsConstants.tideBulbMinXFactor +
              i * ((1.0 - 2 * PhysicsConstants.tideBulbMinXFactor) / 3.0),
          depthY: screenHeight * depthFactors[i],
          phase: i * 1.7,
        ),
      );
    }
    _reshuffleBarnacleOrder(screenHeight);

    buoyXFactor = 0.5;
    buoyTargetXFactor = 0.5;
    _refreshSurfaceGeometry(screenHeight);
  }

  /// Deterministically balanced barnacle depth spread for a fresh layout.
  void _reshuffleBarnacleOrder(double screenHeight) {
    final List<double> depths = barnacles.map((b) => b.depthY).toList()
      ..shuffle(_rng);
    for (int i = 0; i < barnacles.length && i < depths.length; i++) {
      barnacles[i].depthY = depths[i];
    }
  }

  /// Player steers the buoy by holding the desired horizontal station.
  void setBuoyTargetXFactor(double factor) {
    buoyTargetXFactor = factor.clamp(
      PhysicsConstants.tideBuoyMinXFactor,
      1.0 - PhysicsConstants.tideBuoyMinXFactor,
    );
  }

  void clearSubHazards() => arches.clear();
  void clearBuoyHazards() => urchins.clear();

  /// Clears every hazard but preserves tide level, barnacles and steering —
  /// used by the mutation swap so the shared water stays continuous.
  void clearHazardsOnSwap() {
    arches.clear();
    urchins.clear();
    _archTimer = 1.6;
    _urchinTimer = 1.4;
  }

  /// Surface y for a given tide level on a screen of [screenHeight] tall.
  static double surfaceYFor(double level, double screenHeight) =>
      screenHeight *
      (PhysicsConstants.tideSurfaceBaseFactor -
          PhysicsConstants.tideSurfaceRangeFactor * level.clamp(0.0, 1.0));

  void _refreshSurfaceGeometry(double screenHeight) {
    surfaceY = surfaceYFor(level, screenHeight);
    subY = surfaceY + screenHeight * PhysicsConstants.tideSubOffsetFactor;
    buoyY = surfaceY;
  }

  /// Advances the whole pair one frame.
  ///
  /// [subLaneWidth] / [buoyLaneWidth] are the pixel widths of the lanes the
  /// sub / buoy mechanics currently occupy; [subLaneLeft] / [buoyLaneLeft]
  /// are their absolute on-screen left edges (used to emit event positions).
  List<TideEvent> update({
    required double dt,
    required double screenHeight,
    required double subLaneLeft,
    required double subLaneWidth,
    required double buoyLaneLeft,
    required double buoyLaneWidth,
    required bool subIsLeft,
    required bool subActive,
    required bool buoyActive,
    required bool valveHeld,
    required bool valveAuto,
    required double valveAutoTime,
    required bool inverted,
    required bool spawnEnabled,
    required bool allowDeaths,
    required bool attractPilot,
    required double survivalTime,
    required double speedScale,
  }) {
    final List<TideEvent> events = <TideEvent>[];

    // ---- 1. The shared valve -------------------------------------------
    if (valveAuto) {
      // No thumb owns the valve (attract mode or 1-Hand after the valve
      // hemisphere fell): the tide breathes on a slow autonomous swell.
      level = 0.50 + 0.35 * math.sin(valveAutoTime * 0.55);
    } else {
      final double openRate = inverted
          ? PhysicsConstants.tideDrainRate
          : PhysicsConstants.tideRiseRate;
      final double closeRate = inverted
          ? PhysicsConstants.tideRiseRate
          : PhysicsConstants.tideDrainRate;
      final double rate = valveHeld ? openRate : -closeRate;
      level = (level + rate * dt).clamp(0.0, 1.0);
    }
    valveOpen = valveAuto ? level < 0.5 : valveHeld;
    _refreshSurfaceGeometry(screenHeight);

    // ---- 2. Left mechanic: valve + submarine vs hanging arches ----------
    if (subActive) {
      if (spawnEnabled) {
        _archTimer -= dt;
        if (_archTimer <= 0.0) {
          _archTimer = math.max(
            PhysicsConstants.tideArchMinInterval,
            PhysicsConstants.tideArchInitialInterval - survivalTime * 0.012,
          );
          // Arches approach from the divider side and drift outwards —
          // mirrored depending on which hemisphere currently hosts the sub.
          final double direction = subIsLeft ? -1.0 : 1.0;
          arches.add(
            TideArch(
              xFactor: subIsLeft ? 1.06 : -0.06,
              bottomY:
                  screenHeight *
                  (PhysicsConstants.tideArchDepthMinFactor +
                      _rng.nextDouble() *
                          (PhysicsConstants.tideArchDepthMaxFactor -
                              PhysicsConstants.tideArchDepthMinFactor)),
              widthFactor:
                  PhysicsConstants.tideArchWidthFactor *
                  (0.9 + _rng.nextDouble() * 0.25),
              direction: direction,
            ),
          );
        }
      }

      final double archSpeed =
          (PhysicsConstants.tideArchSpeedBase +
              math.min(
                PhysicsConstants.tideArchSpeedCap,
                survivalTime * PhysicsConstants.tideArchSpeedGain,
              )) *
          speedScale;

      final double subXFactor = 0.5;
      for (int i = arches.length - 1; i >= 0; i--) {
        final TideArch arch = arches[i];
        arch.xFactor += arch.direction * (archSpeed * dt) / subLaneWidth;

        // Despawn well outside the lane.
        if (arch.xFactor < -0.30 || arch.xFactor > 1.30) {
          arches.removeAt(i);
          continue;
        }

        final double clearance = arch.bottomY - subY;

        // Score: arch fully passed the sub's station.
        if (!arch.scored) {
          final bool passed = arch.direction < 0
              ? arch.xFactor <
                    subXFactor -
                        arch.widthFactor / 2.0 -
                        PhysicsConstants.tideArchPassMarginFactor
              : arch.xFactor >
                    subXFactor +
                        arch.widthFactor / 2.0 +
                        PhysicsConstants.tideArchPassMarginFactor;
          if (passed) {
            arch.scored = true;
            events.add(
              TideEvent(
                type: TideEventType.archCleared,
                position: Offset(
                  subLaneLeft + subXFactor * subLaneWidth,
                  subY,
                ),
              ),
            );
            if (clearance < PhysicsConstants.tideNearMissClearance &&
                clearance > 0.0) {
              arch.nearMissed = true;
              events.add(
                const TideEvent(type: TideEventType.subNearMiss, position: Offset.zero),
              );
            }
          }
        }

        // Collision: hull overlaps the arch span while riding too high.
        if (allowDeaths && !arch.scored) {
          final bool spanOverlap =
              (arch.xFactor - subXFactor).abs() <
              arch.widthFactor / 2.0 +
                  PhysicsConstants.tideArchHullMarginFactor;
          if (spanOverlap && subY < arch.bottomY + PhysicsConstants.tideCollisionSlack) {
            events.add(
              TideEvent(
                type: TideEventType.subCrushed,
                position: Offset(
                  subLaneLeft +
                      arch.xFactor.clamp(0.0, 1.0) * subLaneWidth,
                  subY,
                ),
              ),
            );
            arches.removeAt(i);
            continue;
          }
        }
      }
    } else if (arches.isNotEmpty) {
      arches.clear();
    }

    // ---- 3. Right mechanic: harvester buoy -----------------------------
    if (buoyActive) {
      // Attract pilot: drift toward the juiciest bulb for the demo reel.
      if (attractPilot) {
        TideBarnacle? best;
        double bestScore = double.negativeInfinity;
        for (final TideBarnacle b in barnacles) {
          final double score = -b.depthY +
              surfaceY * 2.0; // prefer depths closest to current surface
          if (score > bestScore) {
            bestScore = score;
            best = b;
          }
        }
        setBuoyTargetXFactor(best?.xFactor ?? 0.5);
      }

      // Steering chase (converted to pixels of the buoy's current lane).
      final double buoySpeed =
          screenHeight * PhysicsConstants.tideBuoySpeedFactor;
      final double maxStep = (buoySpeed * dt) / buoyLaneWidth;
      final double delta = buoyTargetXFactor - buoyXFactor;
      buoyXFactor += delta.clamp(-maxStep, maxStep);

      // Barnacle feeding.
      final double feedRadius =
          screenHeight * PhysicsConstants.tideBulbFeedRadiusFactor;
      for (final TideBarnacle bulb in barnacles) {
        bulb.swayFactor =
            math.sin(survivalTime * 1.8 + bulb.phase) *
            PhysicsConstants.tideBulbSwayFactor;

        final double bx = (bulb.xFactor + bulb.swayFactor) * buoyLaneWidth;
        final double buoyX = buoyXFactor * buoyLaneWidth;
        final double dist = math.sqrt(
          math.pow(bx - buoyX, 2) + math.pow(bulb.depthY - buoyY, 2),
        );
        if (dist < feedRadius) {
          events.add(
            TideEvent(
              type: TideEventType.bulbFed,
              position: Offset(buoyLaneLeft + bx, bulb.depthY),
            ),
          );
          _respawnBarnacle(bulb, screenHeight);
        }
      }

      // Urchin patrols.
      if (spawnEnabled) {
        _urchinTimer -= dt;
        if (_urchinTimer <= 0.0) {
          _urchinTimer = math.max(
            PhysicsConstants.tideUrchinMinInterval,
            PhysicsConstants.tideUrchinInitialInterval - survivalTime * 0.010,
          );
          final bool fromOuterEdge = _rng.nextBool();
          urchins.add(
            TideUrchin(
              xFactor: fromOuterEdge ? -0.08 : 1.08,
              y: screenHeight *
                  (PhysicsConstants.tideUrchinYMinFactor +
                      _rng.nextDouble() *
                          (PhysicsConstants.tideUrchinYMaxFactor -
                              PhysicsConstants.tideUrchinYMinFactor)),
              vxFactor: 0.0, // resolved against lane width below
              radius: screenHeight * PhysicsConstants.tideUrchinRadiusFactor,
              spinPhase: _rng.nextDouble() * math.pi * 2,
            ),
          );
          final double speedPx =
              (PhysicsConstants.tideUrchinSpeedBase +
                  _rng.nextDouble() *
                      PhysicsConstants.tideUrchinSpeedRange) *
              speedScale;
          urchins.last.vxFactor =
              (fromOuterEdge ? 1.0 : -1.0) * speedPx / buoyLaneWidth;
        }
      }

      final double buoyRadius =
          screenHeight * PhysicsConstants.tideBuoyRadiusFactor;
      for (int i = urchins.length - 1; i >= 0; i--) {
        final TideUrchin urchin = urchins[i];
        urchin.xFactor += urchin.vxFactor * dt;
        urchin.spinPhase += dt * 2.4;
        urchin.y += math.sin(urchin.spinPhase * 1.7) * 6.0 * dt;

        if (urchin.xFactor < -0.18 || urchin.xFactor > 1.18) {
          urchins.removeAt(i);
          continue;
        }

        if (allowDeaths) {
          final double dx = (urchin.xFactor - buoyXFactor) * buoyLaneWidth;
          final double dy = urchin.y - buoyY;
          final double dist = math.sqrt(dx * dx + dy * dy);
          if (dist < urchin.radius + buoyRadius) {
            events.add(
              TideEvent(
                type: TideEventType.buoyStung,
                position: Offset(
                  buoyLaneLeft +
                      buoyXFactor.clamp(0.0, 1.0) * buoyLaneWidth,
                  buoyY,
                ),
              ),
            );
            urchins.removeAt(i);
            continue;
          }
        }
      }
    } else if (urchins.isNotEmpty) {
      urchins.clear();
    }

    return events;
  }

  /// Respawns a fed bulb at a free station not currently touched by the tide
  /// (prevents instant re-feed while the buoy hovers on its old depth).
  void _respawnBarnacle(TideBarnacle bulb, double screenHeight) {
    const double minX = PhysicsConstants.tideBulbMinXFactor;
    const double maxX = 1.0 - minX;
    bulb.xFactor = minX + _rng.nextDouble() * (maxX - minX);

    const List<double> slots = [
      PhysicsConstants.tideBulbDepth1,
      PhysicsConstants.tideBulbDepth2,
      PhysicsConstants.tideBulbDepth3,
      PhysicsConstants.tideBulbDepth4,
    ];
    double feedRadius =
        screenHeight * PhysicsConstants.tideBulbFeedRadiusFactor;
    double chosen = slots[_rng.nextInt(slots.length)];
    for (int attempt = 0; attempt < 4; attempt++) {
      if ((screenHeight * chosen - buoyY).abs() > feedRadius * 1.6) break;
      chosen = slots[_rng.nextInt(slots.length)];
    }
    bulb.depthY = screenHeight * chosen;
  }
}
