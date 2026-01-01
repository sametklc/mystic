import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/onboarding/onboarding.dart';
import 'shared/providers/providers.dart';

/// The root widget of the Mystic application.
class MysticApp extends ConsumerWidget {
  const MysticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      // App Configuration
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Force dark mode only

      // Home - Uses the AppShell to determine which screen to show
      home: const AppShell(),

      // Builder for global configurations
      builder: (context, child) {
        // Apply any global overlays or configurations here
        return MediaQuery(
          // Prevent system font scaling from breaking layout
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Onboarding steps
enum OnboardingStep {
  name,
  birthData,
  complete,
}

/// The app shell that determines which screen to show based on user state.
/// Handles the multi-step onboarding flow and transition to main app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  OnboardingStep _currentStep = OnboardingStep.name;

  void _onNameComplete() {
    setState(() {
      _currentStep = OnboardingStep.birthData;
    });
  }

  void _onBirthDataComplete() {
    ref.read(userProvider.notifier).completeOnboarding();
    setState(() {
      _currentStep = OnboardingStep.complete;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

    // If already completed onboarding, show home
    if (hasCompletedOnboarding || _currentStep == OnboardingStep.complete) {
      return const HomePage();
    }

    // Show current onboarding step
    switch (_currentStep) {
      case OnboardingStep.name:
        return OnboardingNameScreen(
          onComplete: _onNameComplete,
        );
      case OnboardingStep.birthData:
        return OnboardingBirthDataScreen(
          onComplete: _onBirthDataComplete,
        );
      case OnboardingStep.complete:
        return const HomePage();
    }
  }
}
