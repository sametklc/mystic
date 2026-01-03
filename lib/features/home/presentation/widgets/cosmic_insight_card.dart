import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/constants.dart';
import '../../../sky_hall/domain/models/daily_insight_model.dart';

/// Premium Cosmic Insight Card with starfield background.
/// Features a window into deep space with glowing moon and glassmorphism badge.
class CosmicInsightCard extends ConsumerWidget {
  final DailyInsight? insight;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const CosmicInsightCard({
    super.key,
    this.insight,
    this.isLoading = false,
    this.hasError = false,
    this.onTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (insight != null) {
      return _buildSuccessState(context);
    }

    // Error or initial state
    return _buildErrorState();
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.mysticTeal.withOpacity(0.15),
            blurRadius: 15,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Shimmer.fromColors(
          baseColor: AppColors.mysticTeal.withOpacity(0.1),
          highlightColor: AppColors.mysticTeal.withOpacity(0.3),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  const Color(0xFF0D4D4D),
                  const Color(0xFF0A2E2E),
                  Colors.black,
                ],
              ),
            ),
            child: CustomPaint(
              painter: _StarfieldPainter(starCount: 30),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mysticTeal.withOpacity(0.2),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.mysticTeal.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.mysticTeal.withOpacity(0.1),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [
                  const Color(0xFF0D4D4D),
                  const Color(0xFF0A2E2E),
                  Colors.black,
                ],
              ),
              border: Border.all(
                color: AppColors.mysticTeal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: CustomPaint(
              painter: _StarfieldPainter(starCount: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: AppColors.mysticTeal.withOpacity(0.6),
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to retry',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.mysticTeal.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // 3D shadow effect
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.mysticTeal.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Deep space background with radial gradient
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [
                      const Color(0xFF0D4D4D), // Deep teal
                      const Color(0xFF0A2E2E),
                      const Color(0xFF051515),
                      Colors.black,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // Starfield
              CustomPaint(
                painter: _StarfieldPainter(starCount: 60),
                size: Size.infinite,
              ),

              // Content - Flexible layout for varying heights
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Large glowing moon icon (flexible size)
                    Flexible(
                      flex: 3,
                      child: _buildMoonIcon(),
                    ),

                    const SizedBox(height: 6),

                    // Moon phase name
                    Text(
                      insight!.moonPhase,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    // Glassmorphism badge with moon sign
                    _buildMoonSignBadge(),
                  ],
                ),
              ),

              // Border
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.mysticTeal.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoonIcon() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptive size based on available space (max 64px)
        final size = constraints.maxHeight.clamp(40.0, 64.0);
        final iconSize = size * 0.55;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.mysticTeal.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.mysticTeal.withOpacity(0.4),
                  AppColors.mysticTeal.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                insight!.moonPhaseIconData,
                size: iconSize,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: AppColors.mysticTeal,
                    blurRadius: 15,
                  ),
                  Shadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.05, 1.05),
              duration: 3.seconds,
              curve: Curves.easeInOut,
            );
      },
    );
  }

  Widget _buildMoonSignBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.1),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                insight!.moonSignSymbol,
                style: TextStyle(
                  fontSize: 14,
                  color: insight!.elementColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Moon in ${insight!.moonSign}',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for starfield background
class _StarfieldPainter extends CustomPainter {
  final int starCount;
  final math.Random _random = math.Random(42);

  _StarfieldPainter({this.starCount = 50});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < starCount; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = _random.nextDouble() * 1.2 + 0.3;
      final opacity = _random.nextDouble() * 0.7 + 0.3;

      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);

      // Add subtle glow to some stars
      if (_random.nextDouble() > 0.7) {
        paint.color = Colors.white.withOpacity(opacity * 0.3);
        canvas.drawCircle(Offset(x, y), radius * 2.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom sheet for detailed cosmic insight
class CosmicInsightBottomSheet extends StatelessWidget {
  final DailyInsight insight;

  const CosmicInsightBottomSheet({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(
          color: AppColors.mysticTeal.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Moon Phase Icon (Large)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.mysticTeal.withOpacity(0.3),
                        AppColors.mysticTeal.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mysticTeal.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    insight.moonPhaseIconData,
                    color: AppColors.mysticTeal,
                    size: 48,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

                const SizedBox(height: 20),

                // Moon Phase Name
                Text(
                  insight.moonPhase,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: 8),

                // Moon Sign with Element
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      insight.moonSignSymbol,
                      style: TextStyle(
                        fontSize: 18,
                        color: insight.elementColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Moon in ${insight.moonSign}',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: insight.elementColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        insight.moonElement,
                        style: AppTypography.labelSmall.copyWith(
                          color: insight.elementColor,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms),

                const SizedBox(height: 8),

                // Illumination
                Text(
                  '${insight.moonIllumination.toStringAsFixed(0)}% Illuminated',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 24),

                // Divider
                Container(
                  width: 100,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.mysticTeal.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Mercury Status
                if (insight.mercuryRetrograde)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mercury Retrograde',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms)
                      .shake(hz: 2, rotation: 0.02),

                // Advice
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.mysticTeal.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppColors.mysticTeal.withOpacity(0.7),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        insight.advice,
                        style: AppTypography.mysticalQuote.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 24),

                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.textTertiary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms),

                // Bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
