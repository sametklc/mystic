import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/constants.dart';

/// A breathtaking splash screen for the Mystic app.
/// This is not just a loading screen - it's a transition into a spiritual experience.
class MysticSplashScreen extends StatefulWidget {
  /// Callback when the splash animation completes.
  final VoidCallback onComplete;

  /// Duration to show the splash screen (default: 4 seconds)
  final Duration duration;

  const MysticSplashScreen({
    super.key,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 4000),
  });

  @override
  State<MysticSplashScreen> createState() => _MysticSplashScreenState();
}

class _MysticSplashScreenState extends State<MysticSplashScreen>
    with TickerProviderStateMixin {
  // Mystical phrases that cycle during loading
  static const List<String> _mysticalPhrases = [
    'Awakening the cosmos...',
    'Aligning your stars...',
    'Opening the portal...',
    'The universe awaits...',
  ];

  int _currentPhraseIndex = 0;
  bool _hasCompleted = false;

  late AnimationController _starFieldController;
  late AnimationController _phraseController;
  late AnimationController _fadeOutController;

  // Random star positions (generated once)
  late List<_StarData> _stars;

  @override
  void initState() {
    super.initState();

    // Generate random stars
    _stars = List.generate(80, (index) => _StarData.random());

    // Star field rotation controller
    _starFieldController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    // Phrase cycling controller
    _phraseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _currentPhraseIndex =
                (_currentPhraseIndex + 1) % _mysticalPhrases.length;
          });
          _phraseController.forward(from: 0);
        }
      });
    _phraseController.forward();

    // Fade out controller
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Auto-complete after specified duration
    Future.delayed(widget.duration, _onSplashComplete);
  }

  @override
  void dispose() {
    _starFieldController.dispose();
    _phraseController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  void _onSplashComplete() {
    if (!mounted || _hasCompleted) return;
    _hasCompleted = true;

    HapticFeedback.mediumImpact();

    // Fade out then call callback
    _fadeOutController.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeOutController,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _fadeOutController.value,
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Layer 1: Deep cosmic gradient background
            _buildCosmicBackground(),

            // Layer 2: Animated star field
            _buildStarField(),

            // Layer 3: Nebula glow overlay
            _buildNebulaOverlay(),

            // Layer 4: Main content (Logo + Text)
            _buildMainContent(),

            // Layer 5: Mystical phrases at bottom
            _buildMysticalPhrases(),

            // Layer 6: Vignette effect
            _buildVignette(),
          ],
        ),
      ),
    );
  }

  /// Deep cosmic gradient from midnight blue to deep violet
  Widget _buildCosmicBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D0D2B), // Midnight Blue
            Color(0xFF1A0A2E), // Deep Violet
            Color(0xFF0F0F1F), // Dark Purple-Black
            Color(0xFF050510), // Near Black
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
    );
  }

  /// Animated star field with twinkling stars
  Widget _buildStarField() {
    return AnimatedBuilder(
      animation: _starFieldController,
      builder: (context, child) {
        return CustomPaint(
          painter: _StarFieldPainter(
            stars: _stars,
            rotation: _starFieldController.value * 2 * math.pi * 0.02,
            time: _starFieldController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  /// Subtle nebula glow overlay
  Widget _buildNebulaOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Purple nebula glow (top-right)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.2, 1.2),
                  duration: 8.seconds,
                  curve: Curves.easeInOut,
                )
                .fadeIn(duration: 2.seconds),

            // Gold nebula glow (bottom-left)
            Positioned(
              bottom: -150,
              left: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.15, 1.15),
                  duration: 6.seconds,
                  curve: Curves.easeInOut,
                )
                .fadeIn(duration: 2.seconds, delay: 500.ms),
          ],
        ),
      ),
    );
  }

  /// Main content: Logo and mystical elements with animations
  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mystical Icon
          _buildMysticIcon(),

          const SizedBox(height: 30),

          // Title
          Text(
            'MYSTIC',
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.primary,
              letterSpacing: 12,
              shadows: [
                Shadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 20,
                ),
                Shadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 40,
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms, delay: 400.ms)
              .slideY(begin: -0.3, end: 0, curve: Curves.easeOutBack)
              .then()
              .shimmer(
                duration: 2.seconds,
                color: AppColors.primaryLight.withOpacity(0.3),
              ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Your Cosmic Journey Awaits',
            style: AppTypography.mysticalQuote.copyWith(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 800.ms)
              .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  /// Animated mystical icon (eye/moon symbol)
  Widget _buildMysticIcon() {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring with glow
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.05, 1.05),
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),

          // Inner ring
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.4),
                width: 1.5,
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 20.seconds),

          // Center eye/moon icon
          Icon(
            Icons.remove_red_eye_outlined,
            size: 50,
            color: AppColors.primary,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1))
              .then()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.1, 1.1),
                duration: 1500.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 2.seconds,
                color: AppColors.primaryLight.withOpacity(0.5),
              ),

          // Orbiting dots
          ..._buildOrbitingDots(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), curve: Curves.easeOutBack);
  }

  List<Widget> _buildOrbitingDots() {
    return List.generate(3, (index) {
      final delay = index * 0.33;
      return Positioned.fill(
        child: Transform.rotate(
          angle: index * (2 * math.pi / 3),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 8.seconds, begin: delay, end: delay + 1);
    });
  }

  /// Cycling mystical phrases
  Widget _buildMysticalPhrases() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _mysticalPhrases[_currentPhraseIndex],
            key: ValueKey<int>(_currentPhraseIndex),
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 1500.ms);
  }

  /// Subtle vignette effect for cinematic feel
  Widget _buildVignette() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.5, 0.8, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Data class for individual star
class _StarData {
  final double x; // 0.0 to 1.0
  final double y; // 0.0 to 1.0
  final double size;
  final double twinkleSpeed;
  final double twinkleOffset;
  final double brightness;

  _StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.twinkleOffset,
    required this.brightness,
  });

  factory _StarData.random() {
    final random = math.Random();
    return _StarData(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: random.nextDouble() * 2.5 + 0.5,
      twinkleSpeed: random.nextDouble() * 2 + 1,
      twinkleOffset: random.nextDouble() * 2 * math.pi,
      brightness: random.nextDouble() * 0.5 + 0.5,
    );
  }
}

/// Custom painter for the star field
class _StarFieldPainter extends CustomPainter {
  final List<_StarData> stars;
  final double rotation;
  final double time;

  _StarFieldPainter({
    required this.stars,
    required this.rotation,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final star in stars) {
      // Calculate twinkle
      final twinkle = (math.sin(time * star.twinkleSpeed * 2 * math.pi + star.twinkleOffset) + 1) / 2;
      final opacity = star.brightness * (0.3 + twinkle * 0.7);

      // Calculate position with subtle rotation
      final dx = (star.x - 0.5) * size.width;
      final dy = (star.y - 0.5) * size.height;
      final rotatedX = dx * math.cos(rotation) - dy * math.sin(rotation);
      final rotatedY = dx * math.sin(rotation) + dy * math.cos(rotation);

      final position = Offset(
        center.dx + rotatedX,
        center.dy + rotatedY,
      );

      // Skip if out of bounds
      if (position.dx < 0 ||
          position.dx > size.width ||
          position.dy < 0 ||
          position.dy > size.height) {
        continue;
      }

      // Draw star with glow
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, star.size * 0.5);

      canvas.drawCircle(position, star.size, paint);

      // Draw core (brighter center)
      final corePaint = Paint()
        ..color = Colors.white.withOpacity(opacity * 1.2);
      canvas.drawCircle(position, star.size * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
