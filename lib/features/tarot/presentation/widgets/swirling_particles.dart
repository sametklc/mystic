import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Particles that swirl around a central point.
class SwirlingParticles extends StatefulWidget {
  /// Number of particles.
  final int particleCount;

  /// Radius of the swirl.
  final double radius;

  /// Speed multiplier.
  final double speed;

  /// Center offset from widget center.
  final Offset centerOffset;

  /// Whether particles are active.
  final bool isActive;

  const SwirlingParticles({
    super.key,
    this.particleCount = 30,
    this.radius = 150,
    this.speed = 1.0,
    this.centerOffset = Offset.zero,
    this.isActive = true,
  });

  @override
  State<SwirlingParticles> createState() => _SwirlingParticlesState();
}

class _SwirlingParticlesState extends State<SwirlingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initParticles();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  void _initParticles() {
    _particles = List.generate(widget.particleCount, (index) {
      return _Particle(
        angle: _random.nextDouble() * math.pi * 2,
        distance: widget.radius * 0.5 + _random.nextDouble() * widget.radius * 0.5,
        size: 2 + _random.nextDouble() * 4,
        speed: 0.5 + _random.nextDouble() * 1.0,
        color: _getRandomColor(),
        orbitOffset: _random.nextDouble() * math.pi * 2,
        wobble: _random.nextDouble() * 20,
      );
    });
  }

  Color _getRandomColor() {
    final colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.secondary,
      AppColors.secondaryLight,
      AppColors.mysticTeal,
      Colors.white,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _SwirlingParticlesPainter(
            particles: _particles,
            progress: _controller.value,
            speed: widget.speed,
            centerOffset: widget.centerOffset,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  double angle;
  final double distance;
  final double size;
  final double speed;
  final Color color;
  final double orbitOffset;
  final double wobble;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
    required this.color,
    required this.orbitOffset,
    required this.wobble,
  });
}

class _SwirlingParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double speed;
  final Offset centerOffset;

  _SwirlingParticlesPainter({
    required this.particles,
    required this.progress,
    required this.speed,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + centerOffset;

    for (final particle in particles) {
      // Calculate current angle based on progress
      final currentAngle = particle.angle +
          (progress * math.pi * 2 * particle.speed * speed) +
          particle.orbitOffset;

      // Add wobble effect
      final wobbleOffset = math.sin(progress * math.pi * 4 + particle.orbitOffset) *
          particle.wobble;

      // Calculate position
      final distance = particle.distance + wobbleOffset;
      final x = center.dx + math.cos(currentAngle) * distance;
      final y = center.dy + math.sin(currentAngle) * distance;

      // Calculate opacity based on distance from center
      final normalizedDistance = distance / (particles.first.distance * 1.5);
      final opacity = (1.0 - normalizedDistance * 0.3).clamp(0.3, 1.0);

      // Draw particle with glow
      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(Offset(x, y), particle.size, paint);

      // Draw core
      final corePaint = Paint()
        ..color = particle.color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), particle.size * 0.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwirlingParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Mystical text that cycles through different messages.
class CyclingMysticalText extends StatefulWidget {
  /// List of messages to cycle through.
  final List<String> messages;

  /// Duration to show each message.
  final Duration displayDuration;

  /// Duration of fade transition.
  final Duration fadeDuration;

  /// Text style.
  final TextStyle? style;

  const CyclingMysticalText({
    super.key,
    required this.messages,
    this.displayDuration = const Duration(seconds: 3),
    this.fadeDuration = const Duration(milliseconds: 500),
    this.style,
  });

  @override
  State<CyclingMysticalText> createState() => _CyclingMysticalTextState();
}

class _CyclingMysticalTextState extends State<CyclingMysticalText>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );

    _fadeController.forward();
    _startCycle();
  }

  void _startCycle() async {
    while (mounted) {
      await Future.delayed(widget.displayDuration);
      if (!mounted) return;

      // Fade out
      await _fadeController.reverse();
      if (!mounted) return;

      // Change text
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.messages.length;
      });

      // Fade in
      await _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Text(
        widget.messages[_currentIndex],
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}
