import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/constants.dart';
import '../../../tarot/data/tarot_deck_assets.dart';
import '../../data/providers/daily_tarot_provider.dart';

/// Cinematic full-screen overlay for revealing the daily tarot card.
///
/// Shows a dramatic spinning animation followed by the card reveal
/// and interpretation text fade-in.
class TarotRevealOverlay extends StatefulWidget {
  final DailyTarot dailyTarot;
  final VoidCallback onClose;

  const TarotRevealOverlay({
    super.key,
    required this.dailyTarot,
    required this.onClose,
  });

  /// Show the overlay as a modal route
  static Future<void> show(BuildContext context, DailyTarot dailyTarot) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return TarotRevealOverlay(
            dailyTarot: dailyTarot,
            onClose: () => Navigator.of(context).pop(),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<TarotRevealOverlay> createState() => _TarotRevealOverlayState();
}

class _TarotRevealOverlayState extends State<TarotRevealOverlay>
    with TickerProviderStateMixin {
  late AnimationController _shuffleController;
  late AnimationController _flipController;
  late AnimationController _glowController;

  bool _showInterpretation = false;
  bool _isRevealed = false;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();

    // Shuffle/spin animation (2.5 seconds)
    _shuffleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Flip animation (800ms)
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _startRevealSequence();
  }

  Future<void> _startRevealSequence() async {
    // Start with haptic feedback
    HapticFeedback.mediumImpact();

    // Phase 1: Shuffle/spin animation
    _glowController.repeat(reverse: true);
    await _shuffleController.forward();

    // Brief pause for suspense
    await Future.delayed(const Duration(milliseconds: 200));

    // Phase 2: Flip to reveal
    HapticFeedback.heavyImpact();
    await _flipController.forward();

    setState(() => _isRevealed = true);

    // Phase 3: Show interpretation
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _showInterpretation = true);

    // Enable close after animation
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _canClose = true);
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _flipController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.black.withOpacity(0.85),
              ),
            ),
          ),

          // Animated particles/stars background
          Positioned.fill(
            child: _buildStarfieldBackground(),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Close button (appears after animation)
                AnimatedOpacity(
                  opacity: _canClose ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: _canClose ? widget.onClose : null,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.8),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // The Card
                        _buildAnimatedCard(),

                        const SizedBox(height: 32),

                        // Interpretation text
                        _buildInterpretation(),

                        const SizedBox(height: 32),

                        // Bottom action
                        _buildBottomAction(),

                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarfieldBackground() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return CustomPaint(
          painter: _StarfieldPainter(
            glowIntensity: _glowController.value,
            color: AppColors.secondary,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_shuffleController, _flipController]),
      builder: (context, child) {
        // During shuffle: rapid spinning with wobble
        final shuffleProgress = _shuffleController.value;
        final shuffleRotation = shuffleProgress * math.pi * 8; // 4 full rotations
        final wobble = math.sin(shuffleProgress * math.pi * 12) * 0.1;

        // During flip: single flip to reveal
        final flipProgress = _flipController.value;
        final flipAngle = flipProgress * math.pi;
        final showFront = flipProgress >= 0.5;

        // Combine rotations
        final isShuffling = _shuffleController.isAnimating;
        final yRotation = isShuffling ? shuffleRotation : flipAngle;

        // Scale pulse during shuffle
        final scalePulse = isShuffling
            ? 1.0 + math.sin(shuffleProgress * math.pi * 6) * 0.05
            : 1.0;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(yRotation)
            ..rotateZ(isShuffling ? wobble : 0)
            ..scale(scalePulse),
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Dynamic glow
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(
                        0.3 + _glowController.value * 0.4,
                      ),
                      blurRadius: 30 + _glowController.value * 20,
                      spreadRadius: 5 + _glowController.value * 10,
                    ),
                    // Base shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: showFront && !isShuffling
                      ? _buildCardFront()
                      : _buildCardBack(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCardBack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          TarotDeckAssets.getCardBack(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2D1B4E),
                    const Color(0xFF1A0A2E),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.style_rounded,
                  color: AppColors.secondary.withOpacity(0.5),
                  size: 60,
                ),
              ),
            );
          },
        ),
        // Shimmer overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.transparent,
                Colors.white.withOpacity(0.05),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront() {
    // Mirror the content since the card is flipped
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Card image
          Transform(
            alignment: Alignment.center,
            transform: widget.dailyTarot.isUpright
                ? Matrix4.identity()
                : (Matrix4.identity()..rotateZ(math.pi)),
            child: Image.asset(
              TarotDeckAssets.getCardByName(widget.dailyTarot.cardName),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.secondary.withOpacity(0.2),
                  child: Center(
                    child: Icon(
                      Icons.style_rounded,
                      color: AppColors.secondary,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
          ),
          // Border
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterpretation() {
    if (!_showInterpretation) {
      return const SizedBox(height: 180);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Card name
          Text(
            widget.dailyTarot.cardName,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          // Orientation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.dailyTarot.isUpright
                  ? AppColors.secondary.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.dailyTarot.isUpright ? 'Upright' : 'Reversed',
              style: AppTypography.labelSmall.copyWith(
                color: widget.dailyTarot.isUpright
                    ? AppColors.secondary
                    : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Interpretation
          Text(
            widget.dailyTarot.interpretation.isNotEmpty
                ? widget.dailyTarot.interpretation
                : 'The cosmos speaks through this card today. Embrace its energy.',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut);
  }

  Widget _buildBottomAction() {
    if (!_canClose) return const SizedBox(height: 56);

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              AppColors.secondary.withOpacity(0.3),
              AppColors.primary.withOpacity(0.3),
            ],
          ),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          'Embrace Today\'s Guidance',
          style: AppTypography.labelLarge.copyWith(
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms);
  }
}

/// Custom painter for animated starfield background
class _StarfieldPainter extends CustomPainter {
  final double glowIntensity;
  final Color color;

  _StarfieldPainter({
    required this.glowIntensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.05 + glowIntensity * 0.1)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent stars

    // Draw static stars
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Draw larger glowing stars
    final glowPaint = Paint()
      ..color = color.withOpacity(0.1 + glowIntensity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 1;

      canvas.drawCircle(Offset(x, y), radius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}
