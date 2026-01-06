import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/constants.dart';
import 'core/services/user_firestore_service.dart';
import 'core/services/device_id_service.dart';
import 'features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'features/paywall/paywall.dart';
import 'shared/providers/providers.dart';
import 'shared/widgets/main_wrapper.dart';
import 'shared/widgets/mystic_splash_screen.dart';

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

/// Provider to load user data from Firestore on app start.
/// Now uses UserModel.fromJson() which handles multi-profile format
/// and automatic migration from old single-profile format.
final userDataLoaderProvider = FutureProvider<bool>((ref) async {
  final deviceId = ref.watch(deviceIdProvider);
  final firestoreService = ref.watch(userFirestoreServiceProvider);

  // Load user from Firestore (handles old and new format automatically)
  final user = await firestoreService.loadUser(deviceId);

  if (user != null && user.hasCompletedOnboarding) {
    // User exists and completed onboarding - reload from notifier
    // The UserNotifier already loads from Firestore on init,
    // so we just need to trigger a reload to ensure sync
    await ref.read(userProvider.notifier).reload();
    return true; // User exists
  }

  return false; // New user, needs onboarding
});

/// The app shell that determines which screen to show based on user state.
/// Handles the multi-step onboarding flow and transition to main app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Track if splash screen has been shown
  bool _hasShownSplash = false;

  // Track if minimum splash duration has passed
  bool _minSplashDurationPassed = false;

  // Track if paywall has been shown this session (for returning users)
  bool _hasShownPaywallThisSession = false;

  // Track if onboarding is complete (set by OnboardingFlow)
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    // Start minimum splash timer
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() => _minSplashDurationPassed = true);
      }
    });
  }

  void _onOnboardingComplete() {
    setState(() {
      _onboardingComplete = true;
      _hasShownPaywallThisSession = true;
    });
  }

  void _onPaywallComplete() {
    setState(() {
      _hasShownPaywallThisSession = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pre-fetch user data while splash is showing
    final userDataAsync = ref.watch(userDataLoaderProvider);

    // Determine if data loading is complete
    final isDataReady = userDataAsync.hasValue || userDataAsync.hasError;

    // Show splash until BOTH minimum duration passed AND data is ready
    if (!_hasShownSplash) {
      // Check if we can transition away from splash
      if (_minSplashDurationPassed && isDataReady) {
        // Mark splash as shown so we don't show it again
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasShownSplash) {
            setState(() => _hasShownSplash = true);
          }
        });
      }

      return MysticSplashScreen(
        duration: const Duration(milliseconds: 6000), // Fallback max duration
        onComplete: () {
          // Safety fallback: always transition after max duration
          // (Normal transition happens via addPostFrameCallback above)
          if (mounted) {
            setState(() => _hasShownSplash = true);
          }
        },
      );
    }

    // After splash, data is already loaded - go directly to content
    final userExists = userDataAsync.valueOrNull ?? false;

    return _buildMainContent(userExists);
  }

  Widget _buildMainContent(bool userExists) {
    // Check premium status
    final isPremium = ref.watch(isPremiumProvider);

    // If user exists in Firestore and completed onboarding
    if (userExists) {
      // Only show paywall for non-premium users on app launch
      if (!isPremium && !_hasShownPaywallThisSession) {
        return PaywallView(
          onPurchase: _onPaywallComplete,
          onClose: _onPaywallComplete,
        );
      }
      // Use MainWrapper for platform-specific UI
      return const MainWrapper();
    }

    // Check local state as well
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);
    if (hasCompletedOnboarding || _onboardingComplete) {
      // Only show paywall for non-premium users
      if (!isPremium && !_hasShownPaywallThisSession) {
        return PaywallView(
          onPurchase: _onPaywallComplete,
          onClose: _onPaywallComplete,
        );
      }
      // Use MainWrapper for platform-specific UI
      return const MainWrapper();
    }

    // Show platform-specific onboarding flow
    // - Android: All 8 steps (name, birth data, relationship, intention, knowledge, tone, reveal, paywall)
    // - iOS: Only 3 steps (name, intention, paywall) - skips astrology-related screens
    return OnboardingFlow(
      onComplete: _onOnboardingComplete,
    );
  }
}
