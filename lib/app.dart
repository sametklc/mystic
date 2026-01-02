import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/constants.dart';
import 'core/services/user_firestore_service.dart';
import 'core/services/device_id_service.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/onboarding/onboarding.dart';
import 'features/profile/presentation/pages/grimoire_screen.dart';
import 'features/sky_hall/sky_hall.dart';
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

/// Provider to load user data from Firestore on app start.
final userDataLoaderProvider = FutureProvider<bool>((ref) async {
  final deviceId = ref.watch(deviceIdProvider);
  final firestoreService = ref.watch(userFirestoreServiceProvider);

  // Load user from Firestore
  final user = await firestoreService.loadUser(deviceId);

  if (user != null && user.hasCompletedOnboarding) {
    // User exists and completed onboarding - update local state
    final notifier = ref.read(userProvider.notifier);

    // Set name
    if (user.name != null) {
      notifier.setName(user.name!);
    }

    // Set birth data
    if (user.birthDate != null && user.birthLatitude != null) {
      notifier.setBirthData(
        date: user.birthDate!,
        time: user.birthTime,
        latitude: user.birthLatitude!,
        longitude: user.birthLongitude ?? 0,
        timezone: user.birthTimezone,
        city: user.birthCity,
      );
    }

    // Set signs
    if (user.sunSign != null || user.risingSign != null) {
      notifier.setSigns(
        sunSign: user.sunSign,
        risingSign: user.risingSign,
      );
    }

    // Mark as complete
    notifier.completeOnboarding();

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
    // First, load user data from Firestore
    final userDataAsync = ref.watch(userDataLoaderProvider);

    return userDataAsync.when(
      loading: () => _buildLoadingScreen(),
      error: (error, stack) => _buildLoadingScreen(), // On error, proceed to onboarding
      data: (userExists) {
        // If user exists in Firestore and completed onboarding, show main app
        if (userExists) {
          return const MainAppScaffold();
        }

        // Check local state as well
        final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);
        if (hasCompletedOnboarding || _currentStep == OnboardingStep.complete) {
          return const MainAppScaffold();
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
            return const MainAppScaffold();
        }
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mystical loading indicator
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aligning the stars...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main app scaffold with bottom navigation.
class MainAppScaffold extends ConsumerStatefulWidget {
  const MainAppScaffold({super.key});

  @override
  ConsumerState<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends ConsumerState<MainAppScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    SkyHallPage(),
    GrimoireScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMedium,
              vertical: AppConstants.spacingSmall,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  color: AppColors.primary,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.auto_awesome_rounded,
                  label: 'Sky Hall',
                  color: AppColors.mysticTeal,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.auto_stories_rounded,
                  label: 'Grimoire',
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.textTertiary,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
