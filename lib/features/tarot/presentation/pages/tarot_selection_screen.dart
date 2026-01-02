import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../widgets/energy_charge_widget.dart';
import '../widgets/tarot_card_fan.dart';
import 'tarot_reveal_screen.dart';

/// Phases of the tarot selection ritual.
enum TarotSelectionPhase {
  /// Initial phase - show energy charge widget
  charging,
  /// Cards are spread and ready for selection
  selection,
}

/// Screen where users select their tarot card.
class TarotSelectionScreen extends ConsumerStatefulWidget {
  const TarotSelectionScreen({super.key});

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
  TarotSelectionPhase _phase = TarotSelectionPhase.charging;

  late AnimationController _headerController;
  late AnimationController _inputGlowController;
  late AnimationController _fanRevealController;

  @override
  void initState() {
    super.initState();
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

  /// Called when energy charging is complete.
  void _onChargeComplete() {
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
    setState(() {
      _isTransitioning = true;
    });

    final cardName = majorArcana[cardIndex].name;

    // Randomly determine if card is upright (75% upright, 25% reversed)
    final random = Random();
    final isUpright = random.nextDouble() > 0.25;

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
    final isCharging = _phase == TarotSelectionPhase.charging;

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
            if (_selectedCardIndex == null && !isCharging)
              _buildVisionaryToggle()
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms),

            const Spacer(flex: 1),

            // Energy Charge Widget (Charging Phase)
            if (isCharging && !keyboardVisible)
              EnergyChargeWidget(
                onChargeComplete: _onChargeComplete,
                chargeDuration: const Duration(seconds: 3),
              ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

            // Card Fan (Selection Phase)
            if (!isCharging && !keyboardVisible)
              AnimatedBuilder(
                animation: _fanRevealController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (_fanRevealController.value * 0.2),
                    child: Opacity(
                      opacity: _fanRevealController.value,
                      child: SizedBox(
                        height: 220,
                        child: TarotCardFan(
                          onCardSelected: _onCardSelected,
                          selectedCardIndex: _selectedCardIndex,
                          selectionEnabled: _selectedCardIndex == null,
                        ),
                      ),
                    ),
                  );
                },
              ),

            const Spacer(flex: 2),

            // Instruction Text
            if (_selectedCardIndex == null && !keyboardVisible && !isCharging)
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'TAROT',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.primary,
              letterSpacing: 4,
            ),
          )
              .animate(controller: _headerController)
              .fadeIn(duration: 800.ms)
              .shimmer(
                duration: 2000.ms,
                color: AppColors.primaryLight.withOpacity(0.3),
              ),
          const Spacer(),
          const SizedBox(width: 48), // Balance the back button
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
              'Scroll and tap to select your card',
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
