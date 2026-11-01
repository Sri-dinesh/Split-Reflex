/// Deterministic, fair pseudo-random generator with guaranteed solvability corridors.
class SeededRng {
  int _state;

  SeededRng([int? seed]) : _state = seed ?? DateTime.now().microsecondsSinceEpoch;

  /// Returns random double in range [0.0, 1.0)
  double nextDouble() {
    // 32-bit LCG
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }

  /// Returns random double in range [min, max]
  double nextDoubleInRange(double min, double max) {
    return min + nextDouble() * (max - min);
  }

  /// Returns random integer in range [min, max] inclusive
  int nextIntInRange(int min, int max) {
    return min + (nextDouble() * (max - min + 1)).floor();
  }

  /// Guaranteed solvability corridor calculation for Dart falling monoliths.
  /// Shifts previous safe corridor center by at most [maxShiftPercent] * laneWidth.
  double getNextSafeCorridor({
    required double prevCorridorX,
    required double laneLeft,
    required double laneRight,
    double maxShiftPercent = 0.45,
    double corridorWidth = 60.0,
  }) {
    final double laneWidth = laneRight - laneLeft;
    final double maxShift = laneWidth * maxShiftPercent;

    final double shift = (nextDouble() * 2.0 - 1.0) * maxShift;
    double newX = prevCorridorX + shift;

    // Clamp safe corridor so Dart has enough room
    final double halfW = corridorWidth / 2.0;
    final double minX = laneLeft + halfW + 10.0;
    final double maxX = laneRight - halfW - 10.0;

    if (minX >= maxX) {
      return (laneLeft + laneRight) / 2.0;
    }

    return newX.clamp(minX, maxX);
  }
}
