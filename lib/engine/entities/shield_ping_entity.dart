import 'dart:math' as math;

class PlasmaBolt {
  double y;
  final double speed;
  bool deflected = false;

  PlasmaBolt({
    required this.y,
    required this.speed,
  });
}

class ShieldPingEntity {
  double y = 0.0;
  double shieldPulse = 0.0; // 0.0 -> 1.0 expansion ring
  bool isDeflecting = false;
  double comboCount = 0;

  void reset({required double baselineY}) {
    y = baselineY;
    shieldPulse = 0.0;
    isDeflecting = false;
    comboCount = 0;
  }

  void triggerPing() {
    isDeflecting = true;
    shieldPulse = 1.0;
  }

  void update(double dt) {
    if (shieldPulse > 0.0) {
      shieldPulse = math.max(0.0, shieldPulse - dt * 3.5);
      if (shieldPulse <= 0.0) {
        isDeflecting = false;
      }
    }
  }
}
