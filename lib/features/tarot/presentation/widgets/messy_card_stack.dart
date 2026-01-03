import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';

/// A messy stack of tarot cards that animates to an ordered fan on long press.
///
/// Implements a ritualistic "Oracle Shuffle" interaction:
/// - Initial state: Cards displayed in a messy stack with random rotations
/// - Long press: Triggers progressive haptic feedback and shake animation
/// - After 3 seconds: Cards fly out and transition to the fan selection view
class MessyCardStack extends StatefulWidget {
  /// Callback when shuffle is complete
  final VoidCallback onShuffleComplete;

  /// Number of cards to display in the stack
  final int cardCount;

  const MessyCardStack({
    super.key,
    required this.onShuffleComplete,
    this.cardCount = 22,
  });

  @override
  State<MessyCardStack> createState() => _MessyCardStackState();
}

class _MessyCardStackState extends State<MessyCardStack>
    with TickerProviderStateMixin {
  late AnimationController _holdController;
  late AnimationController _shakeController;
  late AnimationController _glowController;
  late AnimationController _flyOutController;

  bool _isHolding = false;
  bool _isShuffling = false;
  final Random _random = Random();

  // Pre-calculated random rotations and offsets for each card
  late List<double> _rotations;
  late List<Offset> _offsets;

  // Fly-out target positions for each card
  late List<Offset> _flyOutTargets;

  // Track last haptic trigger to avoid rapid firing
  double _lastHapticProgress = 0;

  @override
  void initState() {
    super.initState();

    // Generate random positions for messy stack
    _rotations = List.generate(
      widget.cardCount,
      (i) => (_random.nextDouble() - 0.5) * 0.6, // -0.3 to 0.3 radians
    );
    _offsets = List.generate(
      widget.cardCount,
      (i) => Offset(
        (_random.nextDouble() - 0.5) * 40, // -20 to 20 px
        (_random.nextDouble() - 0.5) * 30, // -15 to 15 px
      ),
    );

    // Generate fly-out positions (cards spread outward)
    _flyOutTargets = List.generate(
      widget.cardCount,
      (i) {
        final angle = (i / widget.cardCount) * 2 * pi;
        final radius = 150.0 + _random.nextDouble() * 50;
        return Offset(cos(angle) * radius, sin(angle) * radius);
      },
    );

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _flyOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHolding) {
        _onShuffleComplete();
      }
    });

    _holdController.addListener(_onHoldProgress);
  }

  void _onHoldProgress() {
    if (!_isHolding || _isShuffling) return;

    final progress = _holdController.value;

    // Progressive haptic feedback with increasing intensity
    // Light taps every 10%, medium at 50%, heavy at 80%+
    if (progress >= 0.1 && _lastHapticProgress < 0.1) {
      HapticFeedback.lightImpact();
      _lastHapticProgress = 0.1;
    } else if (progress >= 0.2 && _lastHapticProgress < 0.2) {
      HapticFeedback.lightImpact();
      _lastHapticProgress = 0.2;
    } else if (progress >= 0.3 && _lastHapticProgress < 0.3) {
      HapticFeedback.lightImpact();
      _lastHapticProgress = 0.3;
    } else if (progress >= 0.4 && _lastHapticProgress < 0.4) {
      HapticFeedback.mediumImpact();
      _lastHapticProgress = 0.4;
    } else if (progress >= 0.5 && _lastHapticProgress < 0.5) {
      HapticFeedback.mediumImpact();
      _lastHapticProgress = 0.5;
    } else if (progress >= 0.6 && _lastHapticProgress < 0.6) {
      HapticFeedback.mediumImpact();
      _lastHapticProgress = 0.6;
    } else if (progress >= 0.7 && _lastHapticProgress < 0.7) {
      HapticFeedback.heavyImpact();
      _lastHapticProgress = 0.7;
    } else if (progress >= 0.8 && _lastHapticProgress < 0.8) {
      HapticFeedback.heavyImpact();
      _lastHapticProgress = 0.8;
    } else if (progress >= 0.9 && _lastHapticProgress < 0.9) {
      HapticFeedback.heavyImpact();
      _lastHapticProgress = 0.9;
    }
  }

  @override
  void dispose() {
    _holdController.removeListener(_onHoldProgress);
    _holdController.dispose();
    _shakeController.dispose();
    _glowController.dispose();
    _flyOutController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isHolding = true;
      _lastHapticProgress = 0;
    });
    _holdController.forward(from: 0);
    _startShaking();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isShuffling) {
      _cancelHold();
    }
  }

  void _onTapCancel() {
    if (!_isShuffling) {
      _cancelHold();
    }
  }

  void _cancelHold() {
    setState(() {
      _isHolding = false;
      _lastHapticProgress = 0;
    });
    _holdController.stop();
    _holdController.value = 0;
    _shakeController.stop();
  }

  void _startShaking() async {
    while (_isHolding && !_isShuffling && mounted) {
      await _shakeController.forward();
      await _shakeController.reverse();
      if (!_isHolding || !mounted) break;
      // Shake intensity increases as hold progresses
      final delay = max(20, 60 - (_holdController.value * 40).toInt());
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  void _onShuffleComplete() {
    setState(() {
      _isShuffling = true;
    });

    // Final heavy haptic burst
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });

    // Play fly-out animation
    _flyOutController.forward().then((_) {
      if (mounted) {
        // Callback after fly-out animation completes
        widget.onShuffleComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isShuffling ? null : _onTapDown,
      onTapUp: _isShuffling ? null : _onTapUp,
      onTapCancel: _isShuffling ? null : _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _holdController,
          _shakeController,
          _glowController,
          _flyOutController,
        ]),
        builder: (context, child) {
          final holdProgress = _holdController.value;
          final flyOutProgress = _flyOutController.value;
          // Increase shake intensity as hold progresses
          final shakeIntensity = 4 + (holdProgress * 8);
          final shakeOffset = _shakeController.value * shakeIntensity;
          final glowIntensity = _glowController.value;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress ring - fades during fly-out
              Opacity(
                opacity: 1 - flyOutProgress,
                child: _buildProgressRing(holdProgress, glowIntensity),
              ),

              const SizedBox(height: 24),

              // Card stack with shake and fly-out animations
              SizedBox(
                height: 200,
                width: 250,
                child: Transform.translate(
                  offset: Offset(
                    sin(shakeOffset * pi * 4) * shakeOffset * (1 - flyOutProgress),
                    cos(shakeOffset * pi * 4) * shakeOffset * 0.5 * (1 - flyOutProgress),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: _buildCardStack(holdProgress, glowIntensity, flyOutProgress),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Instructions - fades during fly-out
              Opacity(
                opacity: 1 - flyOutProgress,
                child: _buildInstructions(holdProgress),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressRing(double progress, double glowIntensity) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 3,
            color: AppColors.glassBorder,
          ),
          // Progress ring
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: Color.lerp(
              AppColors.primary,
              AppColors.secondary,
              progress,
            ),
          ),
          // Center icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.glassFill,
              boxShadow: _isHolding
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3 + progress * 0.4),
                        blurRadius: 15 + progress * 20,
                        spreadRadius: 2 + progress * 5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.touch_app_rounded,
              color: _isHolding
                  ? Color.lerp(AppColors.primary, AppColors.secondary, progress)
                  : AppColors.textSecondary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCardStack(double holdProgress, double glowIntensity, double flyOutProgress) {
    final cards = <Widget>[];

    // Show only top cards in the messy stack (for performance)
    final visibleCards = min(12, widget.cardCount);

    for (int i = 0; i < visibleCards; i++) {
      final isTopCard = i == visibleCards - 1;

      // During hold: cards become less messy (align toward center)
      final messyFactor = 1 - (holdProgress * 0.8);
      final currentRotation = _rotations[i] * messyFactor;
      final currentOffset = _offsets[i] * messyFactor;

      // During fly-out: cards spread outward with easing
      final flyOutCurve = Curves.easeOutCubic.transform(flyOutProgress);
      final flyOutOffset = _flyOutTargets[i] * flyOutCurve;

      // Combine offsets - messy offset reduces as fly-out increases
      final combinedOffset = Offset(
        currentOffset.dx * (1 - flyOutProgress) + flyOutOffset.dx,
        currentOffset.dy * (1 - flyOutProgress) + flyOutOffset.dy,
      );

      // Rotation also increases during fly-out (cards spin as they fly)
      final flyOutRotation = (i % 2 == 0 ? 1 : -1) * flyOutProgress * pi * 0.5;
      final combinedRotation = currentRotation * (1 - flyOutProgress) + flyOutRotation;

      // Opacity fades during fly-out
      final cardOpacity = 1 - (flyOutProgress * 0.8);

      cards.add(
        Opacity(
          opacity: cardOpacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(combinedOffset.dx, combinedOffset.dy)
              ..rotateZ(combinedRotation)
              ..scale(1.0 - flyOutProgress * 0.3), // Slightly shrink during fly-out
            child: _MessyStackCard(
              isTopCard: isTopCard,
              glowIntensity: isTopCard ? glowIntensity * (1 - flyOutProgress) : 0,
              isHolding: _isHolding,
              holdProgress: holdProgress,
              flyOutProgress: flyOutProgress,
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildInstructions(double holdProgress) {
    String text;
    if (_isShuffling) {
      text = 'The cards are ready...';
    } else if (_isHolding) {
      if (holdProgress < 0.33) {
        text = 'Focus your energy...';
      } else if (holdProgress < 0.66) {
        text = 'The cards are awakening...';
      } else {
        text = 'Almost there...';
      }
    } else {
      text = 'Hold to shuffle the deck';
    }

    return Text(
      text,
      style: TextStyle(
        color: _isHolding
            ? Color.lerp(AppColors.textSecondary, AppColors.primary, holdProgress)
            : AppColors.textTertiary,
        fontSize: 14,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.5,
      ),
    )
        .animate(target: _isHolding ? 1 : 0)
        .fadeIn(duration: 300.ms);
  }
}

/// Individual card in the messy stack
class _MessyStackCard extends StatelessWidget {
  final bool isTopCard;
  final double glowIntensity;
  final bool isHolding;
  final double holdProgress;
  final double flyOutProgress;

  const _MessyStackCard({
    required this.isTopCard,
    required this.glowIntensity,
    required this.isHolding,
    required this.holdProgress,
    this.flyOutProgress = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTopCard && isHolding
              ? Color.lerp(
                  AppColors.primary.withOpacity(0.5),
                  AppColors.secondary,
                  holdProgress,
                )!
              : AppColors.primary.withOpacity(0.3),
          width: isTopCard ? 2 : 1,
        ),
        gradient: LinearGradient(
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
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
          if (isTopCard && isHolding)
            BoxShadow(
              color: Color.lerp(
                AppColors.primary,
                AppColors.secondary,
                holdProgress,
              )!.withOpacity(0.3 + glowIntensity * 0.3),
              blurRadius: 15 + holdProgress * 20,
              spreadRadius: 2 + holdProgress * 5,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Diagonal pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: CustomPaint(
                painter: _CardPatternPainter(
                  isHighlighted: isTopCard && isHolding,
                  holdProgress: holdProgress,
                ),
              ),
            ),
          ),
          // Center ornament
          Center(
            child: Container(
              width: 50,
              height: 75,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isTopCard && isHolding
                      ? Color.lerp(
                          AppColors.primary,
                          AppColors.secondary,
                          holdProgress,
                        )!.withOpacity(0.5)
                      : AppColors.secondary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome,
                  size: 28,
                  color: isTopCard && isHolding
                      ? Color.lerp(
                          AppColors.primary,
                          AppColors.secondary,
                          holdProgress,
                        )!.withOpacity(0.7 + glowIntensity * 0.3)
                      : AppColors.secondary.withOpacity(0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPatternPainter extends CustomPainter {
  final bool isHighlighted;
  final double holdProgress;

  _CardPatternPainter({
    required this.isHighlighted,
    required this.holdProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final patternColor = isHighlighted
        ? Color.lerp(
            AppColors.primary,
            AppColors.secondary,
            holdProgress,
          )!.withOpacity(0.15 + holdProgress * 0.15)
        : AppColors.secondary.withOpacity(0.1);

    paint.color = patternColor;

    for (int i = -10; i < 25; i++) {
      final startX = i * 10.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CardPatternPainter oldDelegate) {
    return oldDelegate.isHighlighted != isHighlighted ||
        oldDelegate.holdProgress != holdProgress;
  }
}
