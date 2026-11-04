import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum BreachEventType {
  breachSuccess,
  dividerDeflect,
  leftPaddleHit,
  rightPaddleHit,
  wallBounce,
  leftMiss,
  rightMiss,
}

class BreachEvent {
  final BreachEventType type;
  final Offset position;
  final double scoreDelta;

  const BreachEvent({
    required this.type,
    required this.position,
    this.scoreDelta = 0.0,
  });
}

class BreachHazardMine {
  double x;
  double y;
  double vy;
  double radius;
  double pulseAngle;
  bool isDestroyed = false;

  BreachHazardMine({
    required this.x,
    required this.y,
    required this.vy,
    this.radius = 12.0,
    this.pulseAngle = 0.0,
  });

  void update(double dt) {
    y += vy * dt;
    pulseAngle += dt * 3.5;
  }
}

/// The Zero-G Membrane Ping-Pong Entity for Dimension Breach.
///
/// Dual-Hemisphere Mechanics:
/// - Left Realm: Anti-Gravity (accelerates UPWARD)
/// - Right Realm: Heavy Gravity (accelerates DOWNWARD)
/// - Center Divider: Permeable oscillating Breach Aperture
/// - Left & Right Paddles: Smoothly track player touch inputs
class DimensionBreachEntity {
  // Ball state
  double ballX = 0.0;
  double ballY = 0.0;
  double ballVx = 220.0;
  double ballVy = -70.0;
  static const double ballRadius = 12.0;

  // Recent trail positions for glowing comet tail
  final List<Offset> trail = [];

  // Left & Right Paddles
  double paddleLeftY = 300.0;
  double paddleLeftTargetY = 300.0;
  double paddleRightY = 300.0;
  double paddleRightTargetY = 300.0;

  static const double paddleWidth = 14.0;
  static const double paddleHeight = 88.0;

  // Center Slit Window
  double slitY = 400.0;
  double slitHalfHeight = 70.0;
  double slitDirection = 1.0;

  // Hazard Mines
  final List<BreachHazardMine> mines = [];
  double _hazardSpawnTimer = 0.0;

  // Metrics
  int breachCount = 0;
  int volleyCount = 0;

  void reset({
    required double initialLeftX,
    required double initialRightX,
    required double splitX,
    required double screenHeight,
  }) {
    paddleLeftY = screenHeight * 0.5;
    paddleLeftTargetY = screenHeight * 0.5;
    paddleRightY = screenHeight * 0.5;
    paddleRightTargetY = screenHeight * 0.5;

    slitY = screenHeight * 0.5;
    slitHalfHeight = 70.0;
    slitDirection = 1.0;

    // Ball starts on the left side, angled toward the breach slit
    ballX = (initialLeftX + splitX) * 0.5;
    ballY = screenHeight * 0.5;
    ballVx = 220.0;
    ballVy = -70.0;

    trail.clear();
    mines.clear();
    _hazardSpawnTimer = 0.0;
    breachCount = 0;
    volleyCount = 0;
  }

  // Bottom thumb control zone configuration (lower 48% of screen)
  static const double bottomZoneTopFactor = 0.52;
  static const double bottomZoneBottomMargin = 36.0;

  void handleLeftInput(double touchY, double screenHeight) {
    const double minMargin = 60.0;
    final double minPaddleY = minMargin + paddleHeight * 0.5;
    final double maxPaddleY = screenHeight - minMargin - paddleHeight * 0.5;

    final double zoneTop = screenHeight * bottomZoneTopFactor;
    final double zoneBottom = screenHeight - bottomZoneBottomMargin;
    final double zoneHeight = math.max(10.0, zoneBottom - zoneTop);

    // Normalizes touch in the dedicated bottom thumb space (0.0 -> 1.0)
    final double normalizedY =
        ((touchY - zoneTop) / zoneHeight).clamp(0.0, 1.0);
    paddleLeftTargetY = minPaddleY + normalizedY * (maxPaddleY - minPaddleY);
  }

  void handleRightInput(double touchY, double screenHeight) {
    const double minMargin = 60.0;
    final double minPaddleY = minMargin + paddleHeight * 0.5;
    final double maxPaddleY = screenHeight - minMargin - paddleHeight * 0.5;

    final double zoneTop = screenHeight * bottomZoneTopFactor;
    final double zoneBottom = screenHeight - bottomZoneBottomMargin;
    final double zoneHeight = math.max(10.0, zoneBottom - zoneTop);

    // Normalizes touch in the dedicated bottom thumb space (0.0 -> 1.0)
    final double normalizedY =
        ((touchY - zoneTop) / zoneHeight).clamp(0.0, 1.0);
    paddleRightTargetY = minPaddleY + normalizedY * (maxPaddleY - minPaddleY);
  }

  /// Updates physics simulation and returns list of events triggered in this frame.
  List<BreachEvent> update({
    required double dt,
    required double screenWidth,
    required double screenHeight,
    required double splitX,
    required double leftLaneLeft,
    required double leftLaneRight,
    required double rightLaneLeft,
    required double rightLaneRight,
    required double speedScale,
    required double survivalTime,
    required bool isLeftAlive,
    required bool isRightAlive,
    required bool inverted,
    bool isLeftAlpha = true,
    bool isPostSwapGrace = false,
  }) {
    final List<BreachEvent> events = [];

    // Startup Runway grace period (first 3.5s) or post-swap reorientation grace
    final bool isGraceActive = (survivalTime < 3.5) || isPostSwapGrace;
    final double effectiveSpeedScale = isGraceActive ? 0.85 : speedScale;

    // 1. Move Slit Window up and down
    slitY += 110.0 * effectiveSpeedScale * slitDirection * dt;
    final double minSlitY = screenHeight * 0.28;
    final double maxSlitY = screenHeight * 0.72;
    if (slitY > maxSlitY) {
      slitY = maxSlitY;
      slitDirection = -1.0;
    } else if (slitY < minSlitY) {
      slitY = minSlitY;
      slitDirection = 1.0;
    }

    // Dynamic slit height shrinks slightly with speed
    slitHalfHeight = (70.0 - (effectiveSpeedScale - 1.0) * 15.0).clamp(48.0, 75.0);

    // 2. Smoothly damp paddles toward target touch position
    final double smoothFactor = 1.0 - math.exp(-32.0 * dt);
    paddleLeftY =
        ui.lerpDouble(paddleLeftY, paddleLeftTargetY, smoothFactor) ??
        paddleLeftTargetY;
    paddleRightY =
        ui.lerpDouble(paddleRightY, paddleRightTargetY, smoothFactor) ??
        paddleRightTargetY;

    // 3. Gravity Acceleration
    // breachAlpha: Zero-G realm (normally pulls UPWARD)
    // breachBeta: Heavy-G realm (normally pulls DOWNWARD)
    // When inverted (polarity flip), the pull direction flips
    final bool ballOnLeft = ballX < splitX;
    final bool currentSideIsAlpha = ballOnLeft ? isLeftAlpha : !isLeftAlpha;
    final bool pullUpward = currentSideIsAlpha ^ inverted;
    final double gravityMagnitude = 200.0 * effectiveSpeedScale;
    final double g = pullUpward ? -gravityMagnitude : gravityMagnitude;
    ballVy += g * dt;

    // Clamp vertical velocity to avoid runaway speeds
    ballVy = ballVy.clamp(-420.0 * effectiveSpeedScale, 420.0 * effectiveSpeedScale);

    final double prevX = ballX;
    ballX += ballVx * effectiveSpeedScale * dt;
    ballY += ballVy * effectiveSpeedScale * dt;

    // Update trail
    trail.add(Offset(ballX, ballY));
    if (trail.length > 10) {
      trail.removeAt(0);
    }

    // 4. Ceiling & Floor Bouncing
    const double topBound = 54.0;
    final double bottomBound = screenHeight - 24.0;
    if (ballY - ballRadius <= topBound) {
      ballY = topBound + ballRadius;
      ballVy = ballVy.abs() * 0.98;
      events.add(
        BreachEvent(
          type: BreachEventType.wallBounce,
          position: Offset(ballX, ballY),
        ),
      );
    } else if (ballY + ballRadius >= bottomBound) {
      ballY = bottomBound - ballRadius;
      ballVy = -ballVy.abs() * 0.98;
      events.add(
        BreachEvent(
          type: BreachEventType.wallBounce,
          position: Offset(ballX, ballY),
        ),
      );
    }

    // 5. Center Divider Crossing & Breach Slit Collision
    final bool wasLeft = prevX < splitX;
    final bool isNowRight = ballX >= splitX;
    final bool wasRight = prevX >= splitX;
    final bool isNowLeft = ballX < splitX;

    if ((wasLeft && isNowRight) || (wasRight && isNowLeft)) {
      final bool inWindow =
          ballY >= slitY - slitHalfHeight && ballY <= slitY + slitHalfHeight;
      if (inWindow) {
        // Successful breach through membrane!
        breachCount++;
        events.add(
          BreachEvent(
            type: BreachEventType.breachSuccess,
            position: Offset(splitX, ballY),
            scoreDelta: 100.0,
          ),
        );
      } else {
        // Reflected by solid laser wall
        if (wasLeft) {
          ballX = splitX - ballRadius - 1.0;
          ballVx = -ballVx.abs();
        } else {
          ballX = splitX + ballRadius + 1.0;
          ballVx = ballVx.abs();
        }
        events.add(
          BreachEvent(
            type: BreachEventType.dividerDeflect,
            position: Offset(splitX, ballY),
          ),
        );
      }
    }

    // Paddle positions
    final double paddleLeftX = leftLaneLeft + 26.0;
    final double paddleRightX = rightLaneRight - 26.0;

    // 6. Paddle Deflections with generous touch tolerance
    const double hitMargin = 6.0;

    // Left Paddle Deflection (when ball traveling left)
    if (ballVx < 0 &&
        ballX - ballRadius <= paddleLeftX + paddleWidth * 0.5 + 4.0 &&
        ballX + ballRadius >= paddleLeftX - paddleWidth * 0.5 - 4.0) {
      if (isGraceActive && isLeftAlive) {
        // Startup / Post-swap auto-cushion: assist player during orientation
        paddleLeftTargetY = ballY;
        paddleLeftY = ballY;
      }

      if (isLeftAlive &&
          ballY >= paddleLeftY - paddleHeight * 0.5 - ballRadius - hitMargin &&
          ballY <= paddleLeftY + paddleHeight * 0.5 + ballRadius + hitMargin) {
        ballVx = ballVx.abs();
        final double hitFactor =
            ((ballY - paddleLeftY) / (paddleHeight * 0.5)).clamp(-1.0, 1.0);
        ballVy = ballVy * 0.35 + hitFactor * 240.0;
        ballX = paddleLeftX + paddleWidth * 0.5 + ballRadius + 1.0;
        volleyCount++;
        events.add(
          BreachEvent(
            type: BreachEventType.leftPaddleHit,
            position: Offset(paddleLeftX, ballY),
            scoreDelta: 25.0,
          ),
        );
      }
    }

    // Right Paddle Deflection (when ball traveling right)
    if (ballVx > 0 &&
        ballX + ballRadius >= paddleRightX - paddleWidth * 0.5 - 4.0 &&
        ballX - ballRadius <= paddleRightX + paddleWidth * 0.5 + 4.0) {
      if (isGraceActive && isRightAlive) {
        // Startup / Post-swap auto-cushion: assist player during orientation
        paddleRightTargetY = ballY;
        paddleRightY = ballY;
      }

      if (isRightAlive &&
          ballY >= paddleRightY - paddleHeight * 0.5 - ballRadius - hitMargin &&
          ballY <= paddleRightY + paddleHeight * 0.5 + ballRadius + hitMargin) {
        ballVx = -ballVx.abs();
        final double hitFactor =
            ((ballY - paddleRightY) / (paddleHeight * 0.5)).clamp(-1.0, 1.0);
        ballVy = ballVy * 0.35 + hitFactor * 240.0;
        ballX = paddleRightX - paddleWidth * 0.5 - ballRadius - 1.0;
        volleyCount++;
        events.add(
          BreachEvent(
            type: BreachEventType.rightPaddleHit,
            position: Offset(paddleRightX, ballY),
            scoreDelta: 25.0,
          ),
        );
      }
    }

    // 7. Out of Bounds Check (Missing Paddle)
    if (ballX < paddleLeftX - 16.0) {
      if (isGraceActive) {
        // Safety net during initial 3.5s startup or post-swap grace
        ballX = paddleLeftX + paddleWidth * 0.5 + ballRadius;
        ballVx = ballVx.abs();
        paddleLeftY = ballY;
        paddleLeftTargetY = ballY;
        events.add(
          BreachEvent(
            type: BreachEventType.leftPaddleHit,
            position: Offset(paddleLeftX, ballY),
            scoreDelta: 10.0,
          ),
        );
      } else {
        events.add(
          BreachEvent(
            type: BreachEventType.leftMiss,
            position: Offset(ballX, ballY),
          ),
        );
      }
    } else if (ballX > paddleRightX + 16.0) {
      if (isGraceActive) {
        // Safety net during initial 3.5s startup or post-swap grace
        ballX = paddleRightX - paddleWidth * 0.5 - ballRadius;
        ballVx = -ballVx.abs();
        paddleRightY = ballY;
        paddleRightTargetY = ballY;
        events.add(
          BreachEvent(
            type: BreachEventType.rightPaddleHit,
            position: Offset(paddleRightX, ballY),
            scoreDelta: 10.0,
          ),
        );
      } else {
        events.add(
          BreachEvent(
            type: BreachEventType.rightMiss,
            position: Offset(ballX, ballY),
          ),
        );
      }
    }

    // 8. Hazard Mines Update & Collisions (Only spawn after startup runway)
    if (survivalTime >= 4.0) {
      _hazardSpawnTimer += dt;
      if (_hazardSpawnTimer >= 3.2) {
        _hazardSpawnTimer = 0.0;
        if (mines.length < 2) {
          final bool spawnLeft = math.Random().nextBool();
          final double mx = spawnLeft
              ? leftLaneLeft + (leftLaneRight - leftLaneLeft) * (0.35 + math.Random().nextDouble() * 0.3)
              : rightLaneLeft + (rightLaneRight - rightLaneLeft) * (0.35 + math.Random().nextDouble() * 0.3);
          mines.add(
            BreachHazardMine(
              x: mx,
              y: -20.0,
              vy: 80.0 * effectiveSpeedScale,
            ),
          );
        }
      }

      for (int i = mines.length - 1; i >= 0; i--) {
        final mine = mines[i];
        mine.update(dt);
        if (mine.y > screenHeight + 30.0 || mine.isDestroyed) {
          mines.removeAt(i);
          continue;
        }

        // Ball vs Mine collision
        final double dx = mine.x - ballX;
        final double dy = mine.y - ballY;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist < mine.radius + ballRadius) {
          mine.isDestroyed = true;
          // Dynamic deflection
          ballVx = -ballVx * 1.05;
          ballVy = -ballVy + (math.Random().nextDouble() - 0.5) * 80.0;
          events.add(
            BreachEvent(
              type: BreachEventType.dividerDeflect,
              position: Offset(mine.x, mine.y),
              scoreDelta: 50.0,
            ),
          );
        }
      }
    }

    return events;
  }
}
