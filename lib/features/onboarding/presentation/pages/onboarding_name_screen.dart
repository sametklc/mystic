import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';

/// Gender options for onboarding.
enum Gender {
  female,
  male,
  other;

  String get label {
    switch (this) {
      case Gender.female:
        return 'Female';
      case Gender.male:
        return 'Male';
      case Gender.other:
        return 'Other';
    }
  }

  /// Venus symbol for female, Mars for male, Star for other
  String get symbol {
    switch (this) {
      case Gender.female:
        return '♀';
      case Gender.male:
        return '♂';
      case Gender.other:
        return '✧';
    }
  }

  IconData get icon {
    switch (this) {
      case Gender.female:
        return Icons.spa_rounded; // Rose-like
      case Gender.male:
        return Icons.shield_rounded; // Sword/Shield
      case Gender.other:
        return Icons.auto_awesome_rounded; // Cosmic star
    }
  }

  Color get color {
    switch (this) {
      case Gender.female:
        return const Color(0xFFFF6B9D); // Pink
      case Gender.male:
        return const Color(0xFF64B5F6); // Blue
      case Gender.other:
        return const Color(0xFFFFD54F); // Gold
    }
  }
}

/// The first step of the onboarding ritual.
/// A cinematic experience where the user is greeted and asked for their name and gender.
class OnboardingNameScreen extends ConsumerStatefulWidget {
  /// Callback when the user completes this step
  final VoidCallback? onComplete;

  const OnboardingNameScreen({
    super.key,
    this.onComplete,
  });

  @override
  ConsumerState<OnboardingNameScreen> createState() =>
      _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends ConsumerState<OnboardingNameScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Animation state
  bool _showGreeting = false;
  bool _showQuestion = false;
  bool _showInput = false;
  bool _showGenderSelector = false;
  bool _showButton = false;
  bool _isExiting = false;
  bool _hasValidName = false;

  // Gender selection
  Gender? _selectedGender;

  @override
  void initState() {
    super.initState();
    _startRitual();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final hasValid = _nameController.text.trim().length >= 2;
    if (hasValid != _hasValidName) {
      setState(() {
        _hasValidName = hasValid;
        // Show gender selector when user starts typing a valid name
        if (hasValid && !_showGenderSelector) {
          _showGenderSelector = true;
        }
      });
    }
  }

  /// Orchestrates the entrance animation sequence
  Future<void> _startRitual() async {
    // Brief pause before anything appears
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _showGreeting = true);

    // Wait for greeting to settle, then show question
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;
    setState(() => _showQuestion = true);

    // Show input shortly after question
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _showInput = true);

    // Focus the input field
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  /// Check if we can proceed
  bool get _canProceed => _hasValidName && _selectedGender != null;

  /// Show the continue button when requirements are met
  void _maybeShowButton() {
    if (_canProceed && !_showButton) {
      setState(() => _showButton = true);
    }
  }

  void _onGenderSelected(Gender gender) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedGender = gender;
    });
  }

  /// Handle submission of the name and gender
  Future<void> _onSubmit() async {
    final name = _nameController.text.trim();
    if (name.length < 2 || _selectedGender == null) return;

    // Save the name and gender to the provider
    ref.read(userProvider.notifier).setName(name);
    ref.read(userProvider.notifier).setGender(_selectedGender!.name);

    // Start exit animation
    setState(() => _isExiting = true);

    // Wait for exit animation to complete
    await Future.delayed(const Duration(milliseconds: 800));

    // Trigger completion callback
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Show button when requirements are met
    if (_canProceed && !_showButton && _showInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowButton();
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: MysticBackgroundScaffold(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingLarge,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // Greeting Text
                          _buildGreeting(),

                          const SizedBox(height: AppConstants.spacingXXLarge),

                          // Question Text
                          _buildQuestion(),

                          const SizedBox(height: AppConstants.spacingXLarge),

                          // Name Input
                          _buildNameInput(),

                          const SizedBox(height: AppConstants.spacingLarge),

                          // Gender Selector
                          _buildGenderSelector(),

                          const Spacer(flex: 2),

                          // Continue Button
                          _buildContinueButton(),

                          const SizedBox(height: AppConstants.spacingXXLarge),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    if (!_showGreeting) return const SizedBox(height: 60);

    Widget greeting = Text(
      'Welcome to your\nspiritual journey.',
      textAlign: TextAlign.center,
      style: AppTypography.displaySmall.copyWith(
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );

    // Apply entrance animation
    greeting = greeting
        .animate()
        .fadeIn(
          duration: 1200.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 1200.ms,
          curve: Curves.easeOutCubic,
        );

    // Apply exit animation if exiting
    if (_isExiting) {
      greeting = greeting
          .animate()
          .fadeOut(
            duration: 600.ms,
            curve: Curves.easeIn,
          )
          .slideY(
            begin: 0,
            end: -0.3,
            duration: 600.ms,
            curve: Curves.easeInCubic,
          );
    }

    return greeting;
  }

  Widget _buildQuestion() {
    if (!_showQuestion) return const SizedBox(height: 30);

    Widget question = Text(
      'How shall we call you?',
      textAlign: TextAlign.center,
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );

    // Apply entrance animation
    question = question
        .animate()
        .fadeIn(
          duration: 800.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        );

    // Apply exit animation if exiting
    if (_isExiting) {
      question = question
          .animate()
          .fadeOut(
            delay: 100.ms,
            duration: 500.ms,
            curve: Curves.easeIn,
          )
          .slideY(
            begin: 0,
            end: -0.3,
            delay: 100.ms,
            duration: 500.ms,
            curve: Curves.easeInCubic,
          );
    }

    return question;
  }

  Widget _buildNameInput() {
    if (!_showInput) return const SizedBox(height: 80);

    Widget input = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
      ),
      child: MysticTextField(
        controller: _nameController,
        focusNode: _focusNode,
        hintText: '...',
        textAlign: TextAlign.center,
        onSubmitted: (_) {
          if (_canProceed) _onSubmit();
        },
        textStyle: AppTypography.headlineLarge.copyWith(
          color: AppColors.textPrimary,
          letterSpacing: 3,
        ),
      ),
    );

    // Apply entrance animation
    input = input
        .animate()
        .fadeIn(
          duration: 800.ms,
          curve: Curves.easeOut,
        )
        .scaleXY(
          begin: 0.9,
          end: 1.0,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        );

    // Apply exit animation if exiting
    if (_isExiting) {
      input = input
          .animate()
          .fadeOut(
            delay: 150.ms,
            duration: 500.ms,
            curve: Curves.easeIn,
          )
          .slideY(
            begin: 0,
            end: -0.2,
            delay: 150.ms,
            duration: 500.ms,
            curve: Curves.easeInCubic,
          );
    }

    return input;
  }

  Widget _buildGenderSelector() {
    if (!_showGenderSelector) return const SizedBox(height: 60);

    Widget selector = Column(
      children: [
        Text(
          'I identify as...',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppConstants.spacingMedium),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: Gender.values.map((gender) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _GenderOption(
                gender: gender,
                isSelected: _selectedGender == gender,
                onTap: () => _onGenderSelected(gender),
              ),
            );
          }).toList(),
        ),
      ],
    );

    // Apply entrance animation
    selector = selector
        .animate()
        .fadeIn(
          duration: 600.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.2,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );

    // Apply exit animation if exiting
    if (_isExiting) {
      selector = selector
          .animate()
          .fadeOut(
            delay: 100.ms,
            duration: 500.ms,
            curve: Curves.easeIn,
          )
          .slideY(
            begin: 0,
            end: -0.2,
            delay: 100.ms,
            duration: 500.ms,
            curve: Curves.easeInCubic,
          );
    }

    return selector;
  }

  Widget _buildContinueButton() {
    if (!_showButton || !_canProceed) {
      return const SizedBox(height: 56);
    }

    Widget button = _MysticContinueButton(
      onPressed: _onSubmit,
      isExiting: _isExiting,
    );

    // Apply entrance animation
    button = button
        .animate()
        .fadeIn(
          duration: 600.ms,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );

    // Apply exit animation if exiting
    if (_isExiting) {
      button = button
          .animate()
          .fadeOut(
            delay: 200.ms,
            duration: 400.ms,
            curve: Curves.easeIn,
          )
          .slideY(
            begin: 0,
            end: -0.2,
            delay: 200.ms,
            duration: 400.ms,
            curve: Curves.easeInCubic,
          );
    }

    return button;
  }
}

/// A stylish gender option button with symbol and glow effect.
class _GenderOption extends StatelessWidget {
  final Gender gender;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.gender,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Neon Gold for selected state
    const neonGold = Color(0xFFFFD700);
    final genderColor = gender.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? neonGold.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected ? neonGold : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: neonGold.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: genderColor.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Symbol
            Text(
              gender.symbol,
              style: TextStyle(
                fontSize: 24,
                color: isSelected ? neonGold : AppColors.textSecondary,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 2),
            // Label
            Text(
              gender.label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 9,
                color: isSelected ? neonGold : AppColors.textTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A subtle, mystical continue button
class _MysticContinueButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isExiting;

  const _MysticContinueButton({
    required this.onPressed,
    this.isExiting = false,
  });

  @override
  State<_MysticContinueButton> createState() => _MysticContinueButtonState();
}

class _MysticContinueButtonState extends State<_MysticContinueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowOpacity = 0.2 + (_glowController.value * 0.3);

        return GestureDetector(
          onTap: widget.isExiting ? null : widget.onPressed,
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
                  color: AppColors.primary.withOpacity(glowOpacity * 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
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
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(),
                    )
                    .slideX(
                      begin: 0,
                      end: 0.2,
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .slideX(
                      begin: 0.2,
                      end: 0,
                      duration: 1000.ms,
                      curve: Curves.easeInOut,
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
