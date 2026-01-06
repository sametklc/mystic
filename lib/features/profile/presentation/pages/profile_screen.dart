import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/services/profile_image_service.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/services/astrology_service.dart';
import '../../../../shared/widgets/widgets.dart';

/// Profile screen for viewing and editing user data.
/// Features a mystic-themed design with image upload capability.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingImage = false;
  bool _isSaving = false;

  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _nameController = TextEditingController(text: user.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showImagePickerOptions() async {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildImagePickerSheet(),
    );
  }

  Widget _buildImagePickerSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Update Profile Photo',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: AppColors.mysticTeal,
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImage(fromCamera: false);
                },
              ),
              _buildPickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: AppColors.primary,
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImage(fromCamera: true);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage({required bool fromCamera}) async {
    setState(() => _isUploadingImage = true);

    try {
      final profileService = ref.read(profileImageServiceProvider);
      final File? imageFile = fromCamera
          ? await profileService.pickImageFromCamera()
          : await profileService.pickImageFromGallery();

      if (imageFile == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      // Upload to Firebase Storage with profile-specific path
      final deviceId = ref.read(deviceIdProvider);
      final currentProfile = ref.read(currentProfileProvider);
      final downloadUrl = await profileService.uploadProfileImage(
        deviceId,
        imageFile,
        profileId: currentProfile?.id,
      );

      if (downloadUrl != null) {
        // Update local state (this also saves to Firestore via _saveToFirestore)
        // The setProfileImageUrl method updates the current profile's imageUrl
        // and persists the entire UserModel including all profiles
        ref.read(userProvider.notifier).setProfileImageUrl(downloadUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile photo updated!'),
              backgroundColor: AppColors.mysticTeal,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isUploadingImage = false);
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      // Update local state (this also saves to Firestore via _saveToFirestore)
      // The setName method updates the current profile's name
      // and persists the entire UserModel including all profiles
      ref.read(userProvider.notifier).setName(newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Name updated!'),
            backgroundColor: AppColors.mysticTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    return MysticBackgroundScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingMedium),
                child: Column(
                  children: [
                    // Profile Avatar Section
                    _buildAvatarSection(user),
                    const SizedBox(height: 32),

                    // Identity Section
                    _buildSection(
                      title: 'Identity',
                      icon: Icons.person_outline,
                      children: [
                        _buildNameField(),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cosmic Origin Section (Birth Data) - Editable
                    _buildSection(
                      title: 'Cosmic Origin',
                      icon: Icons.auto_awesome,
                      children: [
                        _buildEditableInfoRow(
                          'Birth Date',
                          user.birthDate ?? 'Not set',
                          Icons.calendar_today,
                          () => _showDatePicker(user.birthDate),
                        ),
                        _buildEditableInfoRow(
                          'Birth Time',
                          user.birthTime ?? '12:00',
                          Icons.access_time,
                          () => _showTimePicker(user.birthTime),
                        ),
                        _buildEditableInfoRow(
                          'Birth Place',
                          user.birthCity ?? 'Not set',
                          Icons.location_on,
                          _showLocationPicker,
                        ),
                        const SizedBox(height: 12),
                        _buildSignsRow(user),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // The Journey Section (Onboarding Data)
                    _buildSection(
                      title: 'The Journey',
                      icon: Icons.explore_outlined,
                      children: [
                        _buildInfoRow(
                          'Relationship',
                          _formatRelationship(user.relationshipStatus),
                        ),
                        _buildInfoRow(
                          'Knowledge Level',
                          _formatKnowledge(user.knowledgeLevel),
                        ),
                        _buildInfoRow(
                          'Reading Style',
                          _formatTone(user.preferredTone),
                        ),
                        if (user.intentions != null && user.intentions!.isNotEmpty)
                          _buildIntentionsRow(user.intentions!),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassFill,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Your Profile',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildAvatarSection(user) {
    return Column(
      children: [
        // Avatar with edit button
        Stack(
          children: [
            // Avatar
            GestureDetector(
              onTap: _isUploadingImage ? null : _showImagePickerOptions,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.mysticTeal.withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isUploadingImage
                      ? Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        )
                      : user.hasProfileImage
                          ? Image.network(
                              user.profileImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildLargeAvatarFallback(user),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return _buildLargeAvatarFallback(user);
                              },
                            )
                          : _buildLargeAvatarFallback(user),
                ),
              ),
            ),

            // Edit badge
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _showImagePickerOptions,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(
                      color: AppColors.surface,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Name
        Text(
          user.name ?? 'Seeker',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),

        // Sun sign
        if (user.sunSign != null)
          Text(
            user.sunSign!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          delay: 100.ms,
          duration: 400.ms,
        );
  }

  Widget _buildLargeAvatarFallback(user) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Text(
          user.initials,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildNameField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Display Name',
              labelStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _isSaving ? null : _saveName,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary,
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.check, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textTertiary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit,
                color: AppColors.primary.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker(String? currentDate) async {
    HapticFeedback.selectionClick();

    // Parse current date if available (format: YYYY-MM-DD)
    DateTime initialDate = DateTime(1990);
    if (currentDate != null && currentDate.isNotEmpty && currentDate != 'Not set') {
      try {
        final parts = currentDate.split('-');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      await _updateBirthData(newDate: date);
    }
  }

  Future<void> _showTimePicker(String? currentTime) async {
    HapticFeedback.selectionClick();

    // Parse current time if available (format: HH:MM)
    TimeOfDay initialTime = const TimeOfDay(hour: 12, minute: 0);
    if (currentTime != null && currentTime.isNotEmpty) {
      try {
        final parts = currentTime.split(':');
        if (parts.length >= 2) {
          initialTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time != null && mounted) {
      await _updateBirthData(newTime: time);
    }
  }

  void _showLocationPicker() {
    HapticFeedback.selectionClick();
    final user = ref.read(userProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Birth Location',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              MysticLocationSearchField(
                initialValue: user.birthCity,
                initialLatitude: user.birthLatitude,
                initialLongitude: user.birthLongitude,
                onLocationSelected: (lat, lng, placeName, timezone) async {
                  Navigator.pop(context);
                  await _updateBirthData(
                    newLatitude: lat,
                    newLongitude: lng,
                    newCity: placeName,
                    newTimezone: timezone,
                  );
                },
              ),
              const SizedBox(height: 16),
              SafeArea(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Update birth data and recalculate signs
  Future<void> _updateBirthData({
    DateTime? newDate,
    TimeOfDay? newTime,
    double? newLatitude,
    double? newLongitude,
    String? newCity,
    String? newTimezone,
  }) async {
    final user = ref.read(userProvider);

    // Get current values or use new ones
    String dateStr;
    if (newDate != null) {
      dateStr = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    } else {
      dateStr = user.birthDate ?? '';
    }

    String timeStr;
    if (newTime != null) {
      timeStr = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
    } else {
      timeStr = user.birthTime ?? '12:00';
    }

    final latitude = newLatitude ?? user.birthLatitude ?? 0.0;
    final longitude = newLongitude ?? user.birthLongitude ?? 0.0;
    final city = newCity ?? user.birthCity;
    final timezone = newTimezone ?? user.birthTimezone ?? 'UTC';

    // Save birth data
    ref.read(userProvider.notifier).setBirthData(
      date: dateStr,
      time: timeStr,
      latitude: latitude,
      longitude: longitude,
      city: city,
      timezone: timezone,
    );

    // Recalculate signs if we have a valid date
    if (dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final birthDateTime = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          final birthData = BirthDataModel(
            birthDate: birthDateTime,
            birthTime: null,
            birthLocation: city,
          );

          final profile = await AstrologyService.calculateProfile(birthData);

          ref.read(userProvider.notifier).setSigns(
            sunSign: profile.sunSign.name,
            risingSign: profile.ascendantSign.name,
            moonSign: profile.moonSign.name,
          );
        }
      } catch (e) {
        debugPrint('Error recalculating signs: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Birth data updated!'),
          backgroundColor: AppColors.mysticTeal,
        ),
      );
    }
  }

  Widget _buildSignsRow(user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.mysticTeal.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSignItem('Sun', user.sunSign ?? '?', Icons.wb_sunny_outlined),
          Container(
            width: 1,
            height: 30,
            color: AppColors.glassBorder,
          ),
          _buildSignItem('Moon', user.moonSign ?? '?', Icons.nightlight_outlined),
          Container(
            width: 1,
            height: 30,
            color: AppColors.glassBorder,
          ),
          _buildSignItem('Rising', user.risingSign ?? '?', Icons.arrow_upward),
        ],
      ),
    );
  }

  Widget _buildSignItem(String label, String sign, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          sign,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildIntentionsRow(List<String> intentions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intentions',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: intentions.map((intention) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary.withOpacity(0.15),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                _formatIntention(intention),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatRelationship(String? status) {
    if (status == null) return 'Not set';
    switch (status) {
      case 'single':
        return 'Single';
      case 'inRelationship':
        return 'In a Relationship';
      case 'complicated':
        return "It's Complicated";
      case 'married':
        return 'Married';
      case 'healing':
        return 'Healing';
      case 'seeking':
        return 'Seeking Love';
      default:
        return status;
    }
  }

  String _formatKnowledge(String? level) {
    if (level == null) return 'Not set';
    switch (level) {
      case 'novice':
        return 'Novice';
      case 'seeker':
        return 'Seeker';
      case 'adept':
        return 'Adept';
      default:
        return level;
    }
  }

  String _formatTone(String? tone) {
    if (tone == null) return 'Not set';
    switch (tone) {
      case 'gentle':
        return 'Gentle & Nurturing';
      case 'brutal':
        return 'Brutally Honest';
      default:
        return tone;
    }
  }

  String _formatIntention(String intention) {
    switch (intention) {
      case 'love':
        return 'Love & Relationships';
      case 'career':
        return 'Career & Purpose';
      case 'shadowWork':
        return 'Shadow Work';
      case 'future':
        return 'Future Insights';
      case 'dailyGuidance':
        return 'Daily Guidance';
      case 'healing':
        return 'Healing & Growth';
      default:
        return intention;
    }
  }
}
