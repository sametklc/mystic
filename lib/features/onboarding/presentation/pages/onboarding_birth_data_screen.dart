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

  /// Current onboarding step (0-indexed)
  final int currentStep;

  /// Total onboarding steps
  final int totalSteps;

  const OnboardingBirthDataScreen({
    super.key,
    this.onComplete,
    this.currentStep = 1,
    this.totalSteps = 4,
  });

  @override
  ConsumerState<OnboardingBirthDataScreen> createState() =>
      _OnboardingBirthDataScreenState();
}

class _OnboardingBirthDataScreenState
    extends ConsumerState<OnboardingBirthDataScreen> {
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
    if (_isDataComplete && !_showButton) {
      setState(() => _showButton = true);
    }
  }

  /// Continue to next step - save data without reveal animation
  Future<void> _onContinue() async {
    if (!_isDataComplete) return;

    // Haptic feedback for button press
    HapticFeedback.mediumImpact();

    // Calculate the profile (quietly, no animation)
    final birthData = BirthDataModel(
      birthDate: _birthDate,
      birthTime: _birthTime,
      birthLocation: _birthLocation,
    );

    _profile = await AstrologyService.calculateProfile(birthData);

    // Save birth data to user provider
    _saveBirthData();

    setState(() => _isExiting = true);

    await Future.delayed(const Duration(milliseconds: 400));

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
    if (_isDataComplete && !_showButton) {
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
            child: _buildInputPhase(),
          ),
        ),
      ),
    );
  }

  Widget _buildInputPhase() {
    return LayoutBuilder(
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
                  const SizedBox(height: AppConstants.spacingMedium),

                  // Progress bar
                  MysticProgressBar(
                    totalSteps: widget.totalSteps,
                    currentStep: widget.currentStep,
                  ),

                  const Spacer(flex: 1),

                  // Question text
                  _buildQuestion(),

                  const SizedBox(height: AppConstants.spacingXXLarge),

                  // Pickers
                  if (_showPickers) ...[
                    _buildPickers(),
                    const Spacer(flex: 2),
                  ] else
                    const Spacer(flex: 3),

                  // Continue button
                  _buildContinueButton(),

                  const SizedBox(height: AppConstants.spacingXXLarge),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildContinueButton() {
    if (!_showButton || !_isDataComplete) {
      return const SizedBox(height: 56);
    }

    Widget button = GestureDetector(
      onTap: _isExiting ? null : _onContinue,
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
            if (_isExiting)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            else
              Text(
                'Continue',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            if (!_isExiting) ...[
              const SizedBox(width: AppConstants.spacingSmall),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ],
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

    return button;
  }
}
