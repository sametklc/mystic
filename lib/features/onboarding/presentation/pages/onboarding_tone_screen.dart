import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/widgets/widgets.dart';

/// Preferred tone options for onboarding.
enum PreferredTone {
  gentle,
  brutal;

  String get title {
    switch (this) {
      case PreferredTone.gentle:
        return 'Gentle Light';
      case PreferredTone.brutal:
        return 'Brutal Truth';
    }
  }

  String get subtitle {
    switch (this) {
      case PreferredTone.gentle:
        return 'Compassionate, uplifting, and supportive.';
      case PreferredTone.brutal:
        return 'Direct, honest, and unvarnished.';
    }
  }

  String get description {
    switch (this) {
      case PreferredTone.gentle:
        return 'Focus on hope, possibilities, and the light within every situation.';
      case PreferredTone.brutal:
        return 'Focus on shadow work, hard realities, and transformative truth.';
    }
  }

  IconData get icon {
    switch (this) {
      case PreferredTone.gentle:
        return Icons.wb_sunny_rounded;
      case PreferredTone.brutal:
        return Icons.bolt_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case PreferredTone.gentle:
        return const Color(0xFFFFD54F);
      case PreferredTone.brutal:
        return const Color(0xFFE57373);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case PreferredTone.gentle:
        return const Color(0xFFFFF176);
      case PreferredTone.brutal:
        return const Color(0xFFFF8A80);
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case PreferredTone.gentle:
        return [
          const Color(0xFFFFD54F).withOpacity(0.3),
          const Color(0xFFFFE082).withOpacity(0.1),
        ];
      case PreferredTone.brutal:
        return [
          const Color(0xFFE57373).withOpacity(0.3),
          const Color(0xFFEF5350).withOpacity(0.1),
        ];
    }
  }
}

/// Screen for selecting preferred tone during onboarding.
/// "The Oracle's Voice"
class OnboardingToneScreen extends ConsumerStatefulWidget {
  /// Callback when the user completes this step
  final void Function(PreferredTone tone)? onComplete;

  /// Current onboarding step (0-indexed)
  final int currentStep;

  /// Total onboarding steps
  final int totalSteps;

  const OnboardingToneScreen({
    super.key,
    this.onComplete,
    this.currentStep = 5,
    this.totalSteps = 6,
  });

  @override
  ConsumerState<OnboardingToneScreen> createState() =>
      _OnboardingToneScreenState();
}

class _OnboardingToneScreenState extends ConsumerState<OnboardingToneScreen> {
  PreferredTone? _selectedTone;
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

  void _onToneSelected(PreferredTone tone) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedTone = tone;
      if (!_showButton) _showButton = true;
    });
  }

  Future<void> _onContinue() async {
    if (_selectedTone == null) return;

    HapticFeedback.heavyImpact();
    setState(() => _isExiting = true);

    await Future.delayed(const Duration(milliseconds: 600));

    widget.onComplete?.call(_selectedTone!);
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

                // Tone cards - split screen style
                if (_showCards) Expanded(child: _buildToneCards()),

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
          "The Oracle's Voice",
          textAlign: TextAlign.center,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How should the Oracle\nspeak to you?',
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            height: 1.3,
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

  Widget _buildToneCards() {
    Widget cards = Column(
      children: PreferredTone.values.asMap().entries.map((entry) {
        final index = entry.key;
        final tone = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < PreferredTone.values.length - 1 ? 20 : 0,
            ),
            child: _ToneSplitCard(
              tone: tone,
              isSelected: _selectedTone == tone,
              onTap: () => _onToneSelected(tone),
              animationDelay: Duration(milliseconds: index * 200),
            ),
          ),
        );
      }).toList(),
    );

    if (_isExiting) {
      cards = cards.animate().fadeOut(duration: 400.ms).scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(0.95, 0.95),
            duration: 400.ms,
          );
    }

    return cards;
  }

  Widget _buildContinueButton() {
    if (!_showButton || _selectedTone == null) {
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
              'Complete Your Journey',
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

/// Large split-screen tone selection card.
class _ToneSplitCard extends StatelessWidget {
  final PreferredTone tone;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _ToneSplitCard({
    required this.tone,
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
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? tone.gradientColors
                : [
                    AppColors.glassFill,
                    AppColors.glassFill.withOpacity(0.5),
                  ],
          ),
          border: Border.all(
            color: isSelected ? tone.primaryColor : AppColors.glassBorder,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tone.primaryColor.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Background decoration circles
            if (isSelected) ...[
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone.primaryColor.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone.secondaryColor.withOpacity(0.08),
                  ),
                ),
              ),
            ],
            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Large icon on left
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? tone.primaryColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.08),
                      border: Border.all(
                        color: isSelected
                            ? tone.primaryColor.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: tone.primaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      tone.icon,
                      color: isSelected
                          ? tone.primaryColor
                          : AppColors.textSecondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text content on right
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          tone.title,
                          style: AppTypography.titleLarge.copyWith(
                            color: isSelected
                                ? tone.primaryColor
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle
                        Text(
                          tone.subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: isSelected
                                ? tone.primaryColor.withOpacity(0.8)
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          tone.description,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (isSelected)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone.primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: tone.primaryColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay, duration: 500.ms)
        .slideY(
          begin: 0.15,
          end: 0,
          delay: animationDelay,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

