import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'cosmic_particle.dart';

/// High-performance custom painter for rendering cosmic particles.
/// Uses efficient painting techniques for smooth 60fps animation.
class CosmicPainter extends CustomPainter {
  final List<CosmicParticle> particles;
  final double time;
  final bool enableGlow;

  // Pre-allocated paint objects for performance
  final Paint _starPaint = Paint()..style = PaintingStyle.fill;
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _nebulaPaint = Paint()
    ..style = PaintingStyle.fill
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

  CosmicPainter({
    required this.particles,
    required this.time,
    this.enableGlow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw particles from back to front (by depth)
    // Particles are already sorted by depth when created
    for (final particle in particles) {
      _drawParticle(canvas, particle);
    }
  }

  void _drawParticle(Canvas canvas, CosmicParticle particle) {
    final opacity = particle.getOpacity(time);
    final radius = particle.getRadius(time);
    final position = Offset(particle.x, particle.y);

    switch (particle.type) {
      case ParticleType.dust:
        _drawDust(canvas, position, radius, opacity, particle.color);
        break;
      case ParticleType.star:
        _drawStar(canvas, position, radius, opacity, particle.color);
        break;
      case ParticleType.glowingStar:
        _drawGlowingStar(canvas, position, radius, opacity, particle.color);
        break;
      case ParticleType.nebulaDust:
        _drawNebulaDust(canvas, position, radius, opacity, particle.color);
        break;
    }
  }

  /// Draw a simple dust particle
  void _drawDust(
    Canvas canvas,
    Offset position,
    double radius,
    double opacity,
    Color color,
  ) {
    _starPaint.color = color.withOpacity(opacity);
    canvas.drawCircle(position, radius, _starPaint);
  }

  /// Draw a small bright star
  void _drawStar(
    Canvas canvas,
    Offset position,
    double radius,
    double opacity,
    Color color,
  ) {
    // Core
    _starPaint.color = Colors.white.withOpacity(opacity);
    canvas.drawCircle(position, radius * 0.5, _starPaint);

    // Outer glow
    _starPaint.color = color.withOpacity(opacity * 0.6);
    canvas.drawCircle(position, radius, _starPaint);
  }

  /// Draw a larger star with glow effect
  void _drawGlowingStar(
    Canvas canvas,
    Offset position,
    double radius,
    double opacity,
    Color color,
  ) {
    if (enableGlow) {
      // Outer glow (soft)
      _glowPaint.color = color.withOpacity(opacity * 0.3);
      canvas.drawCircle(position, radius * 2, _glowPaint);

      // Middle glow
      _glowPaint.color = color.withOpacity(opacity * 0.5);
      canvas.drawCircle(position, radius * 1.2, _glowPaint);
    }

    // Core (bright white)
    _starPaint.color = Colors.white.withOpacity(opacity);
    canvas.drawCircle(position, radius * 0.4, _starPaint);

    // Inner colored ring
    _starPaint.color = color.withOpacity(opacity * 0.8);
    canvas.drawCircle(position, radius * 0.6, _starPaint);

    // Draw subtle cross flare for brightest stars
    if (opacity > 0.7 && radius > 3) {
      _drawStarFlare(canvas, position, radius, opacity, color);
    }
  }

  /// Draw star flare (cross shape)
  void _drawStarFlare(
    Canvas canvas,
    Offset position,
    double radius,
    double opacity,
    Color color,
  ) {
    final flarePaint = Paint()
      ..color = color.withOpacity(opacity * 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final flareLength = radius * 3;

    // Horizontal line
    canvas.drawLine(
      Offset(position.dx - flareLength, position.dy),
      Offset(position.dx + flareLength, position.dy),
      flarePaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(position.dx, position.dy - flareLength),
      Offset(position.dx, position.dy + flareLength),
      flarePaint,
    );
  }

  /// Draw soft nebula-like dust
  void _drawNebulaDust(
    Canvas canvas,
    Offset position,
    double radius,
    double opacity,
    Color color,
  ) {
    // Create radial gradient for smooth falloff
    final gradient = ui.Gradient.radial(
      position,
      radius,
      [
        color.withOpacity(opacity * 0.4),
        color.withOpacity(opacity * 0.1),
        color.withOpacity(0),
      ],
      [0.0, 0.5, 1.0],
    );

    _nebulaPaint.shader = gradient;
    canvas.drawCircle(position, radius, _nebulaPaint);
  }

  @override
  bool shouldRepaint(CosmicPainter oldDelegate) {
    // Always repaint for animation
    return oldDelegate.time != time;
  }
}

/// Painter for the gradient background layer
class GradientBackgroundPainter extends CustomPainter {
  final List<Color> colors;
  final List<double>? stops;
  final Offset center;
  final double radius;

  GradientBackgroundPainter({
    required this.colors,
    this.stops,
    this.center = const Offset(0.5, 0.3),
    this.radius = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerPoint = Offset(
      size.width * center.dx,
      size.height * center.dy,
    );
    final gradientRadius = size.longestSide * radius;

    final gradient = ui.Gradient.radial(
      centerPoint,
      gradientRadius,
      colors,
      stops,
    );

    final paint = Paint()..shader = gradient;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(GradientBackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors ||
        oldDelegate.stops != stops ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius;
  }
}

/// Painter for subtle noise texture overlay
class NoisePainter extends CustomPainter {
  final double opacity;
  final int seed;

  NoisePainter({
    this.opacity = 0.03,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Create a subtle noise pattern using points
    // This is a simplified noise - for production, use an image asset
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    final random = _SeededRandom(seed);
    final density = (size.width * size.height / 800).clamp(100, 2000).toInt();

    for (var i = 0; i < density; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final pointOpacity = random.nextDouble() * opacity;
      paint.color = Colors.white.withOpacity(pointOpacity);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(NoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.seed != seed;
  }
}

/// Simple seeded random for consistent noise pattern
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}
