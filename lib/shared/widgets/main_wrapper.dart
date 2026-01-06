import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/ios_chat/presentation/pages/ios_chat_home.dart';
import '../../features/profile/presentation/pages/grimoire_screen.dart';
import '../../features/sky_hall/sky_hall.dart';
import '../../features/sky_hall/presentation/pages/love_match_screen.dart';
import '../../features/tarot/presentation/pages/tarot_hub_screen.dart';
import '../widgets/mystic_background/mystic_background_scaffold.dart';

/// MainWrapper - Platform-specific root widget after onboarding/splash.
///
/// This widget determines which UI to show based on the platform:
/// - **Android**: Full 5-tab navigation with Tarot, Astrology, etc.
/// - **iOS**: Chat-style interface with AI personas (App Store compliant)
///
/// Usage:
/// ```dart
/// // In your app after onboarding is complete:
/// return const MainWrapper();
/// ```
class MainWrapper extends ConsumerWidget {
  const MainWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Platform-specific UI routing
    if (Platform.isIOS) {
      // iOS: Show chat-style interface for App Store compliance
      return const IOSCharacterHome();
    } else {
      // Android: Show full tab navigation
      return const AndroidMainScaffold();
    }
  }
}

/// iOS Character Home - Chat-style interface for App Store compliance.
///
/// Presents AI personas as "wellness guides" rather than fortune tellers.
/// This is a wrapper around IOSChatHome for naming consistency.
class IOSCharacterHome extends StatelessWidget {
  const IOSCharacterHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const IOSChatHome();
  }
}

/// Android Main Scaffold - Full 5-tab navigation.
///
/// Tabs:
/// 1. Sanctuary (Home) - Daily card, character carousel
/// 2. Tarot (Oracle) - Card spreads and readings
/// 3. Sky Hall - Horoscope, birth chart, astro guide
/// 4. Love Match - Synastry compatibility
/// 5. Grimoire - Reading history, journal, gallery
class AndroidMainScaffold extends ConsumerStatefulWidget {
  const AndroidMainScaffold({super.key});

  @override
  ConsumerState<AndroidMainScaffold> createState() => _AndroidMainScaffoldState();
}

class _AndroidMainScaffoldState extends ConsumerState<AndroidMainScaffold> {
  int _currentIndex = 0;

  // 5-tab structure
  final List<Widget> _pages = const [
    HomePage(),
    TarotHubScreen(),
    SkyHallPage(),
    LoveMatchWrapper(),
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
                  label: 'Tarot',
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
                  color: const Color(0xFFFF6B9D),
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.auto_stories_rounded,
                  label: 'Grimoire',
                  color: const Color(0xFFE0B0FF),
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

/// Wrapper for LoveMatchScreen to give it its own scaffold.
class LoveMatchWrapper extends ConsumerWidget {
  const LoveMatchWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: MysticBackgroundScaffold(
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
      ),
    );
  }
}
