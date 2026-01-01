import 'dart:math';
import 'dart:ui';

/// Represents a single cosmic particle (star/dust) in the atmosphere.
/// Optimized for performance with pre-calculated values.
class CosmicParticle {
  // Position
  double x;
  double y;

  // Movement
  final double baseSpeedX;
  final double baseSpeedY;
  final double driftAmplitude;
  final double driftFrequency;
  final double driftPhase;

  // Appearance
  final double baseRadius;
  final double baseOpacity;
  final double twinkleSpeed;
  final double twinklePhase;
  final ParticleType type;
  final Color color;

  // Parallax layer (0.0 = far/slow, 1.0 = near/fast)
  final double depth;

  CosmicParticle({
    required this.x,
    required this.y,
    required this.baseSpeedX,
    required this.baseSpeedY,
    required this.driftAmplitude,
    required this.driftFrequency,
    required this.driftPhase,
    required this.baseRadius,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.twinklePhase,
    required this.type,
    required this.color,
    required this.depth,
  });

  /// Factory to create a random cosmic particle
  factory CosmicParticle.random({
    required Random random,
    required Size bounds,
    required List<Color> colors,
  }) {
    final type = ParticleType.values[random.nextInt(ParticleType.values.length)];
    final depth = random.nextDouble();

    // Deeper particles are smaller, slower, and dimmer
    final depthFactor = 0.3 + (depth * 0.7);

    return CosmicParticle(
      x: random.nextDouble() * bounds.width,
      y: random.nextDouble() * bounds.height,
      baseSpeedX: (random.nextDouble() - 0.5) * 0.3 * depthFactor,
      baseSpeedY: -0.1 - random.nextDouble() * 0.2 * depthFactor, // Drift upward
      driftAmplitude: 0.5 + random.nextDouble() * 1.5,
      driftFrequency: 0.5 + random.nextDouble() * 1.5,
      driftPhase: random.nextDouble() * pi * 2,
      baseRadius: _getRadiusForType(type, random) * depthFactor,
      baseOpacity: _getOpacityForType(type, random) * depthFactor,
      twinkleSpeed: 0.5 + random.nextDouble() * 2.0,
      twinklePhase: random.nextDouble() * pi * 2,
      type: type,
      color: colors[random.nextInt(colors.length)],
      depth: depth,
    );
  }

  static double _getRadiusForType(ParticleType type, Random random) {
    switch (type) {
      case ParticleType.dust:
        return 0.5 + random.nextDouble() * 1.0;
      case ParticleType.star:
        return 1.0 + random.nextDouble() * 2.0;
      case ParticleType.glowingStar:
        return 2.0 + random.nextDouble() * 3.0;
      case ParticleType.nebulaDust:
        return 3.0 + random.nextDouble() * 5.0;
    }
  }

  static double _getOpacityForType(ParticleType type, Random random) {
    switch (type) {
      case ParticleType.dust:
        return 0.2 + random.nextDouble() * 0.3;
      case ParticleType.star:
        return 0.5 + random.nextDouble() * 0.4;
      case ParticleType.glowingStar:
        return 0.7 + random.nextDouble() * 0.3;
      case ParticleType.nebulaDust:
        return 0.1 + random.nextDouble() * 0.15;
    }
  }

  /// Update particle position based on time
  void update(double time, Size bounds) {
    // Apply drift motion (sinusoidal)
    final driftX = sin(time * driftFrequency + driftPhase) * driftAmplitude;

    x += baseSpeedX + driftX * 0.1;
    y += baseSpeedY;

    // Wrap around screen edges
    if (x < -10) x = bounds.width + 10;
    if (x > bounds.width + 10) x = -10;
    if (y < -10) y = bounds.height + 10;
    if (y > bounds.height + 10) y = -10;
  }

  /// Get current opacity with twinkle effect
  double getOpacity(double time) {
    final twinkle = sin(time * twinkleSpeed + twinklePhase);
    final twinkleFactor = 0.7 + twinkle * 0.3;
    return (baseOpacity * twinkleFactor).clamp(0.0, 1.0);
  }

  /// Get current radius with subtle pulsing
  double getRadius(double time) {
    if (type == ParticleType.glowingStar) {
      final pulse = sin(time * twinkleSpeed * 0.5 + twinklePhase);
      return baseRadius * (0.9 + pulse * 0.2);
    }
    return baseRadius;
  }
}

/// Types of cosmic particles with different visual characteristics
enum ParticleType {
  /// Tiny, dim dust particles
  dust,

  /// Small bright stars
  star,

  /// Larger stars with glow effect
  glowingStar,

  /// Soft, diffuse nebula-like dust
  nebulaDust,
}
