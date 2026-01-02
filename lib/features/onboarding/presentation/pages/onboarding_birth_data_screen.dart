import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/services/services.dart';
import '../../../../shared/widgets/widgets.dart';

/// The second step of the onboarding ritual - Birth Data & Cosmic Signature Reveal.
/// This is the "Wow Moment" where we calculate and reveal their astrological profile.
class OnboardingBirthDataScreen extends ConsumerStatefulWidget {
  /// Callback when the user completes this step
  final VoidCallback? onComplete;

  const OnboardingBirthDataScreen({
    super.key,
    this.onComplete,
  });

  @override
  ConsumerState<OnboardingBirthDataScreen> createState() =>
      _OnboardingBirthDataScreenState();
}

class _OnboardingBirthDataScreenState
    extends ConsumerState<OnboardingBirthDataScreen>
    with TickerProviderStateMixin {
  // Birth data
  DateTime? _birthDate;
  DateTime? _birthTime;
  String? _birthLocation;
  double? _birthLatitude;
  double? _birthLongitude;
  String? _birthTimezone;

  // Animation states
  bool _showQuestion = false;
  bool _showPickers = false;
  bool _showButton = false;
  bool _isCalculating = false;
  bool _showWheel = false;
  bool _showResult = false;
  bool _isExiting = false;

  // Result data
  AstrologyProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _startRitual();
  }

  /// Orchestrates the entrance animation sequence
  Future<void> _startRitual() async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _showQuestion = true);

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() => _showPickers = true);
  }

  /// Check if all data is entered
  bool get _isDataComplete =>
      _birthDate != null && _birthTime != null && _birthLocation != null && _birthLatitude != null;

  /// Show the button when data is complete
  void _maybeShowButton() {
    if (_isDataComplete && !_showButton && !_isCalculating) {
      setState(() => _showButton = true);
    }
  }

  /// Start the calculation animation
  Future<void> _onRevealDestiny() async {
    if (!_isDataComplete) return;

    // Haptic feedback for button press
    HapticFeedback.mediumImpact();

    // Hide inputs, show wheel
    setState(() {
      _isCalculating = true;
      _showButton = false;
      _showPickers = false;
      _showQuestion = false;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _showWheel = true);

    // Calculate the profile while wheel is spinning
    final birthData = BirthDataModel(
      birthDate: _birthDate,
      birthTime: _birthTime,
      birthLocation: _birthLocation,
    );

    _profile = await AstrologyService.calculateProfile(birthData);
  }

  /// Called when the wheel spin completes
  void _onSpinComplete() {
    // Final haptic burst
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showResult = true);
    });
  }

  /// Proceed to next step
  Future<void> _onContinue() async {
    HapticFeedback.lightImpact();

    // Save birth data to user provider
    _saveBirthData();

    setState(() => _isExiting = true);

    await Future.delayed(const Duration(milliseconds: 800));

    widget.onComplete?.call();
  }

  /// Save birth data to user provider for use in Sky Hall
  void _saveBirthData() {
    if (_birthDate == null || _birthTime == null || _birthLocation == null || _birthLatitude == null) return;

    // Format date as YYYY-MM-DD
    final dateStr = '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';

    // Format time as HH:MM
    final timeStr = '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}';

    // Save to user provider with coordinates from location search
    ref.read(userProvider.notifier).setBirthData(
      date: dateStr,
      time: timeStr,
      latitude: _birthLatitude!,
      longitude: _birthLongitude ?? 0.0,
      city: _birthLocation,
      timezone: _birthTimezone ?? 'UTC',
    );

    // Save signs if profile was calculated
    if (_profile != null) {
      ref.read(userProvider.notifier).setSigns(
        sunSign: _profile!.sunSign.name,
        risingSign: _profile!.ascendantSign.name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show button when data is complete
    if (_isDataComplete && !_showButton && !_isCalculating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowButton();
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: MysticBackgroundScaffold(
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              if (!_isCalculating) _buildInputPhase(),

              // Calculation phase
              if (_isCalculating) _buildCalculationPhase(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputPhase() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLarge,
      ),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Question text
          _buildQuestion(),

          const SizedBox(height: AppConstants.spacingXXLarge),

          // Pickers
          if (_showPickers) ...[
            _buildPickers(),
            const Spacer(flex: 2),
          ] else
            const Spacer(flex: 3),

          // Reveal button
          _buildRevealButton(),

          const SizedBox(height: AppConstants.spacingXXLarge),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    if (!_showQuestion) return const SizedBox(height: 80);

    return Column(
      children: [
        Text(
          'We need to know\nwhere the stars were.',
          textAlign: TextAlign.center,
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        )
            .animate()
            .fadeIn(duration: 1000.ms, curve: Curves.easeOut)
            .slideY(begin: 0.2, end: 0, duration: 1000.ms),
        const SizedBox(height: AppConstants.spacingMedium),
        Text(
          'Enter your birth details.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        )
            .animate()
            .fadeIn(delay: 500.ms, duration: 800.ms)
            .slideY(begin: 0.2, end: 0, delay: 500.ms, duration: 800.ms),
      ],
    );
  }

  Widget _buildPickers() {
    return Column(
      children: [
        // Date picker
        MysticDatePicker(
          selectedDate: _birthDate,
          onDateSelected: (date) {
            setState(() => _birthDate = date);
            HapticFeedback.selectionClick();
          },
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideX(begin: -0.2, end: 0, duration: 600.ms),

        const SizedBox(height: AppConstants.spacingMedium),

        // Time picker
        MysticTimePicker(
          selectedTime: _birthTime,
          onTimeSelected: (time) {
            setState(() => _birthTime = time);
            HapticFeedback.selectionClick();
          },
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 600.ms)
            .slideX(begin: -0.2, end: 0, delay: 150.ms, duration: 600.ms),

        const SizedBox(height: AppConstants.spacingMedium),

        // Location search field (replaces old country/city picker)
        MysticLocationSearchField(
          initialValue: _birthLocation,
          onLocationSelected: (lat, lng, placeName, timezone) {
            setState(() {
              _birthLocation = placeName;
              _birthLatitude = lat;
              _birthLongitude = lng;
              _birthTimezone = timezone;
            });
            HapticFeedback.selectionClick();
          },
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 600.ms)
            .slideX(begin: -0.2, end: 0, delay: 300.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildRevealButton() {
    if (!_showButton || !_isDataComplete) {
      return const SizedBox(height: 60);
    }

    return _MysticRevealButton(
      onPressed: _onRevealDestiny,
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildCalculationPhase() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Zodiac wheel
          if (_showWheel)
            ZodiacWheel(
              size: 300,
              isSpinning: !_showResult,
              spinDuration: const Duration(seconds: 4),
              highlightedSign: _profile?.sunSign,
              enableHaptics: true,
              onSpinComplete: _onSpinComplete,
            )
                .animate()
                .fadeIn(duration: 800.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),

          const SizedBox(height: AppConstants.spacingXLarge),

          // Result text
          if (_showResult) _buildResultSection(),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    if (_profile == null) return const SizedBox();

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLarge,
      ),
      child: Column(
        children: [
          // Cosmic signature symbols
          Text(
            _profile!.cosmicSignature,
            style: AppTypography.displayMedium.copyWith(
              color: AppColors.primary,
              letterSpacing: 8,
              shadows: [
                Shadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 20,
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 800.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 800.ms,
              ),

          const SizedBox(height: AppConstants.spacingLarge),

          // Main signs text
          Text(
            'Sun: ${_profile!.sunSign.name}',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 600.ms),

          const SizedBox(height: AppConstants.spacingSmall),

          Text(
            'Rising: ${_profile!.ascendantSign.name}',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          )
              .animate()
              .fadeIn(delay: 500.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, delay: 500.ms, duration: 600.ms),

          const SizedBox(height: AppConstants.spacingXLarge),

          // Aura description
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
            child: Text(
              _profile!.auraDescription,
              textAlign: TextAlign.center,
              style: AppTypography.mysticalQuote.copyWith(
                color: AppColors.primary,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 800.ms, duration: 800.ms)
              .slideY(begin: 0.2, end: 0, delay: 800.ms, duration: 800.ms),

          const SizedBox(height: AppConstants.spacingXXLarge),

          // Continue button
          _MysticContinueButton(
            label: 'Meet Your Guide',
            onPressed: _onContinue,
          )
              .animate()
              .fadeIn(delay: 1200.ms, duration: 600.ms)
              .slideY(begin: 0.3, end: 0, delay: 1200.ms, duration: 600.ms),
        ],
      ),
    );

    // Apply exit animation if exiting
    if (_isExiting) {
      content = content
          .animate()
          .fadeOut(duration: 600.ms)
          .slideY(begin: 0, end: -0.2, duration: 600.ms);
    }

    return content;
  }
}

/// Dramatic "Reveal Destiny" button
class _MysticRevealButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _MysticRevealButton({required this.onPressed});

  @override
  State<_MysticRevealButton> createState() => _MysticRevealButtonState();
}

class _MysticRevealButtonState extends State<_MysticRevealButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + _pulseController.value * 0.03;
        final glowOpacity = 0.3 + _pulseController.value * 0.4;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(glowOpacity),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: AppColors.secondary.withOpacity(glowOpacity * 0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 22),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(
                    'Reveal Your Destiny',
                    style: AppTypography.button.copyWith(
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Subtle continue button for post-reveal
class _MysticContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _MysticContinueButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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
              label,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: AppConstants.spacingSmall),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
