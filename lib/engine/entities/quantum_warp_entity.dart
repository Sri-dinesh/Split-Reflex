import 'dart:math' as math;

enum QuantumTrack { left, right }

class QuantumBlockade {
  double y;
  final QuantumTrack track;
  final double height;
  final double speed;

  QuantumBlockade({
    required this.y,
    required this.track,
    this.height = 36.0,
    required this.speed,
  });
}

class QuantumWarpEntity {
  QuantumTrack track = QuantumTrack.left;
  double y = 0.0;
  double warpAnim = 1.0; // 0.0 -> 1.0 when hopping tracks
  double currentX = 0.0;
  double targetX = 0.0;

  void reset({required double railY, required double trackLeftX}) {
    track = QuantumTrack.left;
    y = railY;
    warpAnim = 1.0;
    currentX = trackLeftX;
    targetX = trackLeftX;
  }

  void warp() {
    track = track == QuantumTrack.left ? QuantumTrack.right : QuantumTrack.left;
    warpAnim = 0.0;
  }

  void update(double dt, double trackLeftX, double trackRightX) {
    targetX = track == QuantumTrack.left ? trackLeftX : trackRightX;
    currentX += (targetX - currentX) * math.min(1.0, dt * 28.0);
    if (warpAnim < 1.0) {
      warpAnim = math.min(1.0, warpAnim + dt * 10.0);
    }
  }
}
