import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/audio_player_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../../../shared/widgets/mystic_audio_player/mystic_audio_player.dart';
import '../../../chat/presentation/pages/chat_screen.dart';
import '../../data/providers/tarot_provider.dart';
import '../../data/services/tarot_api_service.dart';
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

  const TarotRevealScreen({
    super.key,
    required this.question,
    required this.visionaryMode,
    required this.cardIndex,
    required this.cardName,
  });

  @override
  ConsumerState<TarotRevealScreen> createState() => _TarotRevealScreenState();
}

class _TarotRevealScreenState extends ConsumerState<TarotRevealScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _revealController;

  // State
  bool _isRevealed = false;
  bool _showInterpretation = false;
  bool _apiCallStarted = false;
  bool _ttsAvailable = false;
  bool _showListenButton = false;

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

    // Start the API call
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startReading();
      _checkTtsAvailability();
    });
  }

  Future<void> _checkTtsAvailability() async {
    try {
      final ttsService = ref.read(ttsServiceProvider);
      final available = await ttsService.isAvailable();
      if (mounted) {
        setState(() {
          _ttsAvailable = available;
        });
      }
    } catch (e) {
      // Silently fail - TTS is optional
      debugPrint('TTS availability check failed: $e');
    }
  }

  void _startReading() {
    if (_apiCallStarted) return;
    _apiCallStarted = true;

    ref.read(tarotReadingProvider.notifier).generateReading(
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}', // TODO: Use real user ID
          question: widget.question.isEmpty ? 'General reading' : widget.question,
          spreadType: SpreadType.single,
          visionaryMode: widget.visionaryMode,
          cardName: widget.cardName,
        );
  }

  void _onRevealComplete() {
    // Wait a moment then show interpretation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showInterpretation = true;
        });

        // Show listen button after interpretation starts appearing
        // (delay based on typical interpretation length)
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _ttsAvailable) {
            setState(() {
              _showListenButton = true;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    // Stop audio playback when leaving the screen
    ref.read(audioPlayerProvider.notifier).stop();
    _pulseController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readingState = ref.watch(tarotReadingProvider);

    // Listen for state changes
    ref.listen<TarotReadingState>(tarotReadingProvider, (previous, next) {
      if (next.hasReading && !_isRevealed) {
        // Reading received - trigger reveal after a brief pause
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            HapticFeedback.heavyImpact();
            setState(() {
              _isRevealed = true;
            });
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

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;

        // Only show loading if API is still in progress AND visionary mode is on
        final isImageLoading = widget.visionaryMode && state.isLoading;

        return FlipCard(
          showFront: _isRevealed,
          duration: const Duration(milliseconds: 1000),
          onFlipComplete: _onRevealComplete,
          back: TarotCardBackLarge(
            glowIntensity: state.isLoading ? pulseValue : 0.3,
            width: 200,
            height: 340,
          ),
          front: TarotCardFrontLarge(
            imageUrl: widget.visionaryMode ? reading?.imageUrl : null,
            cardName: primaryCard?.name ?? widget.cardName,
            isUpright: primaryCard?.isUpright ?? true,
            isLoading: isImageLoading,
            width: 200,
            height: 340,
          ),
        );
      },
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 600.ms);
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

            // Interpretation with typewriter effect
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

            // Listen button (only shown if TTS is available)
            if (_showListenButton && reading?.interpretation != null)
              ListenButton(
                text: reading!.interpretation,
                characterId: 'madame_luna',
                onPlayStart: () {
                  HapticFeedback.lightImpact();
                },
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

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
        // Chat with Oracle button (Primary CTA)
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return ChatScreen(
                    characterId: 'madame_luna',
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
                Icon(
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
            .slideY(begin: 0.2, end: 0)
            .then()
            .shimmer(
              duration: 2000.ms,
              color: AppColors.secondaryLight.withValues(alpha: 0.3),
            ),

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

        const SizedBox(height: 12),

        // Share button (optional)
        TextButton(
          onPressed: () {
            // TODO: Implement share functionality
            HapticFeedback.selectionClick();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.share_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Share',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 2400.ms, duration: 500.ms),
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
}
