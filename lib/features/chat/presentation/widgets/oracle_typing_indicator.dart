import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Magical typing indicator with pulsing particle effect.
class OracleTypingIndicator extends StatefulWidget {
  final Color color;

  const OracleTypingIndicator({
    super.key,
    this.color = AppColors.secondary,
  });

  @override
  State<OracleTypingIndicator> createState() => _OracleTypingIndicatorState();
}

class _OracleTypingIndicatorState extends State<OracleTypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      3,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Start animations with staggered delay
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Magical orb icon
          _buildMagicOrb(),
          const SizedBox(width: 12),
          // Pulsing dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animations[index],
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    child: Transform.scale(
                      scale: 0.8 + (_animations[index].value * 0.4),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: _animations[index].value),
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: _animations[index].value * 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMagicOrb() {
    return AnimatedBuilder(
      animation: _animations[0],
      builder: (context, child) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withValues(alpha: 0.8),
                widget.color.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animations[0].value * 0.4),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome,
              size: 12,
              color: Colors.white.withValues(alpha: _animations[0].value),
            ),
          ),
        );
      },
    );
  }
}

/// Floating particles around the typing indicator.
class TypingParticles extends StatefulWidget {
  final Color color;

  const TypingParticles({
    super.key,
    this.color = AppColors.secondary,
  });

  @override
  State<TypingParticles> createState() => _TypingParticlesState();
}

class _TypingParticlesState extends State<TypingParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Generate particles
    for (var i = 0; i < 6; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble() * 80,
        y: _random.nextDouble() * 40,
        size: 2 + _random.nextDouble() * 3,
        speed: 0.5 + _random.nextDouble() * 0.5,
        phase: _random.nextDouble() * math.pi * 2,
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(80, 40),
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double phase;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final animatedY = particle.y +
          math.sin((progress * math.pi * 2 * particle.speed) + particle.phase) * 5;
      final opacity = 0.3 + math.sin((progress * math.pi * 2) + particle.phase) * 0.3;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(
        Offset(particle.x, animatedY),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
