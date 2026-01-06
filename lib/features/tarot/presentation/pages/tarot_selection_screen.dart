import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../../home/presentation/providers/character_provider.dart';
import '../widgets/card_dealing_widget.dart';
import '../widgets/tarot_card_fan.dart';
import 'tarot_reveal_screen.dart';

/// Phases of the tarot selection ritual.
enum TarotSelectionPhase {
  /// Initial phase - show messy stack for shuffle ritual
  shuffling,
  /// Cards are spread and ready for selection
  selection,
}

/// Screen where users select their tarot card.
class TarotSelectionScreen extends ConsumerStatefulWidget {
  /// Whether this screen is embedded in a tab (hides back button).
  final bool isTabMode;

  /// Whether to skip the shuffling phase and go directly to selection.
  final bool skipCharging;

  /// Optional initial question text.
  final String? initialQuestion;

  const TarotSelectionScreen({
    super.key,
    this.isTabMode = false,
    this.skipCharging = false,
    this.initialQuestion,
  });

  @override
  ConsumerState<TarotSelectionScreen> createState() =>
      _TarotSelectionScreenState();
}

class _TarotSelectionScreenState extends ConsumerState<TarotSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final FocusNode _questionFocusNode = FocusNode();

  bool _visionaryMode = true;
  int? _selectedCardIndex;
  bool _isTransitioning = false;

  /// Current phase of the selection ritual.
  late TarotSelectionPhase _phase;

  late AnimationController _headerController;
  late AnimationController _inputGlowController;
  late AnimationController _fanRevealController;

  @override
  void initState() {
    super.initState();

    // Set initial phase based on skipCharging
    _phase = widget.skipCharging
        ? TarotSelectionPhase.selection
        : TarotSelectionPhase.shuffling;

    // Set initial question if provided
    if (widget.initialQuestion != null) {
      _questionController.text = widget.initialQuestion!;
    }

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _inputGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fanRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // If skipping shuffle, show cards immediately
    if (widget.skipCharging) {
      _fanRevealController.forward();
    }

    _questionFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _questionFocusNode.dispose();
    _headerController.dispose();
    _inputGlowController.dispose();
    _fanRevealController.dispose();
    super.dispose();
  }

  /// Called when shuffle ritual is complete.
  void _onShuffleComplete() {
    setState(() {
      _phase = TarotSelectionPhase.selection;
    });
    _fanRevealController.forward();
    HapticFeedback.heavyImpact();
  }

  void _onCardSelected(int cardIndex) {
    if (_isTransitioning) return;

    setState(() {
      _selectedCardIndex = cardIndex;
      _isTransitioning = true; // Set transitioning IMMEDIATELY on selection
    });

    HapticFeedback.heavyImpact();

    // Wait for selection animation then navigate
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _navigateToProcessing(cardIndex);
      }
    });
  }

  void _navigateToProcessing(int cardIndex) {
    final cardName = majorArcana[cardIndex].name;

    // Randomly determine if card is upright (75% upright, 25% reversed)
    final random = Random();
    final isUpright = random.nextDouble() > 0.25;

    // Get the selected character ID
    final selectedCharacterId = ref.read(selectedCharacterIdProvider);

    // Navigate to reveal screen
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return TarotRevealScreen(
            question: _questionController.text.trim(),
            visionaryMode: _visionaryMode,
            cardIndex: cardIndex,
            cardName: cardName,
            isUpright: isUpright,
            characterId: selectedCharacterId,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    ).then((_) {
      // Reset state when returning
      if (mounted) {
        setState(() {
          _selectedCardIndex = null;
          _isTransitioning = false;
          // In tab mode, stay in selection phase (no need to re-shuffle)
          // Only reset to shuffling in non-tab mode if charging is enabled
          if (!widget.isTabMode && !widget.skipCharging) {
            _phase = TarotSelectionPhase.shuffling;
            _fanRevealController.reset();
          }
          // In tab mode or skipCharging, keep selection phase ready
        });
      }
    });
  }

  void _dismissKeyboard() {
    _questionFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // Use grid layout in tab mode, fan layout otherwise
    if (widget.isTabMode) {
      return _buildTabModeLayout(keyboardVisible);
    }

    return MysticBackgroundScaffold(
      child: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
          children: [
            // Header
            _buildHeader(),

            const Spacer(flex: 1),

            // Question Input Section
            if (!keyboardVisible || _selectedCardIndex == null)
              _buildQuestionInput()
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

            SizedBox(height: keyboardVisible ? 20 : 40),

            // Visionary Mode Toggle
            if (_selectedCardIndex == null)
              _buildVisionaryToggle()
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms),

            const Spacer(flex: 1),

            // Card Dealing Widget (handles both shuffling and selection)
            if (!keyboardVisible)
              SizedBox(
                height: 320,
                child: CardDealingWidget(
                  onDealingComplete: _onShuffleComplete,
                  onCardSelected: _onCardSelected,
                  selectedCardIndex: _selectedCardIndex,
                  selectionEnabled: _selectedCardIndex == null,
                  isTransitioning: _isTransitioning,
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

            const Spacer(flex: 2),

            // Instruction Text (shown when cards are dealt)
            if (_selectedCardIndex == null && !keyboardVisible && _phase == TarotSelectionPhase.selection)
              _buildInstructionText()
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 600.ms),

            const SizedBox(height: 40),
          ],
        ),
        ),
      ),
    );
  }

  /// Tab mode layout with grid cards
  Widget _buildTabModeLayout(bool keyboardVisible) {
    return MysticBackgroundScaffold(
      child: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              // Header (fixed)
              _buildHeader(),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Question Input Section
                      if (!keyboardVisible || _selectedCardIndex == null)
                        _buildQuestionInput()
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms),

                      const SizedBox(height: 16),

                      // Visionary Mode Toggle
                      if (_selectedCardIndex == null)
                        _buildVisionaryToggle()
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: 24),

                      // Card Dealing Widget (handles both shuffling and selection)
                      if (!keyboardVisible)
                        SizedBox(
                          height: 340,
                          child: CardDealingWidget(
                            onDealingComplete: _onShuffleComplete,
                            onCardSelected: _onCardSelected,
                            selectedCardIndex: _selectedCardIndex,
                            selectionEnabled: _selectedCardIndex == null,
                            isTransitioning: _isTransitioning,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Instruction Text
                      if (_selectedCardIndex == null && !keyboardVisible && _phase == TarotSelectionPhase.selection)
                        _buildInstructionText()
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 400.ms),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Tab mode - single line centered
    if (widget.isTabMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: Text(
            'ASK THE ORACLE',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.primary,
              letterSpacing: 3,
              fontSize: 22,
            ),
          )
              .animate(controller: _headerController)
              .fadeIn(duration: 800.ms)
              .shimmer(
                duration: 2000.ms,
                color: AppColors.primaryLight.withOpacity(0.3),
              ),
        ),
      );
    }

    // Non-tab mode - back button aligned with ASK text
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 24, top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button - top left, aligned with first line
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),

          // Title - centered in remaining space
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ASK',
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'THE ORACLE',
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primary,
                    letterSpacing: 6,
                  ),
                ),
              ],
            )
                .animate(controller: _headerController)
                .fadeIn(duration: 800.ms)
                .shimmer(
                  duration: 2000.ms,
                  color: AppColors.primaryLight.withOpacity(0.3),
                ),
          ),

          // Spacer to balance the back button
          const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _buildQuestionInput() {
    return AnimatedBuilder(
      animation: _inputGlowController,
      builder: (context, child) {
        final glowIntensity = _inputGlowController.value;
        final isFocused = _questionFocusNode.hasFocus;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? AppColors.primary.withOpacity(0.5 + glowIntensity * 0.3)
                  : AppColors.glassBorder,
              width: isFocused ? 1.5 : 1,
            ),
            color: AppColors.glassFill,
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color:
                          AppColors.primary.withOpacity(0.1 + glowIntensity * 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: _questionController,
            focusNode: _questionFocusNode,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 3,
            minLines: 1,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _dismissKeyboard(),
            decoration: InputDecoration(
              hintText: 'Focus on your question...',
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
            ),
            cursorColor: AppColors.primary,
          ),
        );
      },
    );
  }

  Widget _buildVisionaryToggle() {
    return AnimatedBuilder(
      animation: _inputGlowController,
      builder: (context, child) {
        final glowIntensity = _inputGlowController.value;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _visionaryMode = !_visionaryMode;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _visionaryMode
                    ? AppColors.secondary.withOpacity(0.5 + glowIntensity * 0.3)
                    : AppColors.glassBorder,
                width: _visionaryMode ? 1.5 : 1,
              ),
              color: _visionaryMode
                  ? AppColors.secondary.withOpacity(0.1)
                  : AppColors.glassFill,
              boxShadow: _visionaryMode
                  ? [
                      BoxShadow(
                        color: AppColors.secondary
                            .withOpacity(0.2 + glowIntensity * 0.15),
                        blurRadius: 15 + glowIntensity * 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI Icon
                Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: _visionaryMode
                      ? AppColors.secondary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
                // Text
                Flexible(
                  child: Text(
                    'AI Vision',
                    style: AppTypography.labelLarge.copyWith(
                      color: _visionaryMode
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Toggle
                _buildCustomSwitch(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomSwitch() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 48,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: _visionaryMode
            ? AppColors.secondary.withOpacity(0.3)
            : AppColors.backgroundSecondary,
        border: Border.all(
          color: _visionaryMode
              ? AppColors.secondary.withOpacity(0.5)
              : AppColors.glassBorder,
        ),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _visionaryMode ? 24 : 2,
            top: 2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _visionaryMode
                    ? AppColors.secondary
                    : AppColors.textTertiary,
                boxShadow: _visionaryMode
                    ? [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionText() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 8),
            Text(
              'Tap any card to reveal your message',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Trust your intuition',
          style: GoogleFonts.cinzel(
            fontSize: 12,
            color: AppColors.textTertiary.withOpacity(0.7),
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
