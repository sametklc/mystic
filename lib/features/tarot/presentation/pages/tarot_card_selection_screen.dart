import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import 'tarot_hub_screen.dart';
import 'tarot_reading_screen.dart';

// =============================================================================
// STATE MANAGEMENT
// =============================================================================

/// State for the card selection process
class CardSelectionState {
  final int currentStep;
  final List<SelectedCard> selectedCards;
  final int? flyingCardIndex;
  final bool isComplete;

  const CardSelectionState({
    this.currentStep = 0,
    this.selectedCards = const [],
    this.flyingCardIndex,
    this.isComplete = false,
  });

  CardSelectionState copyWith({
    int? currentStep,
    List<SelectedCard>? selectedCards,
    int? flyingCardIndex,
    bool? isComplete,
    bool clearFlyingCard = false,
  }) {
    return CardSelectionState(
      currentStep: currentStep ?? this.currentStep,
      selectedCards: selectedCards ?? this.selectedCards,
      flyingCardIndex: clearFlyingCard ? null : (flyingCardIndex ?? this.flyingCardIndex),
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Represents a selected card with its original index and target position
class SelectedCard {
  final int deckIndex;
  final String position;
  final int slotIndex;

  const SelectedCard({
    required this.deckIndex,
    required this.position,
    required this.slotIndex,
  });
}

/// Provider for card selection state - family provider keyed by spread id
final cardSelectionProvider = StateNotifierProvider.autoDispose
    .family<CardSelectionNotifier, CardSelectionState, String>((ref, spreadId) {
  return CardSelectionNotifier();
});

class CardSelectionNotifier extends StateNotifier<CardSelectionState> {
  CardSelectionNotifier() : super(const CardSelectionState());

  void selectCard(int deckIndex, String position) {
    final newCard = SelectedCard(
      deckIndex: deckIndex,
      position: position,
      slotIndex: state.currentStep,
    );

    state = state.copyWith(
      flyingCardIndex: deckIndex,
      selectedCards: [...state.selectedCards, newCard],
    );
  }

  void onFlyAnimationComplete(int totalRequired) {
    final newStep = state.currentStep + 1;
    final isComplete = newStep >= totalRequired;

    state = state.copyWith(
      currentStep: newStep,
      isComplete: isComplete,
      clearFlyingCard: true,
    );
  }

  void reset() {
    state = const CardSelectionState();
  }
}

// =============================================================================
// MAIN SCREEN
// =============================================================================

/// The ritual card selection screen where users pick cards from a fanned deck.
class TarotCardSelectionScreen extends ConsumerStatefulWidget {
  final SpreadDefinition spread;

  const TarotCardSelectionScreen({
    super.key,
    required this.spread,
  });

  @override
  ConsumerState<TarotCardSelectionScreen> createState() =>
      _TarotCardSelectionScreenState();
}

class _TarotCardSelectionScreenState
    extends ConsumerState<TarotCardSelectionScreen>
    with TickerProviderStateMixin {
  // Total cards in the deck to display
  static const int _totalDeckCards = 22;

  // Animation controllers
  late AnimationController _fanController;
  late AnimationController _glowController;
  late AnimationController _textPulseController;

  // For flying card animation
  final Map<int, GlobalKey> _cardKeys = {};
  final List<GlobalKey> _slotKeys = [];

  // Flying card state
  int? _flyingCardIndex;
  Offset? _flyStartPosition;
  Offset? _flyEndPosition;
  late AnimationController _flyController;
  late Animation<double> _flyAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize card keys
    for (int i = 0; i < _totalDeckCards; i++) {
      _cardKeys[i] = GlobalKey();
    }

    // Initialize slot keys
    for (int i = 0; i < widget.spread.cardCount; i++) {
      _slotKeys.add(GlobalKey());
    }

    // Fan entrance animation
    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Text pulse animation
    _textPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Flying animation controller
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flyAnimation = CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInOutCubic,
    );

    // Start fan animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fanController.forward();
    });
  }

  @override
  void dispose() {
    _fanController.dispose();
    _glowController.dispose();
    _textPulseController.dispose();
    _flyController.dispose();
    super.dispose();
  }

  void _onCardTapped(int cardIndex) {
    final state = ref.read(cardSelectionProvider(widget.spread.id));

    // Check if card already selected or animation in progress
    if (state.selectedCards.any((c) => c.deckIndex == cardIndex) ||
        state.flyingCardIndex != null ||
        _flyingCardIndex != null) {
      return;
    }

    // Check if selection complete
    if (state.currentStep >= widget.spread.cardCount) {
      return;
    }

    HapticFeedback.mediumImpact();

    // Get positions for flying animation
    final cardKey = _cardKeys[cardIndex];
    final slotKey = _slotKeys[state.currentStep];

    if (cardKey?.currentContext != null && slotKey.currentContext != null) {
      final cardBox = cardKey!.currentContext!.findRenderObject() as RenderBox;
      final slotBox = slotKey.currentContext!.findRenderObject() as RenderBox;

      final cardPosition = cardBox.localToGlobal(Offset.zero);
      final slotPosition = slotBox.localToGlobal(Offset.zero);

      setState(() {
        _flyingCardIndex = cardIndex;
        _flyStartPosition = cardPosition;
        _flyEndPosition = slotPosition;
      });

      // Select the card in state
      final currentPosition = widget.spread.positions[state.currentStep];
      ref.read(cardSelectionProvider(widget.spread.id).notifier)
          .selectCard(cardIndex, currentPosition);

      // Start fly animation
      _flyController.reset();
      _flyController.forward().then((_) {
        setState(() {
          _flyingCardIndex = null;
          _flyStartPosition = null;
          _flyEndPosition = null;
        });

        ref.read(cardSelectionProvider(widget.spread.id).notifier)
            .onFlyAnimationComplete(widget.spread.cardCount);

        // Check if complete
        final newState = ref.read(cardSelectionProvider(widget.spread.id));
        if (newState.isComplete) {
          _onSelectionComplete();
        }
      });
    }
  }

  void _onSelectionComplete() {
    HapticFeedback.heavyImpact();

    // Wait 500ms then navigate to reading screen
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final state = ref.read(cardSelectionProvider(widget.spread.id));

      // Convert selected cards to SelectedCardData for reading screen
      final selectedCardData = state.selectedCards.map((card) {
        // Generate random card name and orientation for demo
        final cardNames = [
          'The Fool', 'The Magician', 'The High Priestess', 'The Empress',
          'The Emperor', 'The Hierophant', 'The Lovers', 'The Chariot',
          'Strength', 'The Hermit', 'Wheel of Fortune', 'Justice',
          'The Hanged Man', 'Death', 'Temperance', 'The Devil',
          'The Tower', 'The Star', 'The Moon', 'The Sun',
          'Judgement', 'The World',
        ];
        final random = Random();
        return SelectedCardData(
          deckIndex: card.deckIndex,
          cardName: cardNames[card.deckIndex % cardNames.length],
          isUpright: random.nextBool(),
          position: card.position,
        );
      }).toList();

      // Navigate to reading screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return TarotReadingScreen(
              spread: widget.spread,
              selectedCards: selectedCardData,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardSelectionProvider(widget.spread.id));
    final screenSize = MediaQuery.of(context).size;

    return MysticBackgroundScaffold(
      child: Stack(
        children: [
          // Mystic particles background
          Positioned.fill(
            child: _MysticParticles(controller: _glowController),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header with back button
                _buildHeader(),

                const SizedBox(height: 16),

                // Guidance text
                _buildGuidanceText(state),

                // Fanned deck (center)
                Expanded(
                  flex: 3,
                  child: _buildFannedDeck(state, screenSize),
                ),

                // Selected cards slots (bottom)
                _buildSelectedSlots(state),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Flying card overlay
          if (_flyingCardIndex != null &&
              _flyStartPosition != null &&
              _flyEndPosition != null)
            _buildFlyingCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  widget.spread.gradientColors.first.withOpacity(0.3),
                  widget.spread.gradientColors.last.withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(
              widget.spread.icon,
              color: widget.spread.gradientColors.first,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.spread.title.toUpperCase(),
                style: AppTypography.labelMedium.copyWith(
                  color: widget.spread.gradientColors.first,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '${widget.spread.cardCount} Cards',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGuidanceText(CardSelectionState state) {
    if (state.isComplete) {
      return _buildCompletionText();
    }

    final currentPosition = state.currentStep < widget.spread.positions.length
        ? widget.spread.positions[state.currentStep]
        : '';

    return AnimatedBuilder(
      animation: _textPulseController,
      builder: (context, child) {
        final opacity = 0.7 + (_textPulseController.value * 0.3);
        final scale = 1.0 + (_textPulseController.value * 0.02);

        return Transform.scale(
          scale: scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  'Focus your energy...',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary.withOpacity(opacity),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Select a card for '),
                      TextSpan(
                        text: currentPosition.toUpperCase(),
                        style: GoogleFonts.cinzel(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.spread.gradientColors.first,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Progress indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.spread.cardCount, (index) {
                    final isCompleted = index < state.currentStep;
                    final isCurrent = index == state.currentStep;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isCurrent ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isCompleted
                            ? widget.spread.gradientColors.first
                            : isCurrent
                                ? widget.spread.gradientColors.first
                                    .withOpacity(0.5)
                                : AppColors.glassBorder,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: widget.spread.gradientColors.first
                                      .withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.2, end: 0);
  }

  Widget _buildCompletionText() {
    return Column(
      children: [
        Icon(
          Icons.auto_awesome,
          color: widget.spread.gradientColors.first,
          size: 32,
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
            .then()
            .shimmer(color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text(
          'The cards have spoken',
          style: GoogleFonts.cinzel(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: widget.spread.gradientColors.first,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Revealing your destiny...',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  Widget _buildFannedDeck(CardSelectionState state, Size screenSize) {
    return AnimatedBuilder(
      animation: _fanController,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final centerX = constraints.maxWidth / 2;
            final centerY = constraints.maxHeight / 2;

            // Card dimensions
            const cardWidth = 70.0;
            const cardHeight = 110.0;

            // Fan parameters
            const totalAngle = 120.0; // Total spread angle in degrees
            const fanRadius = 180.0; // Distance from center

            // Calculate visible cards (exclude selected ones)
            final visibleCards = <int>[];
            for (int i = 0; i < _totalDeckCards; i++) {
              if (!state.selectedCards.any((c) => c.deckIndex == i) &&
                  i != _flyingCardIndex) {
                visibleCards.add(i);
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Cards in fan arrangement
                ...visibleCards.asMap().entries.map((entry) {
                  final visibleIndex = entry.key;
                  final cardIndex = entry.value;

                  // Calculate angle for this card in the fan
                  final progress = visibleCards.length > 1
                      ? visibleIndex / (visibleCards.length - 1)
                      : 0.5;
                  final angle = (progress - 0.5) * totalAngle;
                  final angleRad = angle * (pi / 180);

                  // Animation progress
                  final animProgress = _fanController.value;
                  final cardDelay = cardIndex / _totalDeckCards;
                  final cardProgress =
                      ((animProgress - cardDelay * 0.3) / 0.7).clamp(0.0, 1.0);

                  // Interpolate from stack to fan position
                  final currentAngle = angleRad * cardProgress;
                  final currentRadius = fanRadius * cardProgress;

                  // Calculate position
                  final x = centerX +
                      sin(currentAngle) * currentRadius -
                      cardWidth / 2;
                  final y = centerY +
                      (1 - cos(currentAngle).abs()) * (fanRadius * 0.3) -
                      cardHeight / 2 +
                      30;

                  return Positioned(
                    left: x,
                    top: y,
                    child: Transform.rotate(
                      angle: currentAngle * 0.5,
                      alignment: Alignment.bottomCenter,
                      child: _FannedCard(
                        key: _cardKeys[cardIndex],
                        index: cardIndex,
                        width: cardWidth,
                        height: cardHeight,
                        glowController: _glowController,
                        gradientColors: widget.spread.gradientColors,
                        onTap: () => _onCardTapped(cardIndex),
                        animationDelay: (cardIndex * 30),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSelectedSlots(CardSelectionState state) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.spread.cardCount, (index) {
          final isSelected = index < state.selectedCards.length;
          final isCurrent = index == state.currentStep && !state.isComplete;
          final position = widget.spread.positions[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _CardSlot(
              key: _slotKeys[index],
              position: position,
              isSelected: isSelected,
              isCurrent: isCurrent,
              gradientColors: widget.spread.gradientColors,
              index: index,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFlyingCard() {
    return AnimatedBuilder(
      animation: _flyAnimation,
      builder: (context, child) {
        final progress = _flyAnimation.value;

        // Interpolate position
        final currentX = _flyStartPosition!.dx +
            (_flyEndPosition!.dx - _flyStartPosition!.dx) * progress;
        final currentY = _flyStartPosition!.dy +
            (_flyEndPosition!.dy - _flyStartPosition!.dy) * progress;

        // Arc effect - rise up then down
        final arcOffset = sin(progress * pi) * -80;

        // Scale effect - grow then shrink
        final scale = 1.0 + sin(progress * pi) * 0.3;

        // Rotation - spin slightly
        final rotation = progress * 0.2;

        return Positioned(
          left: currentX,
          top: currentY + arcOffset,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: _FlyingCardVisual(
                gradientColors: widget.spread.gradientColors,
                glowIntensity: 1.0 - progress * 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// FANNED CARD WIDGET
// =============================================================================

class _FannedCard extends StatefulWidget {
  final int index;
  final double width;
  final double height;
  final AnimationController glowController;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final int animationDelay;

  const _FannedCard({
    super.key,
    required this.index,
    required this.width,
    required this.height,
    required this.glowController,
    required this.gradientColors,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  State<_FannedCard> createState() => _FannedCardState();
}

class _FannedCardState extends State<_FannedCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isHovered = false);
    _hoverController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.glowController, _hoverAnimation]),
        builder: (context, child) {
          final glowValue = widget.glowController.value;
          final hoverValue = _hoverAnimation.value;
          final scale = 1.0 + hoverValue * 0.15;

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.backgroundPurple,
                    AppColors.primary.withOpacity(0.3),
                    AppColors.secondary.withOpacity(0.2),
                  ],
                ),
                border: Border.all(
                  color: _isHovered
                      ? widget.gradientColors.first
                      : AppColors.primary.withOpacity(0.4 + glowValue * 0.2),
                  width: _isHovered ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? widget.gradientColors.first.withOpacity(0.6)
                        : AppColors.primary.withOpacity(0.15 + glowValue * 0.15),
                    blurRadius: _isHovered ? 20 : 10 + glowValue * 8,
                    spreadRadius: _isHovered ? 2 : 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Card back pattern
                  Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 24,
                      color: AppColors.primary.withOpacity(0.6 + glowValue * 0.2),
                    ),
                  ),
                  // Corner decorations
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(
                      Icons.star,
                      size: 8,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.star,
                      size: 8,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Icon(
                      Icons.star,
                      size: 8,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Icon(
                      Icons.star,
                      size: 8,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  // Hover glow overlay
                  if (_isHovered)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: RadialGradient(
                          colors: [
                            widget.gradientColors.first.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: widget.animationDelay + 400),
          duration: 300.ms,
        )
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          delay: Duration(milliseconds: widget.animationDelay + 400),
          duration: 300.ms,
        );
  }
}

// =============================================================================
// CARD SLOT WIDGET
// =============================================================================

class _CardSlot extends StatelessWidget {
  final String position;
  final bool isSelected;
  final bool isCurrent;
  final List<Color> gradientColors;
  final int index;

  const _CardSlot({
    super.key,
    required this.position,
    required this.isSelected,
    required this.isCurrent,
    required this.gradientColors,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slot container
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 55,
          height: 75,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? gradientColors.first.withOpacity(0.2)
                : AppColors.glassFill,
            border: Border.all(
              color: isSelected
                  ? gradientColors.first
                  : isCurrent
                      ? gradientColors.first.withOpacity(0.6)
                      : AppColors.glassBorder,
              width: isCurrent ? 2 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? Center(
                  child: Icon(
                    Icons.auto_awesome,
                    color: gradientColors.first,
                    size: 24,
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1.1, 1.1),
                        duration: 1000.ms,
                      ),
                )
              : isCurrent
                  ? Center(
                      child: Icon(
                        Icons.touch_app_rounded,
                        color: gradientColors.first.withOpacity(0.5),
                        size: 20,
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn()
                          .then()
                          .fadeOut(),
                    )
                  : null,
        ),

        const SizedBox(height: 6),

        // Position label
        SizedBox(
          width: 60,
          child: Text(
            position,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: isSelected
                  ? gradientColors.first
                  : isCurrent
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
              fontSize: 8,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: index * 100 + 200),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.3,
          end: 0,
          delay: Duration(milliseconds: index * 100 + 200),
          duration: 400.ms,
        );
  }
}

// =============================================================================
// FLYING CARD VISUAL
// =============================================================================

class _FlyingCardVisual extends StatelessWidget {
  final List<Color> gradientColors;
  final double glowIntensity;

  const _FlyingCardVisual({
    required this.gradientColors,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientColors.first.withOpacity(0.8),
            gradientColors.last.withOpacity(0.6),
            AppColors.backgroundPurple,
          ],
        ),
        border: Border.all(
          color: gradientColors.first,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.6 * glowIntensity),
            blurRadius: 30,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.2 * glowIntensity),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          size: 28,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }
}

// =============================================================================
// MYSTIC PARTICLES BACKGROUND
// =============================================================================

class _MysticParticles extends StatelessWidget {
  final AnimationController controller;

  const _MysticParticles({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(
            progress: controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  final Random _random = Random(42);

  _ParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 40; i++) {
      final x = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.05 * (i % 3 + 1)) % size.height;

      final particleSize = _random.nextDouble() * 2 + 0.5;
      final twinkle = sin((progress * 2 * pi) + (i * 0.3));
      final opacity = (_random.nextDouble() * 0.4 + 0.1) * (0.5 + 0.5 * twinkle);

      paint.color = AppColors.starWhite.withOpacity(opacity.clamp(0.0, 0.5));
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
