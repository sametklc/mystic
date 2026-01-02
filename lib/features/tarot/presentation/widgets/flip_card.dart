import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// A card that can flip between front and back with a 3D animation.
class FlipCard extends StatefulWidget {
  /// The front side of the card (face up).
  final Widget front;

  /// The back side of the card (face down).
  final Widget back;

  /// Whether to show the front (true) or back (false).
  final bool showFront;

  /// Duration of the flip animation.
  final Duration duration;

  /// Callback when flip animation completes.
  final VoidCallback? onFlipComplete;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.showFront = false,
    this.duration = const Duration(milliseconds: 800),
    this.onFlipComplete,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutBack,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFlipComplete?.call();
      }
    });

    if (widget.showFront) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFront != oldWidget.showFront) {
      if (widget.showFront) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Calculate rotation
        final angle = _animation.value * math.pi;
        final isBack = angle <= math.pi / 2;

        // Apply perspective transform
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // Perspective
          ..rotateY(angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: isBack
              ? widget.back
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.front,
                ),
        );
      },
    );
  }
}

/// The back of the tarot card with pulsing glow effect.
class TarotCardBackLarge extends StatelessWidget {
  final double glowIntensity;
  final double width;
  final double height;

  const TarotCardBackLarge({
    super.key,
    this.glowIntensity = 0.5,
    this.width = 200,
    this.height = 340,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.6 + glowIntensity * 0.4),
          width: 2,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundTertiary,
            AppColors.backgroundSecondary,
            AppColors.background,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2 + glowIntensity * 0.3),
            blurRadius: 30 + glowIntensity * 20,
            spreadRadius: 5 + glowIntensity * 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Mystical pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: _CardBackPatternPainter(glowIntensity: glowIntensity),
              ),
            ),
          ),
          // Center ornament
          Center(
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4 + glowIntensity * 0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: AppColors.primary.withValues(alpha: 0.7 + glowIntensity * 0.3),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 60,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primary.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The front of the tarot card showing the image.
class TarotCardFrontLarge extends StatelessWidget {
  final String? imageUrl;
  final String cardName;
  final bool isUpright;
  final double width;
  final double height;
  final bool isLoading;

  const TarotCardFrontLarge({
    super.key,
    this.imageUrl,
    required this.cardName,
    this.isUpright = true,
    this.width = 200,
    this.height = 340,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.8),
          width: 2,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTertiary,
            AppColors.background,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _buildCardImage(),
      ),
    );
  }

  Widget _buildCardImage() {
    if (isLoading) {
      return _buildShimmerPlaceholder();
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildShimmerPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackImage();
        },
      );
    }

    return _buildFallbackImage();
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundSecondary,
            AppColors.backgroundTertiary,
            AppColors.backgroundSecondary,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Generating Vision...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.secondary.withValues(alpha: 0.3),
            AppColors.background,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          size: 80,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _CardBackPatternPainter extends CustomPainter {
  final double glowIntensity;

  _CardBackPatternPainter({this.glowIntensity = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.primary.withValues(alpha: 0.1 + glowIntensity * 0.15);

    // Draw diagonal lines
    for (int i = -20; i < 40; i++) {
      final startX = i * 15.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(size.width - startX, 0),
        Offset(size.width - startX - size.height, size.height),
        paint,
      );
    }

    // Draw border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.primary.withValues(alpha: 0.2 + glowIntensity * 0.2);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 16, size.width - 32, size.height - 32),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CardBackPatternPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}
