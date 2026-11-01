import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pre-allocated struct for zero heap allocations during high-frequency particle emission.
class ProceduralParticle {
  bool active = false;
  double x = 0.0;
  double y = 0.0;
  double vx = 0.0;
  double vy = 0.0;
  double angle = 0.0;
  double vAngle = 0.0;
  double size = 4.0;
  int sides = 4; // 2 = spark line, 3 = triangle, 4 = rect
  double alpha = 1.0;
  double decay = 2.0; // alpha decay per second
  Color color = Colors.white;

  void reset() {
    active = false;
    x = 0.0;
    y = 0.0;
    vx = 0.0;
    vy = 0.0;
    angle = 0.0;
    vAngle = 0.0;
    size = 4.0;
    sides = 4;
    alpha = 1.0;
    decay = 2.0;
    color = Colors.white;
  }
}

class ParticlePool {
  static const int poolCapacity = 200;
  final List<ProceduralParticle> particles = List.generate(
    poolCapacity,
    (_) => ProceduralParticle(),
    growable: false,
  );

  final math.Random _rng = math.Random();

  void update(double dt) {
    for (int i = 0; i < poolCapacity; i++) {
      final p = particles[i];
      if (!p.active) continue;

      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.angle += p.vAngle * dt;
      p.alpha -= p.decay * dt;

      if (p.alpha <= 0.0) {
        p.active = false;
      }
    }
  }

  void spawnBurst({
    required Offset origin,
    required int count,
    required Color color,
    required double speed,
    int? sides,
    double spreadAngle = math.pi * 2,
    double baseAngle = 0.0,
  }) {
    int spawned = 0;
    for (int i = 0; i < poolCapacity && spawned < count; i++) {
      final p = particles[i];
      if (p.active) continue;

      final double angle = baseAngle + (_rng.nextDouble() * spreadAngle - spreadAngle / 2);
      final double spd = speed * (0.4 + _rng.nextDouble() * 0.8);

      p.active = true;
      p.x = origin.dx;
      p.y = origin.dy;
      p.vx = math.cos(angle) * spd;
      p.vy = math.sin(angle) * spd;
      p.angle = _rng.nextDouble() * math.pi * 2;
      p.vAngle = (_rng.nextDouble() - 0.5) * 12.0;
      p.size = 3.0 + _rng.nextDouble() * 5.0;
      p.sides = sides ?? (_rng.nextBool() ? 3 : 4);
      p.alpha = 1.0;
      p.decay = 1.5 + _rng.nextDouble() * 2.0;
      p.color = color;

      spawned++;
    }
  }

  void spawnDartThruster({
    required Offset origin,
    required Color color,
    required bool inverted,
  }) {
    // Spawn 2 square exhaust particles per frame
    int spawned = 0;
    final double dirY = inverted ? -1.0 : 1.0;

    for (int i = 0; i < poolCapacity && spawned < 2; i++) {
      final p = particles[i];
      if (p.active) continue;

      p.active = true;
      p.x = origin.dx + (_rng.nextDouble() * 6.0 - 3.0);
      p.y = origin.dy;
      p.vx = (_rng.nextDouble() * 40.0 - 20.0);
      p.vy = dirY * (80.0 + _rng.nextDouble() * 90.0);
      p.angle = 0.0;
      p.vAngle = 0.0;
      p.size = 2.5 + _rng.nextDouble() * 2.5;
      p.sides = 4;
      p.alpha = 0.85;
      p.decay = 4.5;
      p.color = color;

      spawned++;
    }
  }

  void clear() {
    for (int i = 0; i < poolCapacity; i++) {
      particles[i].active = false;
    }
  }
}
