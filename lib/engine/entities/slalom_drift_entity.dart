import 'dart:math' as math;

class SlalomPylon {
  double x;
  double y;
  final double radius;
  final double speed;

  SlalomPylon({
    required this.x,
    required this.y,
    this.radius = 12.0,
    required this.speed,
  });
}

class SlalomDriftEntity {
  double x = 0.0;
  double y = 0.0;
  double targetX = 0.0;
  double chasmPhase = 0.0;
  double tiltAngle = 0.0;

  void reset({required double initialX, required double initialY}) {
    x = initialX;
    y = initialY;
    targetX = initialX;
    chasmPhase = 0.0;
    tiltAngle = 0.0;
  }

  void update({
    required double dt,
    required double laneLeft,
    required double laneRight,
    required double screenHeight,
    required bool isGyro,
  }) {
    chasmPhase += dt * 2.2;

    // Follow targetX smoothly
    final double trackingSpeed = isGyro ? 36.0 : 26.0;
    final double prevX = x;
    x += (targetX - x) * math.min(1.0, dt * trackingSpeed);
    x = x.clamp(laneLeft + 14.0, laneRight - 14.0);

    final double vx = (x - prevX) / math.max(0.001, dt);
    tiltAngle = (vx * 0.0018).clamp(-0.45, 0.45);
  }

  /// Calculates safe chasm center at vertical position testY with smooth startup runway
  double getChasmCenter(double testY, double laneLeft, double laneRight, {double introFactor = 1.0}) {
    final double laneWidth = laneRight - laneLeft;
    final double midX = (laneLeft + laneRight) / 2.0;
    // introFactor smoothly curves from 0.0 (straight highway) to 1.0 (winding chasm)
    final double amplitude = (laneWidth * 0.28).clamp(16.0, 75.0) * introFactor;
    return midX + amplitude * math.sin((testY * 0.005) + chasmPhase);
  }

  /// Safe width of the chasm channel (with gentle extra margin during intro)
  double getChasmWidth(double laneWidth, {double introFactor = 1.0}) {
    final double bonus = (1.0 - introFactor).clamp(0.0, 1.0) * 22.0;
    return (laneWidth * 0.54).clamp(76.0, 165.0) + bonus;
  }
}
