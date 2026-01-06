import 'dart:math' as math;
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
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../../chat/presentation/pages/chat_screen.dart';
import '../../../paywall/paywall.dart';
import '../../data/providers/tarot_provider.dart';
import '../../data/services/tarot_api_service.dart';
import '../../data/tarot_deck_assets.dart';
import '../widgets/flip_card.dart';
import '../widgets/swirling_particles.dart';
import '../widgets/typewriter_text.dart';

/// Screen that shows the tarot reading generation and reveal.
class TarotRevealScreen extends ConsumerStatefulWidget {
  /// The question asked by the user.
  final String question;

  /// Whether visionary mode (AI art) is enabled.
  final bool visionaryMode;

  /// The index of the selected card.
  final int cardIndex;

  /// The name of the selected card.
  final String cardName;

  /// Whether the card is upright (true) or reversed (false).
  final bool isUpright;

  /// The character ID providing the reading.
  final String characterId;

  const TarotRevealScreen({
    super.key,
    required this.question,
    required this.visionaryMode,
    required this.cardIndex,
    required this.cardName,
    this.isUpright = true,
    this.characterId = 'madame_luna',
  });

  @override
  ConsumerState<TarotRevealScreen> createState() => _TarotRevealScreenState();
}

class _TarotRevealScreenState extends ConsumerState<TarotRevealScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _revealController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // State
  bool _isRevealed = false; // Card flipped
  bool _showPaywallOverlay = false; // Show paywall on card
  bool _showInterpretation = false;
  bool _apiCallStarted = false;
  bool _savedToGrimoire = false; // Track if saved to Grimoire

  // Mystical loading messages
  static const List<String> _loadingMessages = [
    'Aligning the stars...',
    'Consulting the Oracle...',
    'Weaving your fate...',
    'Reading the cosmic threads...',
    'Channeling ancient wisdom...',
    'Unveiling the mysteries...',
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Flip animation - controlled programmatically
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onRevealComplete();
      }
    });

    // Start the API call
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startReading();
    });
  }

  void _startReading() {
    if (_apiCallStarted) return;
    _apiCallStarted = true;

    // Ask The Oracle is FREE - no gem cost required
    // visionaryMode just controls AI image generation, doesn't cost gems for this feature

    ref.read(tarotReadingProvider.notifier).generateReading(
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}', // TODO: Use real user ID
          question: widget.question.isEmpty ? 'General reading' : widget.question,
          spreadType: SpreadType.single,
          visionaryMode: widget.visionaryMode,
          cardName: widget.cardName,
          isUpright: widget.isUpright,
          characterId: widget.characterId,
        );
  }

  void _onRevealComplete() {
    // Wait a moment then show interpretation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showInterpretation = true;
        });
        // Save to Grimoire after interpretation is shown
        _saveToGrimoire();
      }
    });
  }

  /// Save the reading to Grimoire (Firestore) automatically
  Future<void> _saveToGrimoire() async {
    if (_savedToGrimoire) return; // Already saved

    final readingState = ref.read(tarotReadingProvider);
    final reading = readingState.reading;
    if (reading == null) return;

    try {
      final deviceId = ref.read(deviceIdProvider);
      final firestoreService = ref.read(firestoreReadingServiceProvider);

      await firestoreService.saveReading(
        userId: deviceId,
        question: widget.question.isEmpty ? 'General reading' : widget.question,
        cardName: reading.primaryCard?.name ?? widget.cardName,
        isUpright: reading.primaryCard?.isUpright ?? widget.isUpright,
        interpretation: reading.interpretation,
        imageUrl: widget.visionaryMode ? reading.imageUrl : null,
        characterId: widget.characterId,
      );

      _savedToGrimoire = true;
      debugPrint('✨ Reading saved to Grimoire');
    } catch (e) {
      debugPrint('❌ Failed to save to Grimoire: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _revealController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _onCardTap() {
    // Only handle paywall navigation
    if (_showPaywallOverlay) {
      debugPrint('🎴 Card tapped - navigating to paywall');
      _navigateToPaywall();
    }
  }

  void _navigateToPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallView(
          onClose: () {
            Navigator.of(context).pop();
            // Check if user is now premium after returning
            final isPremium = ref.read(isPremiumProvider);
            if (isPremium && mounted) {
              debugPrint('🎴 User is now premium! Removing blur and overlay...');
              setState(() {
                _showPaywallOverlay = false; // Remove blur and overlay
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readingState = ref.watch(tarotReadingProvider);

    // Listen for state changes - flip card when reading is ready
    ref.listen<TarotReadingState>(tarotReadingProvider, (previous, next) {
      if (next.hasReading && !_isRevealed) {
        debugPrint('🎴 Reading received! Flipping card...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isRevealed) {
            HapticFeedback.heavyImpact();

            // Ask The Oracle is FREE for everyone - no premium check needed
            setState(() {
              _isRevealed = true;
              _showPaywallOverlay = false; // Always free for Ask The Oracle
            });
            _flipController.forward();
          }
        });
      }
    });

    return MysticBackgroundScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            // Swirling particles (only during loading)
            if (!_isRevealed)
              Positioned.fill(
                child: SwirlingParticles(
                  particleCount: 40,
                  radius: 180,
                  speed: 0.8,
                  isActive: readingState.isLoading,
                ),
              ),

            // Main content
            Column(
              children: [
                // Header
                _buildHeader(),

                const Spacer(flex: 2),

                // Card
                _buildCard(readingState),

                const SizedBox(height: 32),

                // Loading text or interpretation
                Expanded(
                  flex: 4,
                  child: _buildBottomContent(readingState),
                ),

                const SizedBox(height: 24),
              ],
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
            onPressed: () {
              ref.read(tarotReadingProvider.notifier).clearReading();
              Navigator.of(context).pop();
            },
            icon: const Icon(
              Icons.close,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          const Spacer(),
          if (widget.visionaryMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI Vision',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }

  Widget _buildCard(TarotReadingState state) {
    final reading = state.reading;
    final primaryCard = reading?.primaryCard;

    // Get the card name for asset lookup
    final cardName = primaryCard?.name ?? widget.cardName;

    // Get asset path for standard deck (non-visionary mode)
    // Also used as fallback if AI image fails to load
    final assetPath = TarotDeckAssets.getCardByName(cardName);

    // Only show loading if API is still in progress AND visionary mode is on
    final isImageLoading = widget.visionaryMode && state.isLoading;

    return GestureDetector(
      onTap: _onCardTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The flip card - wrapped in AbsorbPointer
          AbsorbPointer(
            absorbing: true,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _flipAnimation]),
              builder: (context, child) {
                final pulseValue = _pulseController.value;
                final flipAngle = _flipAnimation.value * math.pi;
                final showBack = flipAngle <= math.pi / 2;

                // Calculate glow intensity based on loading state
                double glowIntensity;
                if (state.isLoading) {
                  glowIntensity = pulseValue;
                } else {
                  glowIntensity = 0.3;
                }

                return Container(
                  width: 200,
                  height: 340,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective
                        ..rotateY(flipAngle),
                      child: showBack
                          ? TarotCardBackLarge(
                              glowIntensity: glowIntensity,
                              width: 200,
                              height: 340,
                            )
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    // Card front - BLURRED if paywall showing
                                    ImageFiltered(
                                      imageFilter: _showPaywallOverlay
                                          ? ImageFilter.blur(sigmaX: 15, sigmaY: 15)
                                          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                                      child: TarotCardFrontLarge(
                                        imageUrl: widget.visionaryMode ? reading?.imageUrl : null,
                                        assetPath: assetPath,
                                        cardName: cardName,
                                        isUpright: primaryCard?.isUpright ?? true,
                                        isLoading: isImageLoading,
                                        width: 200,
                                        height: 340,
                                      ),
                                    ),
                                    // Paywall overlay ON the card front
                                    if (_showPaywallOverlay) _buildCardPaywallOverlay(),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),

          ],
        ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 600.ms);
  }

  /// Paywall overlay that appears ON the card front (blurred image behind)
  Widget _buildCardPaywallOverlay() {
    const goldAccent = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);

    return Positioned.fill(
      child: GestureDetector(
        onTap: _navigateToPaywall,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon with glow
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: goldAccent.withValues(alpha: 0.5),
                      blurRadius: 25,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [goldAccent, goldDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'The cards vibrate\nwith energy...',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Unlock button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: goldAccent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goldAccent.withValues(alpha: 0.25),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [goldAccent, goldDark],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [goldAccent, goldDark],
                      ).createShader(bounds),
                      child: Text(
                        'Reveal Destiny',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent(TarotReadingState state) {
    if (state.hasError) {
      return _buildErrorState(state.error!);
    }

    if (!_isRevealed) {
      return _buildLoadingState(state);
    }

    return _buildRevealedState(state);
  }

  Widget _buildLoadingState(TarotReadingState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Cycling mystical text
        CyclingMysticalText(
          messages: _loadingMessages,
          displayDuration: const Duration(seconds: 2),
          style: GoogleFonts.cinzel(
            fontSize: 16,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 24),

        // Progress indicator
        SizedBox(
          width: 200,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.progress > 0 ? state.progress : null,
                  backgroundColor: AppColors.backgroundSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary.withValues(alpha: 0.7),
                  ),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(state.progress * 100).toInt()}%',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Question display
        if (widget.question.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                Text(
                  'Your Question',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${widget.question}"',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRevealedState(TarotReadingState state) {
    final reading = state.reading;
    final primaryCard = reading?.primaryCard;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Card name with glow
          if (_showInterpretation) ...[
            Text(
              primaryCard?.name.toUpperCase() ?? widget.cardName.toUpperCase(),
              style: GoogleFonts.cinzel(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 3,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .shimmer(duration: 2000.ms, color: AppColors.primaryLight.withValues(alpha: 0.3)),

            const SizedBox(height: 8),

            // Upright/Reversed indicator
            if (primaryCard != null)
              Text(
                primaryCard.isUpright ? 'Upright' : 'Reversed',
                style: AppTypography.labelMedium.copyWith(
                  color: primaryCard.isUpright
                      ? AppColors.mysticTeal
                      : AppColors.secondary,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // Divider
            Container(
              width: 100,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).scaleX(begin: 0, end: 1, duration: 500.ms),

            const SizedBox(height: 24),

            // Interpretation - Full text for everyone (Ask The Oracle is FREE)
            if (reading?.interpretation != null)
              TypewriterRichText(
                text: reading!.interpretation,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.8,
                ),
                textAlign: TextAlign.center,
                characterDelay: const Duration(milliseconds: 25),
                initialDelay: const Duration(milliseconds: 500),
              ),

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final reading = ref.watch(tarotReadingProvider).reading;

    return Column(
      children: [
        // Chat with Oracle button (Primary CTA) - FREE for everyone
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return ChatScreen(
                    characterId: widget.characterId,
                    initialInterpretation: reading?.interpretation,
                    cardName: reading?.primaryCard?.name ?? widget.cardName,
                  );
                },
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.2),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Chat with Oracle',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.secondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 1800.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        // New Reading button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            ref.read(tarotReadingProvider.notifier).clearReading();
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  'New Reading',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(delay: 2200.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'The spirits are silent...',
            style: GoogleFonts.cinzel(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              ref.read(tarotReadingProvider.notifier).clearReading();
              _apiCallStarted = false;
              _startReading();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Try Again',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Share the reading as text
  void _shareReading() {
    final readingState = ref.read(tarotReadingProvider);
    final reading = readingState.reading;
    if (reading == null) return;

    final cardName = reading.primaryCard?.name ?? widget.cardName;
    final orientation = (reading.primaryCard?.isUpright ?? widget.isUpright) ? 'Upright' : 'Reversed';
    final interpretation = reading.interpretation;

    final shareText = '''
✨ Ask The Oracle ✨

🃏 Card: $cardName ($orientation)

❓ Question: ${widget.question.isEmpty ? 'General reading' : widget.question}

📜 Oracle's Wisdom:
$interpretation

🔮 Discover your destiny at mystic.app
''';

    Share.share(shareText, subject: 'Tarot Reading - $cardName');
  }
}
