import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';

/// Spiritual intention options for onboarding.
enum SpiritualIntention {
  love,
  career,
  shadowWork,
  future,
  dailyGuidance,
  healing;

  String get label {
    switch (this) {
      case SpiritualIntention.love:
        return 'Love & Relationships';
      case SpiritualIntention.career:
        return 'Career & Purpose';
      case SpiritualIntention.shadowWork:
        return 'Shadow Work';
      case SpiritualIntention.future:
        return 'Future Insights';
      case SpiritualIntention.dailyGuidance:
        return 'Daily Guidance';
      case SpiritualIntention.healing:
        return 'Healing & Growth';
    }
  }

  IconData get icon {
    switch (this) {
      case SpiritualIntention.love:
        return Icons.favorite_rounded;
      case SpiritualIntention.career:
        return Icons.rocket_launch_rounded;
      case SpiritualIntention.shadowWork:
        return Icons.nightlight_rounded;
      case SpiritualIntention.future:
        return Icons.visibility_rounded;
      case SpiritualIntention.dailyGuidance:
        return Icons.wb_sunny_rounded;
      case SpiritualIntention.healing:
        return Icons.spa_rounded;
    }
  }

  Color get color {
    switch (this) {
      case SpiritualIntention.love:
        return const Color(0xFFFF6B9D);
      case SpiritualIntention.career:
        return const Color(0xFFFFB347);
      case SpiritualIntention.shadowWork:
        return const Color(0xFF9D7BFF);
      case SpiritualIntention.future:
        return const Color(0xFF64B5F6);
      case SpiritualIntention.dailyGuidance:
        return const Color(0xFFFFD54F);
      case SpiritualIntention.healing:
        return const Color(0xFF4DB6AC);
    }
  }
}

/// Screen for selecting spiritual intentions during onboarding.
class OnboardingIntentionScreen extends ConsumerStatefulWidget {
  /// Callback when the user completes this step
  final void Function(List<SpiritualIntention> intentions)? onComplete;

  /// Current onboarding step (0-indexed)
  final int currentStep;

  /// Total onboarding steps
  final int totalSteps;

  const OnboardingIntentionScreen({
    super.key,
    this.onComplete,
    this.currentStep = 3,
    this.totalSteps = 4,
  });

  @override
  ConsumerState<OnboardingIntentionScreen> createState() =>
      _OnboardingIntentionScreenState();
}

class _OnboardingIntentionScreenState
    extends ConsumerState<OnboardingIntentionScreen> {
  final Set<SpiritualIntention> _selectedIntentions = {};
  bool _showQuestion = false;
  bool _showChips = false;
  bool _showButton = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _startRitual();
  }

  Future<void> _startRitual() async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _showQuestion = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _showChips = true);
  }

  void _onIntentionToggled(SpiritualIntention intention) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIntentions.contains(intention)) {
        _selectedIntentions.remove(intention);
      } else {
        _selectedIntentions.add(intention);
      }
      if (_selectedIntentions.isNotEmpty && !_showButton) {
        _showButton = true;
      }
    });
  }

  Future<void> _onContinue() async {
    if (_selectedIntentions.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _isExiting = true);

    await Future.delayed(const Duration(milliseconds: 600));

    widget.onComplete?.call(_selectedIntentions.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MysticBackgroundScaffold(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLarge,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppConstants.spacingMedium),

                // Progress bar
                MysticProgressBar(
                  totalSteps: widget.totalSteps,
                  currentStep: widget.currentStep,
                ),

                const SizedBox(height: AppConstants.spacingLarge),

                // Question
                _buildQuestion(),

                const SizedBox(height: AppConstants.spacingMedium),

                // Intention options in scrollable container
                if (_showChips)
                  Expanded(
                    child: _buildIntentionChips(),
                  ),

                const SizedBox(height: AppConstants.spacingMedium),

                // Continue button
                _buildContinueButton(),

                const SizedBox(height: AppConstants.spacingLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    if (!_showQuestion) return const SizedBox(height: 100);

    Widget question = Column(
      children: [
        Text(
          'What brings you\nto the stars?',
          textAlign: TextAlign.center,
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSmall),
        Text(
          'Select all that resonate with your soul.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    question = question
        .animate()
        .fadeIn(duration: 800.ms, curve: Curves.easeOut)
        .slideY(begin: 0.2, end: 0, duration: 800.ms);

    if (_isExiting) {
      question = question.animate().fadeOut(duration: 400.ms).slideY(
            begin: 0,
            end: -0.2,
            duration: 400.ms,
          );
    }

    return question;
  }

  Widget _buildIntentionChips() {
    Widget chips = Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMedium),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: SpiritualIntention.values.asMap().entries.map((entry) {
              final index = entry.key;
              final intention = entry.value;
              final isSelected = _selectedIntentions.contains(intention);

              return _IntentionChip(
                intention: intention,
                isSelected: isSelected,
                onTap: () => _onIntentionToggled(intention),
                animationDelay: Duration(milliseconds: index * 80),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (_isExiting) {
      chips = chips.animate().fadeOut(duration: 400.ms).slideY(
            begin: 0,
            end: 0.1,
            duration: 400.ms,
          );
    }

    return chips;
  }

  Widget _buildContinueButton() {
    if (!_showButton || _selectedIntentions.isEmpty) {
      return const SizedBox(height: 56);
    }

    Widget button = GestureDetector(
      onTap: _onContinue,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXLarge,
          vertical: AppConstants.spacingMedium,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.mysticTeal,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppConstants.spacingSmall),
            Text(
              'Begin Your Journey',
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    button = button.animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );

    if (_isExiting) {
      button = button.animate().fadeOut(duration: 300.ms).scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(0.9, 0.9),
            duration: 300.ms,
          );
    }

    return button;
  }
}

/// Floating pill-shaped intention chip.
class _IntentionChip extends StatelessWidget {
  final SpiritualIntention intention;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _IntentionChip({
    required this.intention,
    required this.isSelected,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: isSelected
              ? intention.color.withOpacity(0.2)
              : AppColors.glassFill,
          border: Border.all(
            color: isSelected ? intention.color : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: intention.color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              intention.icon,
              color: isSelected ? intention.color : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              intention.label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? intention.color : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                color: intention.color,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay, duration: 400.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          delay: animationDelay,
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }
}

