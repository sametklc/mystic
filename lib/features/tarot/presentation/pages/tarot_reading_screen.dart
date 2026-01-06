import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/firestore_reading_service.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/services/gem_service.dart';
import '../../../../core/utils/tarot_image_helper.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../data/services/tarot_api_service.dart';
import '../../../shop/presentation/pages/diamond_shop_screen.dart';
import 'tarot_hub_screen.dart';

/// Cost in diamonds for Sacred Spreads reading
const int kSacredSpreadsDiamondCost = 25;

// =============================================================================
// DATA MODELS
// =============================================================================

/// Represents a selected card with its details
class SelectedCardData {
  final int deckIndex;
  final String cardName;
  final bool isUpright;
  final String position;

  const SelectedCardData({
    required this.deckIndex,
    required this.cardName,
    required this.isUpright,
    required this.position,
  });
}

/// Represents the interpretation for a single card from the API
class CardInterpretation {
  final String position;
  final String cardName;
  final String orientation;
  final String interpretation;

  const CardInterpretation({
    required this.position,
    required this.cardName,
    required this.orientation,
    required this.interpretation,
  });

  factory CardInterpretation.fromJson(Map<String, dynamic> json) {
    return CardInterpretation(
      position: json['position'] ?? '',
      cardName: json['card_name'] ?? '',
      orientation: json['orientation'] ?? 'Upright',
      interpretation: json['interpretation'] ?? '',
    );
  }
}

/// Full reading response from the API
class TarotReadingResponse {
  final String readingType;
  final List<CardInterpretation> cardsAnalysis;
  final String overallSynthesis;

  const TarotReadingResponse({
    required this.readingType,
    required this.cardsAnalysis,
    required this.overallSynthesis,
  });

  factory TarotReadingResponse.fromJson(Map<String, dynamic> json) {
    final cardsList = (json['cards_analysis'] as List<dynamic>?)
            ?.map((e) => CardInterpretation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return TarotReadingResponse(
      readingType: json['reading_type'] ?? '',
      cardsAnalysis: cardsList,
      overallSynthesis: json['overall_synthesis'] ?? '',
    );
  }
}

// =============================================================================
// STATE MANAGEMENT
// =============================================================================

/// State for the reading screen
class TarotReadingState {
  final bool isLoading;
  final String? error;
  final TarotReadingResponse? response;
  final int currentRevealIndex; // Which card can be revealed next
  final Set<int> revealedCards; // Which cards have been flipped
  final int? focusedCardIndex; // Currently focused card for interpretation display

  const TarotReadingState({
    this.isLoading = true,
    this.error,
    this.response,
    this.currentRevealIndex = 0,
    this.revealedCards = const {},
    this.focusedCardIndex,
  });

  bool get allCardsRevealed =>
      response != null && revealedCards.length >= response!.cardsAnalysis.length;

  TarotReadingState copyWith({
    bool? isLoading,
    String? error,
    TarotReadingResponse? response,
    int? currentRevealIndex,
    Set<int>? revealedCards,
    int? focusedCardIndex,
    bool clearError = false,
  }) {
    return TarotReadingState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      response: response ?? this.response,
      currentRevealIndex: currentRevealIndex ?? this.currentRevealIndex,
      revealedCards: revealedCards ?? this.revealedCards,
      focusedCardIndex: focusedCardIndex ?? this.focusedCardIndex,
    );
  }
}

/// Provider for reading state - keyed by a unique reading ID
final tarotReadingProvider = StateNotifierProvider.autoDispose
    .family<TarotReadingNotifier, TarotReadingState, String>((ref, readingId) {
  return TarotReadingNotifier(ref);
});

class TarotReadingNotifier extends StateNotifier<TarotReadingState> {
  final Ref ref;

  TarotReadingNotifier(this.ref) : super(const TarotReadingState());

  /// Fetch interpretation from the API
  Future<void> fetchReading({
    required SpreadDefinition spread,
    required List<SelectedCardData> selectedCards,
    String? userQuestion,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Simulate API call for now - replace with actual API call
      await Future.delayed(const Duration(seconds: 2));

      // Mock response - in production, call actual API
      final mockResponse = _generateMockReading(spread, selectedCards);

      state = state.copyWith(
        isLoading: false,
        response: mockResponse,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to consult the spirits. Please try again.',
      );
    }
  }

  /// Reveal a card at the given index
  void revealCard(int index) {
    if (index != state.currentRevealIndex) return;
    if (state.revealedCards.contains(index)) return;

    final newRevealed = {...state.revealedCards, index};

    state = state.copyWith(
      revealedCards: newRevealed,
      currentRevealIndex: state.currentRevealIndex + 1,
      focusedCardIndex: index,
    );
  }

  /// Set the focused card for interpretation display
  void setFocusedCard(int index) {
    if (!state.revealedCards.contains(index)) return;
    state = state.copyWith(focusedCardIndex: index);
  }

  /// Generate mock reading data
  TarotReadingResponse _generateMockReading(
    SpreadDefinition spread,
    List<SelectedCardData> selectedCards,
  ) {
    final cards = <CardInterpretation>[];

    for (int i = 0; i < selectedCards.length && i < spread.positions.length; i++) {
      final card = selectedCards[i];
      cards.add(CardInterpretation(
        position: spread.positions[i],
        cardName: card.cardName,
        orientation: card.isUpright ? 'Upright' : 'Reversed',
        interpretation: _getMockInterpretation(card.cardName, spread.positions[i]),
      ));
    }

    return TarotReadingResponse(
      readingType: spread.title,
      cardsAnalysis: cards,
      overallSynthesis: _getMockSynthesis(spread.title),
    );
  }

  String _getMockInterpretation(String cardName, String position) {
    return 'In the position of "$position", $cardName reveals profound insights about your journey. '
        'This card speaks to the energies surrounding you, suggesting a time of transformation and growth. '
        'Pay attention to the subtle signs around you, as they will guide your path forward. '
        'Trust in the cosmic forces that have brought this card to you at this moment.';
  }

  String _getMockSynthesis(String spreadType) {
    return 'The cards have spoken with clarity for your $spreadType reading. '
        'Together, they weave a narrative of transformation, challenge, and ultimate triumph. '
        'The energies present suggest that you are at a pivotal moment in your journey. '
        'Trust your intuition, embrace the changes ahead, and remember that the universe supports your highest good. '
        'Take time to reflect on these messages and allow their wisdom to guide your decisions in the coming days.';
  }
}

// =============================================================================
// MAIN SCREEN
// =============================================================================

/// The reading result screen where cards are revealed and interpreted
class TarotReadingScreen extends ConsumerStatefulWidget {
  final SpreadDefinition spread;
  final List<SelectedCardData> selectedCards;
  final String? userQuestion;

  const TarotReadingScreen({
    super.key,
    required this.spread,
    required this.selectedCards,
    this.userQuestion,
  });

  @override
  ConsumerState<TarotReadingScreen> createState() => _TarotReadingScreenState();
}

class _TarotReadingScreenState extends ConsumerState<TarotReadingScreen>
    with TickerProviderStateMixin {
  late String _readingId;
  late AnimationController _loadingController;
  late AnimationController _pulseController;
  bool _isSaving = false;
  bool _hasSaved = false;
  bool _diamondsDeducted = false;
  bool _insufficientDiamonds = false;

  @override
  void initState() {
    super.initState();

    // Generate unique reading ID
    _readingId = '${widget.spread.id}_${DateTime.now().millisecondsSinceEpoch}';

    // Loading animation controller
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Pulse animation for various elements
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Check diamonds and fetch reading on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndDeductDiamonds();
    });
  }

  /// Check if premium user has enough diamonds and deduct them
  Future<void> _checkAndDeductDiamonds() async {
    final isPremium = ref.read(isPremiumProvider);

    if (isPremium) {
      // Premium users pay 25 diamonds
      final userNotifier = ref.read(userProvider.notifier);
      final currentGems = ref.read(userProvider).gems;

      if (currentGems < kSacredSpreadsDiamondCost) {
        // Not enough diamonds
        setState(() => _insufficientDiamonds = true);
        return;
      }

      // Deduct diamonds
      final success = userNotifier.spendGems(kSacredSpreadsDiamondCost);

      if (!success) {
        setState(() => _insufficientDiamonds = true);
        return;
      }

      setState(() => _diamondsDeducted = true);
    }

    // Fetch reading (for both premium with deducted diamonds, and non-premium who see paywall)
    ref.read(tarotReadingProvider(_readingId).notifier).fetchReading(
          spread: widget.spread,
          selectedCards: widget.selectedCards,
          userQuestion: widget.userQuestion,
        );
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tarotReadingProvider(_readingId));
    final isPremium = ref.watch(isPremiumProvider);

    return MysticBackgroundScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: _insufficientDiamonds
                  ? _buildInsufficientDiamondsState()
                  : state.isLoading
                      ? _buildLoadingState()
                      : state.error != null
                          ? _buildErrorState(state.error!)
                          : isPremium
                              ? _buildReadingContent(state)
                              : _buildPremiumPaywall(state),
            ),
          ],
        ),
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
                'Reading',
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

  // ===========================================================================
  // PHASE 1: LOADING STATE
  // ===========================================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mystical loading indicator
          _MysticalLoadingIndicator(
            controller: _loadingController,
            pulseController: _pulseController,
            gradientColors: widget.spread.gradientColors,
          ),

          const SizedBox(height: 40),

          // Loading text
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final opacity = 0.5 + _pulseController.value * 0.5;
              return Text(
                'Consulting the spirits...',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  color: AppColors.textSecondary.withOpacity(opacity),
                  fontStyle: FontStyle.italic,
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Mystical sub-text
          Text(
            'The cards are revealing their secrets',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(duration: 1000.ms)
              .then()
              .fadeOut(duration: 1000.ms),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(tarotReadingProvider(_readingId).notifier).fetchReading(
                      spread: widget.spread,
                      selectedCards: widget.selectedCards,
                      userQuestion: widget.userQuestion,
                    );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.spread.gradientColors.first,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build insufficient diamonds state
  Widget _buildInsufficientDiamondsState() {
    final currentGems = ref.watch(userProvider).gems;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Diamond icon with warning
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00D9FF).withOpacity(0.2),
                        const Color(0xFF00D9FF).withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.diamond_outlined,
                    size: 48,
                    color: Color(0xFF00D9FF),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.warning,
                    ),
                    child: const Icon(
                      Icons.priority_high,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Not Enough Diamonds',
              style: GoogleFonts.cinzel(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'You need $kSacredSpreadsDiamondCost diamonds for a ${widget.spread.title} reading.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // Current balance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.glassFill,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.diamond,
                    size: 20,
                    color: Color(0xFF00D9FF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Current Balance: $currentGems',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Get Diamonds button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return const DiamondShopScreen();
                    },
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                ).then((_) {
                  // Check again after returning from shop
                  final newGems = ref.read(userProvider).gems;
                  if (newGems >= kSacredSpreadsDiamondCost) {
                    setState(() => _insufficientDiamonds = false);
                    _checkAndDeductDiamonds();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00D9FF),
                      Color(0xFF00A8CC),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D9FF).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.diamond,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Get Diamonds',
                      style: GoogleFonts.cinzel(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Go back button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Go Back',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PREMIUM PAYWALL
  // ===========================================================================

  Widget _buildPremiumPaywall(TarotReadingState state) {
    final cardCount = widget.selectedCards.length;
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Locked cards row (face down)
          _buildLockedCardsRow(cardCount, screenWidth),

          const SizedBox(height: 40),

          // Premium lock container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildPremiumLockCard(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLockedCardsRow(int cardCount, double screenWidth) {
    const double cardWidth = 90.0;
    const double cardHeight = 140.0;
    const double cardSpacing = 12.0;

    final totalCardsWidth = (cardCount * cardWidth) + ((cardCount - 1) * cardSpacing);
    final needsScrolling = totalCardsWidth > (screenWidth - 32);
    final centerPadding = needsScrolling
        ? 16.0
        : max(16.0, (screenWidth - totalCardsWidth) / 2);

    return SizedBox(
      height: cardHeight + 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: needsScrolling
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: centerPadding),
        itemCount: cardCount,
        separatorBuilder: (context, index) => const SizedBox(width: cardSpacing),
        itemBuilder: (context, index) {
          final position = widget.spread.positions[index];
          return _LockedCardWithLabel(
            position: position,
            index: index,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            gradientColors: widget.spread.gradientColors,
            pulseController: _pulseController,
          );
        },
      ),
    );
  }

  Widget _buildPremiumLockCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD700).withOpacity(0.15),
            AppColors.glassFill,
            AppColors.backgroundSecondary.withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Lock icon with glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glowOpacity = 0.3 + _pulseController.value * 0.4;
              final scale = 1.0 + _pulseController.value * 0.05;

              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFF8C00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(glowOpacity),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            'Unlock Your Reading',
            style: GoogleFonts.cinzel(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            'Your cards have been drawn and your reading awaits. Upgrade to Premium to reveal the cosmic insights hidden within.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 8),

          // Spread name badge
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: widget.spread.gradientColors.first.withOpacity(0.2),
              border: Border.all(
                color: widget.spread.gradientColors.first.withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.spread.icon,
                  size: 16,
                  color: widget.spread.gradientColors.first,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.spread.title} • ${widget.spread.cardCount} Cards',
                  style: AppTypography.labelMedium.copyWith(
                    color: widget.spread.gradientColors.first,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Premium features list
          _buildPremiumFeatures(),

          const SizedBox(height: 28),

          // CTA Button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return const DiamondShopScreen();
                  },
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFFF8C00),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Upgrade to Premium',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.02, 1.02),
                  duration: 1500.ms,
                )
                .shimmer(
                  color: Colors.white.withOpacity(0.3),
                  duration: 2000.ms,
                ),
          ),

          const SizedBox(height: 16),

          // Secondary action
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Maybe Later',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatures() {
    final features = [
      ('Unlimited Spread Readings', Icons.all_inclusive),
      ('AI-Powered Interpretations', Icons.auto_awesome),
      ('Save & Share Readings', Icons.bookmark_rounded),
      ('Exclusive Card Decks', Icons.style_rounded),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                ),
                child: Icon(
                  feature.$2,
                  size: 16,
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature.$1,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.check_circle,
                size: 18,
                color: const Color(0xFFFFD700).withOpacity(0.8),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // PHASE 2, 3, 4: READING CONTENT
  // ===========================================================================

  Widget _buildReadingContent(TarotReadingState state) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // User question (if provided)
          if (widget.userQuestion != null && widget.userQuestion!.isNotEmpty)
            _buildQuestionDisplay(),

          const SizedBox(height: 24),

          // Cards row
          _buildCardsRow(state),

          const SizedBox(height: 16),

          // Hint text
          if (!state.allCardsRevealed) _buildHintText(state),

          const SizedBox(height: 24),

          // Current card interpretation
          if (state.focusedCardIndex != null)
            _buildInterpretationCard(state)
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.1, end: 0),

          // Overall synthesis (shown after all cards revealed)
          if (state.allCardsRevealed)
            _buildOverallSynthesis(state)
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.15, end: 0),
        ],
      ),
    );
  }

  Widget _buildQuestionDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.glassFill,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: AppColors.primary.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '"${widget.userQuestion}"',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildCardsRow(TarotReadingState state) {
    final cardCount = state.response!.cardsAnalysis.length;
    final screenWidth = MediaQuery.of(context).size.width;

    // Card dimensions
    const double cardWidth = 90.0;
    const double cardHeight = 140.0;
    const double cardSpacing = 12.0;
    const double labelHeight = 30.0; // Space for position label above card

    // Calculate total width needed for all cards
    final totalCardsWidth = (cardCount * cardWidth) + ((cardCount - 1) * cardSpacing);

    // Determine if cards need scrolling or can be centered
    final needsScrolling = totalCardsWidth > (screenWidth - 32); // 32 = horizontal padding

    // Calculate centering padding
    final centerPadding = needsScrolling
        ? 16.0
        : max(16.0, (screenWidth - totalCardsWidth) / 2);

    return SizedBox(
      height: cardHeight + labelHeight + 16, // Card + label + padding
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: needsScrolling
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: centerPadding),
        itemCount: cardCount,
        separatorBuilder: (context, index) => const SizedBox(width: cardSpacing),
        itemBuilder: (context, index) {
          final card = state.response!.cardsAnalysis[index];
          final isRevealed = state.revealedCards.contains(index);
          final canReveal = index == state.currentRevealIndex;
          final isFocused = state.focusedCardIndex == index;

          return _TarotCardWithLabel(
            index: index,
            position: card.position,
            cardName: card.cardName,
            orientation: card.orientation,
            isRevealed: isRevealed,
            canReveal: canReveal,
            isFocused: isFocused,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            gradientColors: widget.spread.gradientColors,
            pulseController: _pulseController,
            onTap: () {
              if (canReveal && !isRevealed) {
                HapticFeedback.mediumImpact();
                ref.read(tarotReadingProvider(_readingId).notifier).revealCard(index);
              } else if (isRevealed) {
                ref.read(tarotReadingProvider(_readingId).notifier).setFocusedCard(index);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildHintText(TarotReadingState state) {
    final nextPosition = state.currentRevealIndex < state.response!.cardsAnalysis.length
        ? state.response!.cardsAnalysis[state.currentRevealIndex].position
        : '';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity = 0.6 + _pulseController.value * 0.4;
        return Text(
          state.currentRevealIndex == 0
              ? 'Tap the first card to reveal its meaning'
              : 'Tap to reveal: $nextPosition',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary.withOpacity(opacity),
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }

  Widget _buildInterpretationCard(TarotReadingState state) {
    final card = state.response!.cardsAnalysis[state.focusedCardIndex!];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.spread.gradientColors.first.withOpacity(0.15),
              AppColors.glassFill,
              AppColors.backgroundSecondary.withOpacity(0.9),
            ],
          ),
          border: Border.all(
            color: widget.spread.gradientColors.first.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.spread.gradientColors.first.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Position label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: widget.spread.gradientColors.first.withOpacity(0.2),
              ),
              child: Text(
                card.position.toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  color: widget.spread.gradientColors.first,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card name and orientation
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.cardName,
                    style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: card.orientation == 'Upright'
                        ? AppColors.success.withOpacity(0.2)
                        : AppColors.warning.withOpacity(0.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        card.orientation == 'Upright'
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: card.orientation == 'Upright'
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        card.orientation,
                        style: AppTypography.labelSmall.copyWith(
                          color: card.orientation == 'Upright'
                              ? AppColors.success
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    widget.spread.gradientColors.first.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Interpretation text
            Text(
              card.interpretation,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallSynthesis(TarotReadingState state) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: widget.spread.gradientColors,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'OVERALL SYNTHESIS',
                style: AppTypography.labelMedium.copyWith(
                  color: widget.spread.gradientColors.first,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Synthesis container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.spread.gradientColors.first.withOpacity(0.1),
                  widget.spread.gradientColors.last.withOpacity(0.05),
                  AppColors.backgroundSecondary.withOpacity(0.95),
                ],
              ),
              border: Border.all(
                color: widget.spread.gradientColors.first.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.spread.gradientColors.first.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Decorative element
                Icon(
                  Icons.all_inclusive,
                  color: widget.spread.gradientColors.first.withOpacity(0.6),
                  size: 32,
                ),
                const SizedBox(height: 16),

                Text(
                  state.response!.overallSynthesis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.crimsonText(
                    fontSize: 16,
                    height: 1.8,
                    color: AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 24),

                // Action button - New Reading
                Center(
                  child: _buildActionButton(
                    icon: Icons.refresh,
                    label: 'New Reading',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDisabled
              ? AppColors.glassFill.withOpacity(0.5)
              : AppColors.glassFill,
          border: Border.all(
            color: isDisabled
                ? AppColors.glassBorder.withOpacity(0.5)
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDisabled
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isDisabled
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Save reading to Grimoire (Firestore)
  Future<void> _saveReading(TarotReadingState state) async {
    if (_isSaving || _hasSaved || state.response == null) return;

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);

    try {
      final deviceId = ref.read(deviceIdProvider);
      final firestoreService = ref.read(firestoreReadingServiceProvider);

      // Build a combined interpretation from all cards
      final cards = state.response!.cardsAnalysis;
      final synthesis = state.response!.overallSynthesis;

      // Format: Position: CardName - Interpretation
      final cardSummary = cards.map((c) =>
        '${c.position}: ${c.cardName} (${c.orientation})'
      ).join('\n');

      final fullInterpretation = '''
${widget.spread.title} Reading

Cards:
$cardSummary

Overall Synthesis:
$synthesis
''';

      // Save the first card as primary, with full interpretation
      final primaryCard = cards.isNotEmpty ? cards.first : null;

      await firestoreService.saveReading(
        userId: deviceId,
        question: widget.userQuestion ?? 'Sacred Spreads: ${widget.spread.title}',
        cardName: primaryCard?.cardName ?? widget.spread.title,
        isUpright: primaryCard?.orientation == 'Upright',
        interpretation: fullInterpretation,
        characterId: 'sacred_spreads',
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasSaved = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reading saved to Grimoire ✨'),
            backgroundColor: widget.spread.gradientColors.first,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Share reading as text
  void _shareReading(TarotReadingState state) {
    if (state.response == null) return;

    HapticFeedback.lightImpact();

    final cards = state.response!.cardsAnalysis;
    final synthesis = state.response!.overallSynthesis;

    // Format shareable text
    final cardLines = cards.map((c) =>
      '🃏 ${c.position}: ${c.cardName} (${c.orientation})'
    ).join('\n');

    final shareText = '''
✨ ${widget.spread.title} Reading ✨

$cardLines

📜 Cosmic Insight:
$synthesis

🔮 Discover your destiny at mystic.app
''';

    Share.share(shareText, subject: '${widget.spread.title} Tarot Reading');
  }
}

// =============================================================================
// MYSTICAL LOADING INDICATOR
// =============================================================================

class _MysticalLoadingIndicator extends StatelessWidget {
  final AnimationController controller;
  final AnimationController pulseController;
  final List<Color> gradientColors;

  const _MysticalLoadingIndicator({
    required this.controller,
    required this.pulseController,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: controller.value * 2 * pi,
                child: CustomPaint(
                  size: const Size(140, 140),
                  painter: _RuneCirclePainter(
                    color: gradientColors.first,
                    progress: controller.value,
                  ),
                ),
              );
            },
          ),

          // Inner rotating ring (opposite direction)
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: -controller.value * 2 * pi * 0.7,
                child: CustomPaint(
                  size: const Size(100, 100),
                  painter: _RuneCirclePainter(
                    color: gradientColors.last,
                    progress: 1 - controller.value,
                    runeCount: 6,
                  ),
                ),
              );
            },
          ),

          // Center pulsing eye
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              final scale = 1.0 + pulseController.value * 0.15;
              final glowOpacity = 0.3 + pulseController.value * 0.4;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        gradientColors.first,
                        gradientColors.last.withOpacity(0.5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withOpacity(glowOpacity),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.remove_red_eye,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RuneCirclePainter extends CustomPainter {
  final Color color;
  final double progress;
  final int runeCount;

  _RuneCirclePainter({
    required this.color,
    required this.progress,
    this.runeCount = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;

    // Draw circle
    final circlePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw rune markers
    final runePaint = Paint()
      ..color = color.withOpacity(0.6 + progress * 0.4)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < runeCount; i++) {
      final angle = (i / runeCount) * 2 * pi;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      canvas.drawCircle(Offset(x, y), 4, runePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RuneCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// =============================================================================
// 3D FLIP CARD WIDGET
// =============================================================================

class _TarotCardWithLabel extends StatefulWidget {
  final int index;
  final String position;
  final String cardName;
  final String orientation;
  final bool isRevealed;
  final bool canReveal;
  final bool isFocused;
  final double cardWidth;
  final double cardHeight;
  final List<Color> gradientColors;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _TarotCardWithLabel({
    required this.index,
    required this.position,
    required this.cardName,
    required this.orientation,
    required this.isRevealed,
    required this.canReveal,
    required this.isFocused,
    required this.cardWidth,
    required this.cardHeight,
    required this.gradientColors,
    required this.pulseController,
    required this.onTap,
  });

  @override
  State<_TarotCardWithLabel> createState() => _TarotCardWithLabelState();
}

class _TarotCardWithLabelState extends State<_TarotCardWithLabel>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showFront = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _flipAnimation.addListener(() {
      if (_flipAnimation.value >= 0.5 && !_showFront) {
        setState(() => _showFront = true);
      }
    });
  }

  @override
  void didUpdateWidget(_TarotCardWithLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _flipController.forward();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Position label
        AnimatedBuilder(
          animation: widget.pulseController,
          builder: (context, child) {
            final glowOpacity = widget.canReveal
                ? 0.5 + widget.pulseController.value * 0.5
                : widget.isRevealed
                    ? 1.0
                    : 0.4;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              constraints: BoxConstraints(maxWidth: widget.cardWidth + 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.isFocused
                    ? widget.gradientColors.first.withOpacity(0.3)
                    : Colors.transparent,
                boxShadow: widget.canReveal
                    ? [
                        BoxShadow(
                          color: widget.gradientColors.first
                              .withOpacity(glowOpacity * 0.5),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.position.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: widget.isRevealed
                      ? widget.gradientColors.first
                      : widget.canReveal
                          ? widget.gradientColors.first.withOpacity(glowOpacity)
                          : AppColors.textTertiary,
                  letterSpacing: 1,
                  fontSize: 9,
                  fontWeight: widget.isFocused ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 6),

        // The card with 3D flip
        GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _flipAnimation,
            builder: (context, child) {
              final angle = _flipAnimation.value * pi;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(angle),
                child: _showFront
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildCardFront(),
                      )
                    : _buildCardBack(),
              );
            },
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: widget.index * 100 + 200),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          delay: Duration(milliseconds: widget.index * 100 + 200),
          duration: 400.ms,
        );
  }

  Widget _buildCardBack() {
    return AnimatedBuilder(
      animation: widget.pulseController,
      builder: (context, child) {
        final glowIntensity = widget.canReveal ? widget.pulseController.value : 0.0;

        return Container(
          width: widget.cardWidth,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (widget.canReveal)
                BoxShadow(
                  color: widget.gradientColors.first
                      .withOpacity(0.3 + glowIntensity * 0.4),
                  blurRadius: 15 + glowIntensity * 10,
                  spreadRadius: 2,
                ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Card back image or fallback gradient
                Image.asset(
                  TarotImageHelper.cardBackPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback gradient if image not found
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.backgroundPurple,
                            AppColors.primary.withOpacity(0.4),
                            AppColors.secondary.withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome,
                          size: widget.cardWidth * 0.4,
                          color: AppColors.primary.withOpacity(0.6),
                        ),
                      ),
                    );
                  },
                ),

                // Border overlay
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.canReveal
                          ? widget.gradientColors.first
                              .withOpacity(0.5 + glowIntensity * 0.5)
                          : AppColors.primary.withOpacity(0.4),
                      width: widget.canReveal ? 2.5 : 2,
                    ),
                  ),
                ),

                // Tap indicator
                if (widget.canReveal)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.touch_app,
                        size: 18,
                        color: widget.gradientColors.first.withOpacity(0.9),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn()
                          .then()
                          .fadeOut(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardFront() {
    final isUpright = widget.orientation == 'Upright';
    final assetPath = TarotImageHelper.getCardAssetPath(widget.cardName);
    final isMajorArcana = TarotImageHelper.isMajorArcana(widget.cardName);

    return Container(
      width: widget.cardWidth,
      height: widget.cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: widget.gradientColors.first.withOpacity(widget.isFocused ? 0.5 : 0.3),
            blurRadius: widget.isFocused ? 20 : 12,
            spreadRadius: widget.isFocused ? 3 : 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Card image (rotated if reversed)
            Transform.rotate(
              angle: isUpright ? 0 : pi,
              child: isMajorArcana
                  ? Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackCardFront();
                      },
                    )
                  : _buildFallbackCardFront(),
            ),

            // Border overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isFocused
                      ? widget.gradientColors.first
                      : widget.gradientColors.first.withOpacity(0.6),
                  width: widget.isFocused ? 2.5 : 2,
                ),
              ),
            ),

            // Card name overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  TarotImageHelper.getDisplayName(widget.cardName),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cinzel(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),

            // Reversed indicator
            if (!isUpright)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.arrow_downward,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fallback card front for Minor Arcana or missing images
  Widget _buildFallbackCardFront() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.gradientColors.first.withOpacity(0.8),
            widget.gradientColors.last.withOpacity(0.6),
            AppColors.backgroundSecondary,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Card symbol
          Icon(
            _getCardIcon(widget.cardName),
            size: widget.cardWidth * 0.4,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(height: 8),
          // Card name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.cardName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cinzel(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCardIcon(String cardName) {
    final name = cardName.toLowerCase();
    if (name.contains('fool')) return Icons.emoji_emotions;
    if (name.contains('magician')) return Icons.auto_fix_high;
    if (name.contains('priestess')) return Icons.visibility;
    if (name.contains('empress')) return Icons.spa;
    if (name.contains('emperor')) return Icons.gavel;
    if (name.contains('hierophant')) return Icons.account_balance;
    if (name.contains('lovers')) return Icons.favorite;
    if (name.contains('chariot')) return Icons.directions_car;
    if (name.contains('strength')) return Icons.fitness_center;
    if (name.contains('hermit')) return Icons.lightbulb;
    if (name.contains('wheel')) return Icons.casino;
    if (name.contains('justice')) return Icons.balance;
    if (name.contains('hanged')) return Icons.swap_vert;
    if (name.contains('death')) return Icons.autorenew;
    if (name.contains('temperance')) return Icons.water_drop;
    if (name.contains('devil')) return Icons.whatshot;
    if (name.contains('tower')) return Icons.flash_on;
    if (name.contains('star')) return Icons.star;
    if (name.contains('moon')) return Icons.nightlight;
    if (name.contains('sun')) return Icons.wb_sunny;
    if (name.contains('judgement')) return Icons.campaign;
    if (name.contains('world')) return Icons.public;
    // Minor Arcana suits
    if (name.contains('wand')) return Icons.spa;
    if (name.contains('cup')) return Icons.local_drink;
    if (name.contains('sword')) return Icons.content_cut;
    if (name.contains('pentacle') || name.contains('coin')) return Icons.paid;
    return Icons.style;
  }
}

// =============================================================================
// LOCKED CARD WIDGET (For Premium Paywall)
// =============================================================================

class _LockedCardWithLabel extends StatelessWidget {
  final String position;
  final int index;
  final double cardWidth;
  final double cardHeight;
  final List<Color> gradientColors;
  final AnimationController pulseController;

  const _LockedCardWithLabel({
    required this.position,
    required this.index,
    required this.cardWidth,
    required this.cardHeight,
    required this.gradientColors,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Position label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          constraints: BoxConstraints(maxWidth: cardWidth + 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: gradientColors.first.withOpacity(0.2),
          ),
          child: Text(
            position.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: gradientColors.first,
              letterSpacing: 1,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Locked card (face down with lock overlay)
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Card back image or fallback gradient
                    Image.asset(
                      TarotImageHelper.cardBackPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.backgroundPurple,
                                AppColors.primary.withOpacity(0.4),
                                AppColors.secondary.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.auto_awesome,
                              size: cardWidth * 0.4,
                              color: AppColors.primary.withOpacity(0.6),
                            ),
                          ),
                        );
                      },
                    ),

                    // Dark overlay for locked state
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),

                    // Lock icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: const Color(0xFFFFD700).withOpacity(0.9),
                        ),
                      ),
                    ),

                    // Border overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: index * 100 + 200),
          duration: 400.ms,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          delay: Duration(milliseconds: index * 100 + 200),
          duration: 400.ms,
        );
  }
}
