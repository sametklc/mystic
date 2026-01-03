import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';

/// Esoteric knowledge level options for onboarding.
enum KnowledgeLevel {
  novice,
  seeker,
  adept;

  String get title {
    switch (this) {
      case KnowledgeLevel.novice:
        return 'The Novice';
      case KnowledgeLevel.seeker:
        return 'The Seeker';
      case KnowledgeLevel.adept:
        return 'The Adept';
    }
  }

  String get description {
    switch (this) {
      case KnowledgeLevel.novice:
        return "I'm new to this world.";
      case KnowledgeLevel.seeker:
        return 'I know my Sun sign and some cards.';
      case KnowledgeLevel.adept:
        return 'I speak the language of the stars.';
    }
  }

  String get detailedDescription {
    switch (this) {
      case KnowledgeLevel.novice:
        return 'Perfect for beginners. We\'ll explain mystical concepts in simple, accessible terms.';
      case KnowledgeLevel.seeker:
        return 'A balanced approach mixing familiar terms with deeper insights.';
      case KnowledgeLevel.adept:
        return 'Full astrological terminology and advanced symbolic analysis.';
    }
  }

  IconData get icon {
    switch (this) {
      case KnowledgeLevel.novice:
        return Icons.wb_twilight_rounded;
      case KnowledgeLevel.seeker:
        return Icons.explore_rounded;
      case KnowledgeLevel.adept:
        return Icons.auto_awesome_rounded;
    }
  }

  Color get color {
    switch (this) {
      case KnowledgeLevel.novice:
        return const Color(0xFF64B5F6);
      case KnowledgeLevel.seeker:
        return const Color(0xFFFFB74D);
      case KnowledgeLevel.adept:
        return const Color(0xFFBA68C8);
    }
  }
}

/// Screen for selecting esoteric knowledge level during onboarding.
/// "The Initiate's Path"
class OnboardingKnowledgeScreen extends ConsumerStatefulWidget {
  /// Callback when the user completes this step
  final void Function(KnowledgeLevel level)? onComplete;

  /// Current onboarding step (0-indexed)
  final int currentStep;

  /// Total onboarding steps
  final int totalSteps;

  const OnboardingKnowledgeScreen({
    super.key,
    this.onComplete,
    this.currentStep = 4,
    this.totalSteps = 6,
  });

  @override
  ConsumerState<OnboardingKnowledgeScreen> createState() =>
      _OnboardingKnowledgeScreenState();
}

class _OnboardingKnowledgeScreenState
    extends ConsumerState<OnboardingKnowledgeScreen> {
  KnowledgeLevel? _selectedLevel;
  bool _showQuestion = false;
  bool _showCards = false;
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
    setState(() => _showCards = true);
  }

  void _onLevelSelected(KnowledgeLevel level) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLevel = level;
      if (!_showButton) _showButton = true;
    });
  }

  Future<void> _onContinue() async {
    if (_selectedLevel == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isExiting = true);

    await Future.delayed(const Duration(milliseconds: 600));

    widget.onComplete?.call(_selectedLevel!);
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

                // Knowledge level cards
                if (_showCards) Expanded(child: _buildKnowledgeCards()),

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
    if (!_showQuestion) return const SizedBox(height: 60);

    Widget question = Column(
      children: [
        Text(
          "The Initiate's Path",
          textAlign: TextAlign.center,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How familiar are you\nwith the mystic arts?',
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This helps us speak your language.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
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

  Widget _buildKnowledgeCards() {
    Widget cards = Column(
      children: KnowledgeLevel.values.asMap().entries.map((entry) {
        final index = entry.key;
        final level = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < KnowledgeLevel.values.length - 1 ? 16 : 0,
            ),
            child: _KnowledgeLevelCard(
              level: level,
              isSelected: _selectedLevel == level,
              onTap: () => _onLevelSelected(level),
              animationDelay: Duration(milliseconds: index * 150),
            ),
          ),
        );
      }).toList(),
    );

    if (_isExiting) {
      cards = cards.animate().fadeOut(duration: 400.ms).slideY(
            begin: 0,
            end: 0.1,
            duration: 400.ms,
          );
    }

    return cards;
  }

  Widget _buildContinueButton() {
    if (!_showButton || _selectedLevel == null) {
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
          border: Border.all(
            color: AppColors.primary.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Continue',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSmall),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );

    button = button.animate().fadeIn(duration: 400.ms).slideY(
          begin: 0.3,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeOut,
        );

    if (_isExiting) {
      button = button.animate().fadeOut(duration: 300.ms);
    }

    return button;
  }
}

/// Full-height knowledge level card that fills available space.
class _KnowledgeLevelCard extends StatelessWidget {
  final KnowledgeLevel level;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _KnowledgeLevelCard({
    required this.level,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          color: isSelected
              ? level.color.withOpacity(0.15)
              : AppColors.glassFill,
          border: Border.all(
            color: isSelected ? level.color : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: level.color.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? level.color.withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: isSelected
                        ? level.color.withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  level.icon,
                  color: isSelected ? level.color : AppColors.textSecondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              // Text content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: AppTypography.titleMedium.copyWith(
                        color: isSelected ? level.color : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      level.detailedDescription,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Selection indicator
              if (isSelected)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: level.color.withOpacity(0.2),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: level.color,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay, duration: 400.ms)
        .slideX(
          begin: 0.1,
          end: 0,
          delay: animationDelay,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

