import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../home/presentation/providers/character_provider.dart';
import '../../data/providers/sky_hall_provider.dart';
import '../widgets/compatibility_result_view.dart';

/// Love Match screen for synastry compatibility calculation.
class LoveMatchScreen extends ConsumerStatefulWidget {
  const LoveMatchScreen({super.key});

  @override
  ConsumerState<LoveMatchScreen> createState() => _LoveMatchScreenState();
}

class _LoveMatchScreenState extends ConsumerState<LoveMatchScreen> {
  final _formKey = GlobalKey<FormState>();

  // Partner's birth data
  String? _partnerName;
  DateTime? _partnerBirthDate;
  TimeOfDay? _partnerBirthTime;
  double? _partnerLatitude;
  double? _partnerLongitude;
  String? _partnerLocation;
  String _partnerTimezone = 'UTC';

  bool _showResults = false;

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final synastryState = ref.watch(synastryProvider);

    if (_showResults && synastryState.hasReport) {
      return CompatibilityResultView(
        report: synastryState.report!,
        onBack: () {
          setState(() => _showResults = false);
          ref.read(synastryProvider.notifier).clearReport();
        },
      );
    }

    // Calculate dynamic bottom padding for keyboard
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = keyboardHeight > 0
        ? keyboardHeight + 280 // Extra space for autocomplete suggestions
        : AppConstants.spacingLarge;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          top: AppConstants.spacingMedium,
          left: AppConstants.spacingMedium,
          right: AppConstants.spacingMedium,
          bottom: bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your Profile Summary
            _buildYourProfileCard(),

            const SizedBox(height: AppConstants.spacingLarge),

            // Partner Input Form
            _buildPartnerForm(),

            const SizedBox(height: AppConstants.spacingLarge),

            // Calculate Button
            _buildCalculateButton(synastryState.isLoading),

            if (synastryState.hasError) ...[
              const SizedBox(height: AppConstants.spacingMedium),
              _buildErrorMessage(synastryState.error!),
            ],

            const SizedBox(height: AppConstants.spacingMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildYourProfileCard() {
    final user = ref.watch(userProvider);
    final hasData = user.birthDate != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.mysticTeal.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    user.name?.substring(0, 1).toUpperCase() ?? '?',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      user.name ?? 'Unknown',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasData)
                      Text(
                        user.birthDate ?? '',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasData)
                Icon(
                  Icons.check_circle,
                  color: AppColors.mysticTeal,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildPartnerForm() {
    return Form(
      key: _formKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.pink.withOpacity(0.1),
                  AppColors.glassFill,
                ],
              ),
              border: Border.all(color: Colors.pink.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Partner's Birth Data",
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.pink,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMedium),

                // Name
                _buildTextField(
                  label: 'Name',
                  hint: "Enter partner's name",
                  onChanged: (value) => _partnerName = value,
                ),

                const SizedBox(height: AppConstants.spacingMedium),

                // Birth Date
                _buildDatePicker(
                  label: 'Birth Date',
                  value: _partnerBirthDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime(1990),
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _partnerBirthDate = date);
                    }
                  },
                ),

                const SizedBox(height: AppConstants.spacingMedium),

                // Birth Time
                _buildTimePicker(
                  label: 'Birth Time (optional)',
                  value: _partnerBirthTime,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => _partnerBirthTime = time);
                    }
                  },
                ),

                const SizedBox(height: AppConstants.spacingMedium),

                // Location (simplified for now)
                _buildLocationPicker(),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _dismissKeyboard(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'
                        : 'Select date',
                    style: AppTypography.bodyMedium.copyWith(
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
                        : '12:00 (default)',
                    style: AppTypography.bodyMedium.copyWith(
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                Icon(
                  Icons.access_time,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    // Location search with autocomplete
    return MysticLocationSearchField(
      label: 'Birth Location',
      placeholder: 'Search city...',
      initialValue: _partnerLocation,
      onLocationSelected: (lat, lng, placeName, timezone) {
        setState(() {
          _partnerLatitude = lat;
          _partnerLongitude = lng;
          _partnerLocation = placeName;
          if (timezone != null) {
            _partnerTimezone = timezone;
          }
        });
      },
    );
  }

  Widget _buildCalculateButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _onCalculate,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.pink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Calculate Compatibility',
                    style: AppTypography.titleSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCalculate() {
    _dismissKeyboard();
    final user = ref.read(userProvider);

    // Validate user data
    if (user.birthDate == null || user.birthLatitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete your birth data first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate partner data
    if (_partnerBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter partner's birth date."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate partner location
    if (_partnerLatitude == null || _partnerLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please select partner's birth location."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final partnerLat = _partnerLatitude!;
    final partnerLng = _partnerLongitude!;

    // Build request data
    final user1Data = {
      'date': user.birthDate!,
      'time': user.birthTime ?? '12:00',
      'latitude': user.birthLatitude!,
      'longitude': user.birthLongitude ?? 0.0,
      'timezone': user.birthTimezone ?? 'UTC',
      'name': user.name ?? 'You',
    };

    final user2Data = {
      'date':
          '${_partnerBirthDate!.year}-${_partnerBirthDate!.month.toString().padLeft(2, '0')}-${_partnerBirthDate!.day.toString().padLeft(2, '0')}',
      'time': _partnerBirthTime != null
          ? '${_partnerBirthTime!.hour.toString().padLeft(2, '0')}:${_partnerBirthTime!.minute.toString().padLeft(2, '0')}'
          : '12:00',
      'latitude': partnerLat,
      'longitude': partnerLng,
      'timezone': _partnerTimezone,
      'name': _partnerName ?? 'Partner',
    };

    // Get selected guide character for AI analysis
    final selectedCharacterId = ref.read(selectedCharacterIdProvider);

    // Calculate synastry
    ref.read(synastryProvider.notifier).calculateSynastry(
          user1Data: user1Data,
          user2Data: user2Data,
          characterId: selectedCharacterId,
        );

    setState(() => _showResults = true);
  }
}
