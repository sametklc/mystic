import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/gem_service.dart';
import '../../features/onboarding/onboarding.dart';
import '../../features/paywall/paywall.dart';
import '../models/profile_model.dart';
import '../providers/user_provider.dart';

/// A bubble dialog that appears from the profile photo to switch profiles.
class ProfileSwitcherDialog extends ConsumerWidget {
  const ProfileSwitcherDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const ProfileSwitcherDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(allProfilesProvider);
    final currentProfile = ref.watch(currentProfileProvider);

    return Stack(
      children: [
        // Dismiss on tap outside
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),

        // Dialog positioned at top-left
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF16213E),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Profiles',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),

                  // Profile list
                  ...profiles.map((profile) => _ProfileTile(
                        profile: profile,
                        isSelected: profile.id == currentProfile?.id,
                        onTap: () {
                          ref
                              .read(userProvider.notifier)
                              .switchProfile(profile.id);
                          Navigator.of(context).pop();
                        },
                      )),

                  Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),

                  // Add profile button
                  InkWell(
                    onTap: () {
                      final isPremium = ref.read(isPremiumProvider);

                      // Non-premium users: redirect to paywall
                      if (!isPremium) {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PaywallView(
                              onClose: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
                        return;
                      }

                      // Premium users: check gems
                      final userGems = ref.read(gemsProvider);
                      final requiredGems = GemConfig.newProfileChartCost;

                      if (userGems < requiredGems) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Not enough gems! Adding a profile requires $requiredGems 💎 (you have $userGems)',
                            ),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).pop();
                      // Start new profile and navigate to onboarding
                      ref.read(userProvider.notifier).startNewProfile();
                      ref.read(addProfileModeProvider.notifier).state = true;
                      // Navigate to add profile onboarding
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const _AddProfileOnboarding(),
                        ),
                      );
                    },
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF6C63FF),
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignCenter,
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFF6C63FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Profile',
                                style: TextStyle(
                                  color: const Color(0xFF6C63FF),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Consumer(
                                builder: (context, ref, _) {
                                  final isPremium = ref.watch(isPremiumProvider);
                                  return Text(
                                    isPremium ? '${GemConfig.newProfileChartCost} 💎' : '✨ Premium',
                                    style: TextStyle(
                                      color: isPremium
                                          ? const Color(0xFF6C63FF).withValues(alpha: 0.7)
                                          : const Color(0xFFFFD700),
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 200.ms)
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 200.ms,
                  curve: Curves.easeOutBack,
                )
                .slideY(begin: -0.1, end: 0, duration: 200.ms),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final ProfileModel profile;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    const Color(0xFF6C63FF).withValues(alpha: 0.05),
                  ],
                ),
              )
            : null,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: profile.isMainProfile
                      ? [
                          const Color(0xFFFFD700),
                          const Color(0xFFFF8C00),
                        ]
                      : [
                          const Color(0xFF6C63FF),
                          const Color(0xFF4834D4),
                        ],
                ),
                border: isSelected
                    ? Border.all(
                        color: Colors.white,
                        width: 2,
                      )
                    : null,
              ),
              child: profile.hasProfileImage
                  ? ClipOval(
                      child: Image.network(
                        profile.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            profile.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        profile.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 14),

            // Name and info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name ?? 'Unnamed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.isMainProfile) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFD700).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MAIN',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (profile.sunSign != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.sunSign!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Checkmark for selected
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6C63FF),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Onboarding steps for adding a new profile
enum _AddProfileStep {
  name,
  birthData,
  relationship,
  intention,
  knowledge,
  tone,
  reveal,
  complete,
}

/// A streamlined onboarding flow for adding a new profile.
/// Reuses existing onboarding screens but skips paywall and completes with
/// completeAddProfile() instead of completeOnboarding().
class _AddProfileOnboarding extends ConsumerStatefulWidget {
  const _AddProfileOnboarding();

  @override
  ConsumerState<_AddProfileOnboarding> createState() =>
      _AddProfileOnboardingState();
}

class _AddProfileOnboardingState extends ConsumerState<_AddProfileOnboarding> {
  _AddProfileStep _currentStep = _AddProfileStep.name;

  void _onNameComplete() {
    setState(() {
      _currentStep = _AddProfileStep.birthData;
    });
  }

  void _onBirthDataComplete() {
    setState(() {
      _currentStep = _AddProfileStep.relationship;
    });
  }

  void _onRelationshipComplete(RelationshipStatus status) {
    ref.read(userProvider.notifier).setRelationshipStatus(status.name);
    setState(() {
      _currentStep = _AddProfileStep.intention;
    });
  }

  void _onIntentionComplete(List<SpiritualIntention> intentions) {
    final intentionNames = intentions.map((i) => i.name).toList();
    ref.read(userProvider.notifier).setIntentions(intentionNames);
    setState(() {
      _currentStep = _AddProfileStep.knowledge;
    });
  }

  void _onKnowledgeComplete(KnowledgeLevel level) {
    ref.read(userProvider.notifier).setKnowledgeLevel(level.name);
    setState(() {
      _currentStep = _AddProfileStep.tone;
    });
  }

  void _onToneComplete(PreferredTone tone) {
    ref.read(userProvider.notifier).setPreferredTone(tone.name);
    setState(() {
      _currentStep = _AddProfileStep.reveal;
    });
  }

  void _onRevealComplete() {
    // Deduct gems for creating new profile with birth chart
    ref.read(userProvider.notifier).spendGems(GemConfig.newProfileChartCost);

    // Complete adding profile (not the main onboarding)
    ref.read(userProvider.notifier).completeAddProfile();
    ref.read(addProfileModeProvider.notifier).state = false;

    // Navigate back to home
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Profile created! -${GemConfig.newProfileChartCost} 💎',
        ),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _onBack() {
    if (_currentStep == _AddProfileStep.name) {
      // Cancel adding profile
      ref.read(userProvider.notifier).cancelAddProfile();
      ref.read(addProfileModeProvider.notifier).state = false;
      Navigator.of(context).pop();
    } else {
      // Go back to previous step
      setState(() {
        final currentIndex = _AddProfileStep.values.indexOf(_currentStep);
        if (currentIndex > 0) {
          _currentStep = _AddProfileStep.values[currentIndex - 1];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Onboarding content
            _buildCurrentStep(),

            // Back button (except on reveal screen)
            if (_currentStep != _AddProfileStep.reveal)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  onPressed: _onBack,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case _AddProfileStep.name:
        return OnboardingNameScreen(
          onComplete: _onNameComplete,
        );
      case _AddProfileStep.birthData:
        return OnboardingBirthDataScreen(
          currentStep: 1,
          totalSteps: 6,
          onComplete: _onBirthDataComplete,
        );
      case _AddProfileStep.relationship:
        return OnboardingRelationshipScreen(
          currentStep: 2,
          totalSteps: 6,
          onComplete: _onRelationshipComplete,
        );
      case _AddProfileStep.intention:
        return OnboardingIntentionScreen(
          currentStep: 3,
          totalSteps: 6,
          onComplete: _onIntentionComplete,
        );
      case _AddProfileStep.knowledge:
        return OnboardingKnowledgeScreen(
          currentStep: 4,
          totalSteps: 6,
          onComplete: _onKnowledgeComplete,
        );
      case _AddProfileStep.tone:
        return OnboardingToneScreen(
          currentStep: 5,
          totalSteps: 6,
          onComplete: _onToneComplete,
        );
      case _AddProfileStep.reveal:
        return OnboardingRevealScreen(
          onComplete: _onRevealComplete,
        );
      case _AddProfileStep.complete:
        // This should never be reached since we navigate away
        return const SizedBox.shrink();
    }
  }
}
