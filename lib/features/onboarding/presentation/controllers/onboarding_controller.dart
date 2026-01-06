import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/user_provider.dart';
import '../../onboarding.dart';
import '../../../../features/paywall/paywall.dart';

/// Defines the available onboarding steps.
/// Not all steps are shown on all platforms.
enum OnboardingStepType {
  /// Step 1 (All platforms): Name input
  name,

  /// Step 2 (Android only): Birth date, time, and place
  birthData,

  /// Step 3 (Android only): Relationship status
  relationship,

  /// Step 4 (All platforms): Spiritual intentions/interests
  intention,

  /// Step 5 (Android only): Knowledge level
  knowledge,

  /// Step 6 (Android only): Preferred tone
  tone,

  /// Step 7 (Android only): Cosmic reveal animation
  reveal,

  /// Step 8 (All platforms): Paywall
  paywall,

  /// Final: Onboarding complete
  complete,
}

/// Configuration for a single onboarding step.
class OnboardingStepConfig {
  final OnboardingStepType type;
  final bool showOnAndroid;
  final bool showOnIOS;

  const OnboardingStepConfig({
    required this.type,
    this.showOnAndroid = true,
    this.showOnIOS = true,
  });

  /// Check if this step should be shown on the current platform.
  bool get shouldShow => Platform.isIOS ? showOnIOS : showOnAndroid;
}

/// Master configuration for all onboarding steps.
/// Modify this list to change which steps appear on each platform.
const List<OnboardingStepConfig> _allSteps = [
  // Step 1: Name (both platforms)
  OnboardingStepConfig(
    type: OnboardingStepType.name,
    showOnAndroid: true,
    showOnIOS: true,
  ),

  // Step 2: Birth Data (Android only - astrology features)
  OnboardingStepConfig(
    type: OnboardingStepType.birthData,
    showOnAndroid: true,
    showOnIOS: false, // Skip on iOS for App Store compliance
  ),

  // Step 3: Relationship Status (Android only)
  OnboardingStepConfig(
    type: OnboardingStepType.relationship,
    showOnAndroid: true,
    showOnIOS: false,
  ),

  // Step 4: Spiritual Intentions (both platforms)
  OnboardingStepConfig(
    type: OnboardingStepType.intention,
    showOnAndroid: true,
    showOnIOS: true, // Keep for personalization
  ),

  // Step 5: Knowledge Level (Android only)
  OnboardingStepConfig(
    type: OnboardingStepType.knowledge,
    showOnAndroid: true,
    showOnIOS: false,
  ),

  // Step 6: Preferred Tone (Android only)
  OnboardingStepConfig(
    type: OnboardingStepType.tone,
    showOnAndroid: true,
    showOnIOS: false,
  ),

  // Step 7: Cosmic Reveal Animation (Android only - zodiac wheel)
  OnboardingStepConfig(
    type: OnboardingStepType.reveal,
    showOnAndroid: true,
    showOnIOS: false, // Skip zodiac animation on iOS
  ),

  // Step 8: Paywall (both platforms)
  OnboardingStepConfig(
    type: OnboardingStepType.paywall,
    showOnAndroid: true,
    showOnIOS: true,
  ),
];

/// Controller for managing the onboarding flow.
///
/// Provides platform-specific step filtering and navigation.
///
/// Usage:
/// ```dart
/// final controller = OnboardingController(ref);
/// final steps = controller.activeSteps; // Filtered for current platform
/// final totalSteps = controller.totalSteps;
/// ```
class OnboardingController {
  final WidgetRef ref;

  OnboardingController(this.ref);

  /// Get list of steps that should be shown on the current platform.
  List<OnboardingStepType> get activeSteps {
    return _allSteps
        .where((config) => config.shouldShow)
        .map((config) => config.type)
        .where((type) => type != OnboardingStepType.complete) // Exclude 'complete'
        .toList();
  }

  /// Total number of visible onboarding steps (excluding paywall and complete).
  int get totalSteps {
    return activeSteps.where((step) => step != OnboardingStepType.paywall).length;
  }

  /// Get the step number (1-based) for display in UI.
  int getStepNumber(OnboardingStepType step) {
    final visibleSteps = activeSteps.where((s) => s != OnboardingStepType.paywall).toList();
    final index = visibleSteps.indexOf(step);
    return index >= 0 ? index + 1 : 0;
  }

  /// Check if a step should be shown on the current platform.
  bool shouldShowStep(OnboardingStepType step) {
    return activeSteps.contains(step);
  }

  /// Get the next step after the given step.
  /// Returns null if there are no more steps.
  OnboardingStepType? getNextStep(OnboardingStepType currentStep) {
    final steps = activeSteps;
    final currentIndex = steps.indexOf(currentStep);

    if (currentIndex < 0 || currentIndex >= steps.length - 1) {
      return OnboardingStepType.complete;
    }

    return steps[currentIndex + 1];
  }

  /// Check if we're on iOS.
  bool get isIOS => Platform.isIOS;

  /// Check if we're on Android.
  bool get isAndroid => !Platform.isIOS;

  /// Set default values for skipped iOS steps.
  /// Call this when completing onboarding on iOS to set sensible defaults.
  void setIOSDefaults() {
    if (!isIOS) return;

    final userNotifier = ref.read(userProvider.notifier);

    // Set default values for skipped steps
    // These won't affect the user experience on iOS but keep data consistent
    userNotifier.setRelationshipStatus('single'); // Default relationship
    userNotifier.setKnowledgeLevel('seeker'); // Middle ground
    userNotifier.setPreferredTone('gentle'); // Friendly default
  }
}

/// Provider for the onboarding controller.
final onboardingControllerProvider = Provider<OnboardingController>((ref) {
  throw UnimplementedError('Must be overridden in widget tree');
});

/// A stateful widget that manages the onboarding flow with platform-specific steps.
class OnboardingFlow extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingFlow({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late OnboardingController _controller;
  late OnboardingStepType _currentStep;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingController(ref);
    _currentStep = _controller.activeSteps.first;
  }

  void _goToNextStep() {
    final nextStep = _controller.getNextStep(_currentStep);

    if (nextStep == OnboardingStepType.complete) {
      // Set defaults for skipped iOS steps before completing
      _controller.setIOSDefaults();
      ref.read(userProvider.notifier).completeOnboarding();
      widget.onComplete();
    } else if (nextStep != null) {
      setState(() {
        _currentStep = nextStep;
      });
    }
  }

  // Callbacks for each step
  void _onNameComplete() => _goToNextStep();

  void _onBirthDataComplete() => _goToNextStep();

  void _onRelationshipComplete(RelationshipStatus status) {
    ref.read(userProvider.notifier).setRelationshipStatus(status.name);
    _goToNextStep();
  }

  void _onIntentionComplete(List<SpiritualIntention> intentions) {
    final intentionNames = intentions.map((i) => i.name).toList();
    ref.read(userProvider.notifier).setIntentions(intentionNames);
    _goToNextStep();
  }

  void _onKnowledgeComplete(KnowledgeLevel level) {
    ref.read(userProvider.notifier).setKnowledgeLevel(level.name);
    _goToNextStep();
  }

  void _onToneComplete(PreferredTone tone) {
    ref.read(userProvider.notifier).setPreferredTone(tone.name);
    _goToNextStep();
  }

  void _onRevealComplete() {
    ref.read(userProvider.notifier).completeOnboarding();
    _goToNextStep();
  }

  void _onPaywallComplete() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = _controller.totalSteps;
    final currentStepNumber = _controller.getStepNumber(_currentStep);

    switch (_currentStep) {
      case OnboardingStepType.name:
        return OnboardingNameScreen(
          onComplete: _onNameComplete,
        );

      case OnboardingStepType.birthData:
        return OnboardingBirthDataScreen(
          currentStep: currentStepNumber,
          totalSteps: totalSteps,
          onComplete: _onBirthDataComplete,
        );

      case OnboardingStepType.relationship:
        return OnboardingRelationshipScreen(
          currentStep: currentStepNumber,
          totalSteps: totalSteps,
          onComplete: _onRelationshipComplete,
        );

      case OnboardingStepType.intention:
        return OnboardingIntentionScreen(
          currentStep: currentStepNumber,
          totalSteps: totalSteps,
          onComplete: _onIntentionComplete,
        );

      case OnboardingStepType.knowledge:
        return OnboardingKnowledgeScreen(
          currentStep: currentStepNumber,
          totalSteps: totalSteps,
          onComplete: _onKnowledgeComplete,
        );

      case OnboardingStepType.tone:
        return OnboardingToneScreen(
          currentStep: currentStepNumber,
          totalSteps: totalSteps,
          onComplete: _onToneComplete,
        );

      case OnboardingStepType.reveal:
        return OnboardingRevealScreen(
          onComplete: _onRevealComplete,
        );

      case OnboardingStepType.paywall:
        return PaywallView(
          onPurchase: _onPaywallComplete,
          onClose: _onPaywallComplete,
        );

      case OnboardingStepType.complete:
        // Should not reach here, but handle gracefully
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onComplete();
        });
        return const SizedBox.shrink();
    }
  }
}

/// Helper extension for getting platform-specific step info.
extension OnboardingStepTypeExtension on OnboardingStepType {
  /// Get display name for the step.
  String get displayName {
    switch (this) {
      case OnboardingStepType.name:
        return 'Your Name';
      case OnboardingStepType.birthData:
        return 'Birth Data';
      case OnboardingStepType.relationship:
        return 'Relationship';
      case OnboardingStepType.intention:
        return 'Interests';
      case OnboardingStepType.knowledge:
        return 'Experience';
      case OnboardingStepType.tone:
        return 'Preferences';
      case OnboardingStepType.reveal:
        return 'Your Sign';
      case OnboardingStepType.paywall:
        return 'Premium';
      case OnboardingStepType.complete:
        return 'Complete';
    }
  }

  /// Check if this is an astrology-related step (skipped on iOS).
  bool get isAstrologyStep {
    return this == OnboardingStepType.birthData ||
        this == OnboardingStepType.reveal;
  }
}
