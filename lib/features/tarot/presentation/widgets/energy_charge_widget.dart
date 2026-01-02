import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/constants.dart';

/// Callback when energy charging is complete.
typedef OnChargeComplete = void Function();

/// Ritualistic energy charge mechanic for tarot card selection.
/// User holds to channel energy, deck bursts open after 3 seconds.
class EnergyChargeWidget extends StatefulWidget {
  final OnChargeComplete onChargeComplete;
  final Duration chargeDuration;

  const EnergyChargeWidget({
    super.key,
    required this.onChargeComplete,
    this.chargeDuration = const Duration(seconds: 3),
  });

  @override
  State<EnergyChargeWidget> createState() => _EnergyChargeWidgetState();
}

class _EnergyChargeWidgetState extends State<EnergyChargeWidget>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _chargeController;
  late AnimationController _shakeController;
  late AnimationController _glowPulseController;
  late AnimationController _burstController;

  // Animations
  late Animation<double> _chargeProgress;
  late Animation<double> _glowOpacity;
  late Animation<double> _shakeIntensity;

  // State
  bool _isCharging = false;
  bool _isComplete = false;
  bool _isBursting = false;

  // Haptic timer
  Timer? _hapticTimer;
  int _hapticLevel = 0;

  // Particles
  final List<_EnergyParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Main charge progress (0 to 1 over 3 seconds)
    _chargeController = AnimationController(
      vsync: this,
      duration: widget.chargeDuration,
    );

    _chargeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chargeController, curve: Curves.easeInOut),
    );

    // Glow opacity animation (0.2 to 1.0)
    _glowOpacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _chargeController, curve: Curves.easeIn),
    );

    // Shake intensity animation (increases with charge)
    _shakeIntensity = Tween<double>(begin: 0.5, end: 8.0).animate(
      CurvedAnimation(parent: _chargeController, curve: Curves.easeIn),
    );

    // Shake controller (continuous oscillation)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..repeat(reverse: true);

    // Glow pulse controller (subtle pulsing effect)
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Burst animation controller
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Listen for charge completion
    _chargeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isComplete) {
        _onChargeComplete();
      }
    });

    // Update particles during charge
    _chargeController.addListener(_updateParticles);
  }

  void _updateParticles() {
    if (!_isCharging) return;

    final progress = _chargeProgress.value;

    // Add new particles based on charge level
    final particleCount = (progress * 3).toInt() + 1;
    for (int i = 0; i < particleCount; i++) {
      if (_particles.length < 50) {
        _particles.add(_EnergyParticle(
          angle: _random.nextDouble() * 2 * math.pi,
          distance: 60 + _random.nextDouble() * 40,
          size: 2 + _random.nextDouble() * 4,
          opacity: 0.5 + _random.nextDouble() * 0.5,
          isGold: _random.nextBool(),
          speed: 0.5 + _random.nextDouble() * 1.5,
        ));
      }
    }

    // Update and remove dead particles
    _particles.removeWhere((p) {
      p.life -= 0.02;
      return p.life <= 0;
    });

    setState(() {});
  }

  void _startCharging() {
    if (_isComplete || _isBursting) return;

    setState(() {
      _isCharging = true;
      _particles.clear();
    });

    _chargeController.forward(from: 0);
    _startHapticFeedback();
  }

  void _stopCharging() {
    if (_isComplete || _isBursting) return;

    setState(() {
      _isCharging = false;
      _particles.clear();
    });

    _chargeController.stop();
    _chargeController.reset();
    _stopHapticFeedback();
  }

  void _startHapticFeedback() {
    _hapticLevel = 0;

    // Start with light impacts
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isCharging) {
        timer.cancel();
        return;
      }

      final progress = _chargeProgress.value;

      // Escalate haptic intensity based on progress
      if (progress < 0.33) {
        // Light impacts (first third)
        if (_hapticLevel != 1) {
          _hapticLevel = 1;
        }
        HapticFeedback.lightImpact();
      } else if (progress < 0.66) {
        // Medium impacts (second third)
        if (_hapticLevel != 2) {
          _hapticLevel = 2;
        }
        HapticFeedback.mediumImpact();
      } else {
        // Heavy impacts (final third) - faster
        if (_hapticLevel != 3) {
          _hapticLevel = 3;
          timer.cancel();
          _hapticTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
            if (!_isCharging) {
              t.cancel();
              return;
            }
            HapticFeedback.mediumImpact();
          });
        }
      }
    });
  }

  void _stopHapticFeedback() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
  }

  void _onChargeComplete() {
    setState(() {
      _isComplete = true;
      _isBursting = true;
    });

    _stopHapticFeedback();

    // Heavy impact for completion
    HapticFeedback.heavyImpact();

    // Short delay then another heavy impact
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });

    // Start burst animation
    _burstController.forward().then((_) {
      // Notify parent after burst animation
      widget.onChargeComplete();
    });
  }

  @override
  void dispose() {
    _chargeController.dispose();
    _shakeController.dispose();
    _glowPulseController.dispose();
    _burstController.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBursting) {
      return _buildBurstAnimation();
    }

    return GestureDetector(
      onLongPressStart: (_) => _startCharging(),
      onLongPressEnd: (_) => _stopCharging(),
      onLongPressCancel: () => _stopCharging(),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _chargeController,
          _shakeController,
          _glowPulseController,
        ]),
        builder: (context, child) {
          // Calculate shake offset
          final shakeOffset = _isCharging
              ? Offset(
                  (_shakeController.value - 0.5) * 2 * _shakeIntensity.value,
                  (_random.nextDouble() - 0.5) * _shakeIntensity.value,
                )
              : Offset.zero;

          // Calculate glow intensity
          final baseGlow = _isCharging ? _glowOpacity.value : 0.2;
          final pulseGlow = _glowPulseController.value * 0.1;
          final totalGlow = (baseGlow + pulseGlow).clamp(0.0, 1.0);

          return SizedBox(
            width: double.infinity,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Energy particles
                if (_isCharging) ..._buildParticles(),

                // Outer glow ring
                _buildGlowRing(totalGlow),

                // Deck with shake effect
                Transform.translate(
                  offset: shakeOffset,
                  child: _buildDeck(totalGlow),
                ),

                // Progress indicator
                if (_isCharging) _buildProgressRing(),

                // Prompt text
                Positioned(
                  bottom: 20,
                  child: _buildPromptText(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildParticles() {
    return _particles.map((particle) {
      final x = math.cos(particle.angle) * particle.distance * particle.life;
      final y = math.sin(particle.angle) * particle.distance * particle.life;

      return Positioned(
        left: 150 + x - particle.size / 2,
        top: 120 + y - particle.size / 2,
        child: Container(
          width: particle.size,
          height: particle.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (particle.isGold ? AppColors.secondary : AppColors.primary)
                .withOpacity(particle.opacity * particle.life),
            boxShadow: [
              BoxShadow(
                color:
                    (particle.isGold ? AppColors.secondary : AppColors.primary)
                        .withOpacity(0.5 * particle.life),
                blurRadius: particle.size * 2,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildGlowRing(double glowIntensity) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primary.withOpacity(glowIntensity * 0.3),
            AppColors.secondary.withOpacity(glowIntensity * 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(glowIntensity * 0.4),
            blurRadius: 40 + glowIntensity * 30,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: AppColors.secondary.withOpacity(glowIntensity * 0.3),
            blurRadius: 60 + glowIntensity * 40,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildDeck(double glowIntensity) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Card stack (multiple cards stacked)
        for (int i = 0; i < 5; i++)
          Transform.translate(
            offset: Offset(i * 2.0, -i * 2.0),
            child: Transform.rotate(
              angle: (i - 2) * 0.02,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2A1B3D),
                      const Color(0xFF1A0F2E),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3 + glowIntensity * 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(2, 4),
                    ),
                    if (_isCharging)
                      BoxShadow(
                        color: AppColors.primary.withOpacity(glowIntensity * 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withOpacity(glowIntensity),
                        AppColors.secondary.withOpacity(glowIntensity),
                      ],
                    ).createShader(bounds),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 40,
                      color: Colors.white.withOpacity(glowIntensity),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: _ChargeProgressPainter(
          progress: _chargeProgress.value,
          color: AppColors.primary,
          secondaryColor: AppColors.secondary,
        ),
      ),
    );
  }

  Widget _buildPromptText() {
    final text = _isCharging
        ? 'Channeling energy...'
        : 'Hold to channel your energy';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        key: ValueKey(text),
        style: AppTypography.bodyMedium.copyWith(
          color: _isCharging ? AppColors.primary : AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    ).animate(target: _isCharging ? 1 : 0).shimmer(
          color: AppColors.primaryLight.withOpacity(0.5),
          duration: 1500.ms,
        );
  }

  Widget _buildBurstAnimation() {
    return AnimatedBuilder(
      animation: _burstController,
      builder: (context, child) {
        final progress = _burstController.value;
        final scale = 1.0 + progress * 0.5;
        final opacity = 1.0 - progress;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Expanding burst ring
            Transform.scale(
              scale: 1.0 + progress * 3,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(opacity * 0.8),
                    width: 4 * (1 - progress),
                  ),
                ),
              ),
            ),

            // Second burst ring (delayed)
            if (progress > 0.2)
              Transform.scale(
                scale: 1.0 + (progress - 0.2) * 2.5,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(opacity * 0.6),
                      width: 3 * (1 - progress),
                    ),
                  ),
                ),
              ),

            // Central flash
            Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        AppColors.primary.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Flying cards (bursting outward)
            for (int i = 0; i < 7; i++)
              _buildBurstingCard(i, progress),
          ],
        );
      },
    );
  }

  Widget _buildBurstingCard(int index, double progress) {
    final angle = (index * 2 * math.pi / 7) - math.pi / 2;
    final distance = progress * 200;
    final rotation = progress * math.pi * 0.5;
    final opacity = 1.0 - progress * 0.5;

    return Transform.translate(
      offset: Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance,
      ),
      child: Transform.rotate(
        angle: rotation + index * 0.3,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: 60,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2A1B3D),
                  const Color(0xFF1A0F2E),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Represents an energy particle in the charging effect.
class _EnergyParticle {
  final double angle;
  final double distance;
  final double size;
  final double opacity;
  final bool isGold;
  final double speed;
  double life;

  _EnergyParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.opacity,
    required this.isGold,
    required this.speed,
    this.life = 1.0,
  });
}

/// Custom painter for the circular progress indicator.
class _ChargeProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color secondaryColor;

  _ChargeProgressPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color, secondaryColor, color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      progressPaint,
    );

    // Glow effect on the leading edge
    if (progress > 0) {
      final glowAngle = -math.pi / 2 + progress * 2 * math.pi;
      final glowPoint = Offset(
        center.dx + radius * math.cos(glowAngle),
        center.dy + radius * math.sin(glowAngle),
      );

      final glowPaint = Paint()
        ..color = secondaryColor.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(glowPoint, 6, glowPaint);

      // Bright center
      final brightPaint = Paint()..color = Colors.white;
      canvas.drawCircle(glowPoint, 3, brightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChargeProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
