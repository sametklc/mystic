import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/constants.dart';
import 'core/services/user_firestore_service.dart';
import 'core/services/device_id_service.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/onboarding/onboarding.dart';
import 'features/profile/presentation/pages/grimoire_screen.dart';
import 'features/sky_hall/sky_hall.dart';
import 'features/sky_hall/presentation/pages/love_match_screen.dart';
import 'features/tarot/presentation/pages/tarot_selection_screen.dart';
import 'shared/providers/providers.dart';
import 'shared/widgets/mystic_background/mystic_background_scaffold.dart';

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
  relationship,
  intention,
  knowledge,
  tone,
  reveal,
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

    // Set gender
    if (user.gender != null) {
      notifier.setGender(user.gender!);
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
    setState(() {
      _currentStep = OnboardingStep.relationship;
    });
  }

  void _onRelationshipComplete(RelationshipStatus status) {
    ref.read(userProvider.notifier).setRelationshipStatus(status.name);
    setState(() {
      _currentStep = OnboardingStep.intention;
    });
  }

  void _onIntentionComplete(List<SpiritualIntention> intentions) {
    final intentionNames = intentions.map((i) => i.name).toList();
    ref.read(userProvider.notifier).setIntentions(intentionNames);
    setState(() {
      _currentStep = OnboardingStep.knowledge;
    });
  }

  void _onKnowledgeComplete(KnowledgeLevel level) {
    ref.read(userProvider.notifier).setKnowledgeLevel(level.name);
    setState(() {
      _currentStep = OnboardingStep.tone;
    });
  }

  void _onToneComplete(PreferredTone tone) {
    ref.read(userProvider.notifier).setPreferredTone(tone.name);
    setState(() {
      _currentStep = OnboardingStep.reveal;
    });
  }

  void _onRevealComplete() {
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

        // Show current onboarding step (6 total steps: 0-5)
        switch (_currentStep) {
          case OnboardingStep.name:
            return OnboardingNameScreen(
              onComplete: _onNameComplete,
            );
          case OnboardingStep.birthData:
            return OnboardingBirthDataScreen(
              currentStep: 1,
              totalSteps: 6,
              onComplete: _onBirthDataComplete,
            );
          case OnboardingStep.relationship:
            return OnboardingRelationshipScreen(
              currentStep: 2,
              totalSteps: 6,
              onComplete: _onRelationshipComplete,
            );
          case OnboardingStep.intention:
            return OnboardingIntentionScreen(
              currentStep: 3,
              totalSteps: 6,
              onComplete: _onIntentionComplete,
            );
          case OnboardingStep.knowledge:
            return OnboardingKnowledgeScreen(
              currentStep: 4,
              totalSteps: 6,
              onComplete: _onKnowledgeComplete,
            );
          case OnboardingStep.tone:
            return OnboardingToneScreen(
              currentStep: 5,
              totalSteps: 6,
              onComplete: _onToneComplete,
            );
          case OnboardingStep.reveal:
            return OnboardingRevealScreen(
              onComplete: _onRevealComplete,
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
/// 5 tabs: Sanctuary (Home), Oracle, Sky Hall, Love Match, Grimoire
class MainAppScaffold extends ConsumerStatefulWidget {
  const MainAppScaffold({super.key});

  @override
  ConsumerState<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends ConsumerState<MainAppScaffold> {
  int _currentIndex = 0;

  // 5-tab structure
  final List<Widget> _pages = const [
    HomePage(),
    // Oracle tab - TarotSelectionScreen in tab mode (no back button, skip charging)
    TarotSelectionScreen(
      isTabMode: true,
      skipCharging: true,
    ),
    SkyHallPage(), // Now has 3 sub-tabs: Daily, Chart, Guide
    LoveMatchWrapper(), // Standalone Love Match with its own scaffold
    GrimoireScreen(),
  ];

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    }
  }

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
              horizontal: 4,
              vertical: AppConstants.spacingSmall,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_filled,
                  label: 'Sanctuary',
                  color: AppColors.primary,
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.visibility_rounded,
                  label: 'Oracle',
                  color: AppColors.secondary,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.auto_awesome_rounded,
                  label: 'Sky Hall',
                  color: AppColors.mysticTeal,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.favorite_rounded,
                  label: 'Love',
                  color: const Color(0xFFFF6B9D), // Rose pink for love
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.auto_stories_rounded,
                  label: 'Grimoire',
                  color: const Color(0xFFE0B0FF), // Light purple
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

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : AppColors.textTertiary,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected ? color : AppColors.textTertiary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper for LoveMatchScreen to give it its own scaffold
class LoveMatchWrapper extends ConsumerWidget {
  const LoveMatchWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MysticBackgroundScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMedium),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF6B9D).withOpacity(0.3),
                          AppColors.primary.withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Color(0xFFFF6B9D),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOVE MATCH',
                          style: AppTypography.labelMedium.copyWith(
                            color: const Color(0xFFFF6B9D),
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          'Cosmic Compatibility',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Love Match Content
            const Expanded(
              child: LoveMatchScreen(),
            ),
          ],
        ),
      ),
    );
  }
}
