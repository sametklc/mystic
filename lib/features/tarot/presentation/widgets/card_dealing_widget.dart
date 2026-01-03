import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import 'tarot_card_fan.dart';

/// Phases of the card dealing ritual
enum DealingPhase {
  /// Cards are in a messy stack, waiting for user interaction
  stack,

  /// User is charging/holding the stack
  charging,

  /// Cards are flying out to their grid positions
  dealing,

  /// Cards are in their final grid positions, ready for selection
  ready,
}

/// State for each individual card during the animation
class CardAnimationState {
  double x;
  double y;
  double rotation;
  double targetX;
  double targetY;
  double initialRotation;
  double initialX;
  double initialY;
  bool isDealt;
  double dealProgress;
  int gridRow;
  int gridCol;

  CardAnimationState({
    required this.x,
    required this.y,
    required this.rotation,
    required this.targetX,
    required this.targetY,
    required this.initialRotation,
    required this.initialX,
    required this.initialY,
    this.isDealt = false,
    this.dealProgress = 0,
    this.gridRow = 0,
    this.gridCol = 0,
  });
}

/// A widget that handles the complete card dealing ritual animation.
///
/// CRITICAL: When `isTransitioning` is true, this widget FREEZES in its
/// current visual state and ignores all other inputs.
class CardDealingWidget extends StatefulWidget {
  final VoidCallback? onDealingComplete;
  final void Function(int cardIndex)? onCardSelected;
  final int? selectedCardIndex;
  final bool selectionEnabled;
  final bool isTransitioning;
  final int cardCount;
  final double chargeDuration;

  const CardDealingWidget({
    super.key,
    this.onDealingComplete,
    this.onCardSelected,
    this.selectedCardIndex,
    this.selectionEnabled = true,
    this.isTransitioning = false,
    this.cardCount = 22,
    this.chargeDuration = 2.5,
  });

  @override
  State<CardDealingWidget> createState() => _CardDealingWidgetState();
}

class _CardDealingWidgetState extends State<CardDealingWidget>
    with TickerProviderStateMixin {
  final Random _random = Random();

  DealingPhase _phase = DealingPhase.stack;
  late List<CardAnimationState> _cardStates;

  double _chargeProgress = 0;
  Offset _shakeOffset = Offset.zero;
  double _stackScale = 1.0;
  double _glowIntensity = 0;

  late AnimationController _chargeController;
  late AnimationController _shakeController;
  late AnimationController _glowController;
  late AnimationController _dealController;
  late AnimationController _selectionGlowController;

  Timer? _hapticTimer;
  Timer? _dealTimer;

  static const double stackCardWidth = 70;
  static const double stackCardHeight = 120;
  static const List<int> gridRowCounts = [6, 6, 6, 4];

  Size? _cachedSize;
  double _gridCardWidth = 0;
  double _gridCardHeight = 0;
  bool _gridPositionsCalculated = false;

  /// CRITICAL: Track if we've ever reached the ready phase
  /// This prevents going back to stack phase during transition
  bool _hasReachedReadyPhase = false;

  /// CRITICAL: Cache the last known good state for freezing
  int? _frozenSelectedIndex;

  @override
  void initState() {
    super.initState();
    _initializeCardStates();

    _chargeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.chargeDuration * 1000).toInt()),
    )..addListener(() {
        if (!widget.isTransitioning) {
          setState(() {
            _chargeProgress = _chargeController.value;
          });
        }
      });

    _chargeController.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _phase == DealingPhase.charging &&
          !widget.isTransitioning) {
        _startDealing();
      }
    });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(() {
        if (_phase == DealingPhase.charging && !widget.isTransitioning) {
          final intensity = 3 + (_chargeProgress * 8);
          setState(() {
            _shakeOffset = Offset(
              sin(_shakeController.value * pi * 8) * intensity,
              cos(_shakeController.value * pi * 6) * intensity * 0.5,
            );
          });
        }
      });

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )
      ..addListener(() {
        if ((_phase == DealingPhase.stack || _phase == DealingPhase.charging) &&
            !widget.isTransitioning) {
          setState(() {
            _glowIntensity = _glowController.value;
          });
        }
      })
      ..repeat(reverse: true);

    _dealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        if (!widget.isTransitioning) {
          _updateDealingAnimation();
        }
      });

    _selectionGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _initializeCardStates() {
    _cardStates = List.generate(widget.cardCount, (index) {
      final randomRotation = (_random.nextDouble() - 0.5) * 0.4;
      final randomX = (_random.nextDouble() - 0.5) * 40;
      final randomY = (_random.nextDouble() - 0.5) * 30;

      return CardAnimationState(
        x: randomX,
        y: randomY,
        rotation: randomRotation,
        targetX: 0,
        targetY: 0,
        initialRotation: randomRotation,
        initialX: randomX,
        initialY: randomY,
      );
    });
  }

  @override
  void didUpdateWidget(CardDealingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: When transitioning starts, freeze the current selected index
    if (widget.isTransitioning && !oldWidget.isTransitioning) {
      _frozenSelectedIndex = widget.selectedCardIndex;
      // Do NOT reset anything - just freeze
      return;
    }

    // CRITICAL: When transitioning ends (user came back), reset for new selection
    if (!widget.isTransitioning && oldWidget.isTransitioning) {
      _frozenSelectedIndex = null;
      // Keep in ready phase if we were there
      if (_hasReachedReadyPhase) {
        _phase = DealingPhase.ready;
      }
    }

    // Don't update anything else while transitioning
    if (widget.isTransitioning) {
      return;
    }
  }

  @override
  void dispose() {
    _chargeController.dispose();
    _shakeController.dispose();
    _glowController.dispose();
    _dealController.dispose();
    _selectionGlowController.dispose();
    _hapticTimer?.cancel();
    _dealTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_phase != DealingPhase.stack || widget.isTransitioning) return;

    setState(() {
      _phase = DealingPhase.charging;
      _stackScale = 1.0;
    });

    HapticFeedback.lightImpact();
    _chargeController.forward(from: 0);
    _startShaking();
    _startHapticFeedback();
  }

  void _onTapUp(TapUpDetails details) {
    if (_phase == DealingPhase.charging && !widget.isTransitioning) {
      _cancelCharging();
    }
  }

  void _onTapCancel() {
    if (_phase == DealingPhase.charging && !widget.isTransitioning) {
      _cancelCharging();
    }
  }

  void _cancelCharging() {
    setState(() {
      _phase = DealingPhase.stack;
      _chargeProgress = 0;
      _shakeOffset = Offset.zero;
      _stackScale = 1.0;
    });
    _chargeController.stop();
    _chargeController.value = 0;
    _shakeController.stop();
    _hapticTimer?.cancel();
  }

  void _startShaking() async {
    while (_phase == DealingPhase.charging && mounted && !widget.isTransitioning) {
      await _shakeController.forward(from: 0);
      if (_phase != DealingPhase.charging || !mounted || widget.isTransitioning) break;

      setState(() {
        _stackScale = 1.0 + (_chargeProgress * 0.15);
      });

      final delay = max(20, (50 - _chargeProgress * 30).toInt());
      await Future.delayed(Duration(milliseconds: delay));
    }
  }

  void _startHapticFeedback() {
    _hapticTimer?.cancel();

    void triggerHaptic() {
      if (_phase != DealingPhase.charging || !mounted || widget.isTransitioning) {
        _hapticTimer?.cancel();
        return;
      }

      if (_chargeProgress < 0.3) {
        HapticFeedback.lightImpact();
      } else if (_chargeProgress < 0.7) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }

      final interval = max(50, (200 - _chargeProgress * 150).toInt());
      _hapticTimer = Timer(Duration(milliseconds: interval), triggerHaptic);
    }

    triggerHaptic();
  }

  void _startDealing() {
    if (widget.isTransitioning) return;

    _hapticTimer?.cancel();

    setState(() {
      _phase = DealingPhase.dealing;
      _shakeOffset = Offset.zero;
      _stackScale = 1.0;
    });

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.heavyImpact();
    });

    _dealController.forward(from: 0);
    _startSequentialDealing();
  }

  void _calculateGridPositions(Size size) {
    if (_gridPositionsCalculated && _cachedSize == size) return;

    _cachedSize = size;
    _gridPositionsCalculated = true;

    final availableWidth = size.width - 32;
    const horizontalSpacing = 6.0;
    _gridCardWidth = (availableWidth - (5 * horizontalSpacing)) / 6;
    _gridCardHeight = _gridCardWidth * 1.5;
    const verticalSpacing = 8.0;

    final totalGridHeight = (4 * _gridCardHeight) + (3 * verticalSpacing);
    final gridTop = (size.height - totalGridHeight) / 2;

    int cardIndex = 0;
    double currentY = gridTop;

    for (int rowIndex = 0; rowIndex < gridRowCounts.length; rowIndex++) {
      final cardsInRow = gridRowCounts[rowIndex];
      final rowWidth =
          (cardsInRow * _gridCardWidth) + ((cardsInRow - 1) * horizontalSpacing);
      double currentX = (size.width - rowWidth) / 2;

      for (int colIndex = 0; colIndex < cardsInRow; colIndex++) {
        if (cardIndex >= widget.cardCount) break;

        final state = _cardStates[cardIndex];
        state.targetX = currentX + _gridCardWidth / 2 - size.width / 2;
        state.targetY = currentY + _gridCardHeight / 2 - size.height / 2;
        state.gridRow = rowIndex;
        state.gridCol = colIndex;

        currentX += _gridCardWidth + horizontalSpacing;
        cardIndex++;
      }

      currentY += _gridCardHeight + verticalSpacing;
    }
  }

  void _startSequentialDealing() {
    if (widget.isTransitioning) return;

    int cardIndex = 0;
    const delayPerCard = 40;

    _dealTimer?.cancel();

    void dealNextCard() {
      if (cardIndex >= widget.cardCount || !mounted || widget.isTransitioning) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !widget.isTransitioning) {
            setState(() {
              _phase = DealingPhase.ready;
              _hasReachedReadyPhase = true; // CRITICAL: Mark that we've reached ready
            });
            widget.onDealingComplete?.call();
          }
        });
        return;
      }

      setState(() {
        _cardStates[cardIndex].isDealt = true;
      });

      if (cardIndex % 4 == 0) {
        HapticFeedback.lightImpact();
      }

      cardIndex++;
      _dealTimer = Timer(const Duration(milliseconds: delayPerCard), dealNextCard);
    }

    dealNextCard();
  }

  void _updateDealingAnimation() {
    if (_phase != DealingPhase.dealing || widget.isTransitioning) return;

    final progress = _dealController.value;

    setState(() {
      for (int i = 0; i < _cardStates.length; i++) {
        final state = _cardStates[i];
        if (state.isDealt) {
          final cardDelay = i / widget.cardCount;
          final cardProgress = ((progress - cardDelay * 0.4) / 0.6).clamp(0.0, 1.0);
          final easedCardProgress = Curves.easeOutCubic.transform(cardProgress);

          state.dealProgress = easedCardProgress;
          state.x = state.initialX + (state.targetX - state.initialX) * easedCardProgress;
          state.y = state.initialY + (state.targetY - state.initialY) * easedCardProgress;
          state.rotation = state.initialRotation * (1 - easedCardProgress);
        }
      }
    });
  }

  void _onCardTap(int index) {
    if (!widget.selectionEnabled || widget.isTransitioning) return;

    HapticFeedback.mediumImpact();
    widget.onCardSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    // ========================================================================
    // CRITICAL FREEZE LOGIC
    // ========================================================================
    // If isTransitioning is TRUE, we MUST show the grid/ready view
    // with the selected card highlighted, regardless of internal phase.
    // This prevents the "flashback" glitch.
    // ========================================================================

    if (widget.isTransitioning) {
      // FORCE render the frozen selection view - ignore all other state
      return _buildFrozenSelectionView();
    }

    // Normal phase-based rendering when not transitioning
    switch (_phase) {
      case DealingPhase.stack:
      case DealingPhase.charging:
        return _buildStackPhase();
      case DealingPhase.dealing:
        return _buildDealingPhase();
      case DealingPhase.ready:
        return _buildReadyPhase();
    }
  }

  /// CRITICAL: Build a frozen view that shows the grid with selection
  /// This is used during transition to prevent any visual changes
  Widget _buildFrozenSelectionView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _calculateGridPositions(size);

        final centerX = size.width / 2;
        final centerY = size.height / 2;
        final selectedIndex = _frozenSelectedIndex ?? widget.selectedCardIndex;

        // Use a static glow value to prevent animation during freeze
        const frozenGlowIntensity = 0.7;

        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(widget.cardCount, (index) {
            final state = _cardStates[index];
            final isSelected = selectedIndex == index;
            final hasSelection = selectedIndex != null;

            // Use target positions (final grid positions)
            final displayX = centerX + state.targetX - _gridCardWidth / 2;
            final displayY = centerY + state.targetY - _gridCardHeight / 2;

            double scale = 1.0;
            double opacity = 1.0;

            if (hasSelection) {
              if (isSelected) {
                scale = 1.15;
              } else {
                opacity = 0.5;
                scale = 0.95;
              }
            }

            return Positioned(
              left: displayX,
              top: displayY,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: _buildGridCard(
                    index: index,
                    width: _gridCardWidth,
                    height: _gridCardHeight,
                    isSelected: isSelected,
                    hasSelection: hasSelection,
                    glowIntensity: isSelected ? frozenGlowIntensity : 0,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStackPhase() {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChargeProgress(),
          const SizedBox(height: 24),
          SizedBox(
            height: stackCardHeight + 40,
            width: stackCardWidth + 60,
            child: Transform.translate(
              offset: _shakeOffset,
              child: Transform.scale(
                scale: _stackScale,
                child: Stack(
                  alignment: Alignment.center,
                  children: _buildStackCards(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildInstructions(),
        ],
      ),
    );
  }

  Widget _buildChargeProgress() {
    if (_phase != DealingPhase.charging) {
      return const SizedBox(height: 60);
    }

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 3,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: _chargeProgress,
              strokeWidth: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                Color.lerp(AppColors.primary, AppColors.secondary, _chargeProgress)!,
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3 + _chargeProgress * 0.5),
                  blurRadius: 10 + _chargeProgress * 20,
                  spreadRadius: _chargeProgress * 5,
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 16,
              color: AppColors.primary.withOpacity(0.6 + _chargeProgress * 0.4),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStackCards() {
    final cards = <Widget>[];
    final visibleCards = min(15, widget.cardCount);

    for (int i = 0; i < visibleCards; i++) {
      final isTopCard = i == visibleCards - 1;
      final state = _cardStates[i];
      final messyFactor = 1 - (_chargeProgress * 0.7);

      cards.add(
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translate(state.initialX * messyFactor, state.initialY * messyFactor)
            ..rotateZ(state.initialRotation * messyFactor),
          child: _buildStackCard(
            isTopCard: isTopCard,
            glowIntensity: isTopCard ? _glowIntensity * (0.5 + _chargeProgress * 0.5) : 0,
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildInstructions() {
    final isCharging = _phase == DealingPhase.charging;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCharging ? Icons.hourglass_top : Icons.touch_app,
              size: 16,
              color: isCharging ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              isCharging ? 'Channeling energy...' : 'Hold to channel energy',
              style: AppTypography.bodySmall.copyWith(
                color: isCharging ? AppColors.primary : AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        if (isCharging) ...[
          const SizedBox(height: 8),
          Text(
            '${(_chargeProgress * 100).toInt()}%',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primary,
              letterSpacing: 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDealingPhase() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _calculateGridPositions(size);

        final centerX = size.width / 2;
        final centerY = size.height / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(widget.cardCount, (index) {
            final state = _cardStates[index];

            final displayX = state.isDealt
                ? centerX + state.x - _gridCardWidth / 2
                : centerX + state.initialX - stackCardWidth / 2;
            final displayY = state.isDealt
                ? centerY + state.y - _gridCardHeight / 2
                : centerY + state.initialY - stackCardHeight / 2;
            final displayRotation = state.isDealt ? state.rotation : state.initialRotation;

            final cardWidth = state.isDealt
                ? stackCardWidth + (_gridCardWidth - stackCardWidth) * state.dealProgress
                : stackCardWidth;
            final cardHeight = state.isDealt
                ? stackCardHeight + (_gridCardHeight - stackCardHeight) * state.dealProgress
                : stackCardHeight;

            return Positioned(
              left: displayX,
              top: displayY,
              child: Transform.rotate(
                angle: displayRotation,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: state.isDealt ? 1.0 : 0.7,
                  child: _buildGridCard(
                    index: index,
                    width: cardWidth,
                    height: cardHeight,
                    isSelected: false,
                    hasSelection: false,
                    glowIntensity: 0,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildReadyPhase() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _calculateGridPositions(size);

        final centerX = size.width / 2;
        final centerY = size.height / 2;

        return AnimatedBuilder(
          animation: _selectionGlowController,
          builder: (context, child) {
            final glowIntensity = _selectionGlowController.value;

            return Stack(
              clipBehavior: Clip.none,
              children: List.generate(widget.cardCount, (index) {
                final state = _cardStates[index];
                final isSelected = widget.selectedCardIndex == index;
                final hasSelection = widget.selectedCardIndex != null;

                final displayX = centerX + state.targetX - _gridCardWidth / 2;
                final displayY = centerY + state.targetY - _gridCardHeight / 2;

                double scale = 1.0;
                double opacity = 1.0;

                if (hasSelection) {
                  if (isSelected) {
                    scale = 1.15;
                  } else {
                    opacity = 0.5;
                    scale = 0.95;
                  }
                }

                return Positioned(
                  left: displayX,
                  top: displayY,
                  child: GestureDetector(
                    onTap: () => _onCardTap(index),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: opacity,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        scale: scale,
                        child: _buildGridCard(
                          index: index,
                          width: _gridCardWidth,
                          height: _gridCardHeight,
                          isSelected: isSelected,
                          hasSelection: hasSelection,
                          glowIntensity: isSelected ? glowIntensity : 0,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildStackCard({bool isTopCard = false, double glowIntensity = 0}) {
    return Container(
      width: stackCardWidth,
      height: stackCardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTopCard
              ? AppColors.primary.withOpacity(0.5 + glowIntensity * 0.5)
              : AppColors.primary.withOpacity(0.3),
          width: isTopCard ? 1.5 : 1,
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
            offset: const Offset(2, 3),
          ),
          if (glowIntensity > 0)
            BoxShadow(
              color: AppColors.primary.withOpacity(glowIntensity * 0.5),
              blurRadius: 15 + glowIntensity * 10,
              spreadRadius: glowIntensity * 3,
            ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _CardPatternPainter(glowIntensity: glowIntensity),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 36,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.2 + glowIntensity * 0.3),
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 20,
                color: AppColors.secondary.withOpacity(0.4 + glowIntensity * 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard({
    required int index,
    required double width,
    required double height,
    required bool isSelected,
    required bool hasSelection,
    required double glowIntensity,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withOpacity(0.8 + glowIntensity * 0.2)
              : AppColors.primary.withOpacity(0.25),
          width: isSelected ? 2 : 1,
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
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3 + glowIntensity * 0.3),
              blurRadius: 12 + glowIntensity * 8,
              spreadRadius: 1 + glowIntensity * 2,
            ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CustomPaint(
                painter: _GridCardPatternPainter(
                  isSelected: isSelected,
                  glowIntensity: glowIntensity,
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.auto_awesome,
              size: width * 0.35,
              color: isSelected
                  ? AppColors.primary.withOpacity(0.8 + glowIntensity * 0.2)
                  : AppColors.secondary.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPatternPainter extends CustomPainter {
  final double glowIntensity;

  _CardPatternPainter({this.glowIntensity = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.secondary.withOpacity(0.08 + glowIntensity * 0.1);

    for (int i = -10; i < 20; i++) {
      final startX = i * 10.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.secondary.withOpacity(0.12 + glowIntensity * 0.15);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CardPatternPainter oldDelegate) {
    return oldDelegate.glowIntensity != glowIntensity;
  }
}

class _GridCardPatternPainter extends CustomPainter {
  final bool isSelected;
  final double glowIntensity;

  _GridCardPatternPainter({
    this.isSelected = false,
    this.glowIntensity = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    final patternColor = isSelected
        ? AppColors.primary.withOpacity(0.15 + glowIntensity * 0.15)
        : AppColors.secondary.withOpacity(0.08);
    paint.color = patternColor;

    for (int i = -5; i < 15; i++) {
      final startX = i * 8.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = isSelected
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.secondary.withOpacity(0.1);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GridCardPatternPainter oldDelegate) {
    return oldDelegate.isSelected != isSelected ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
