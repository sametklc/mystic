import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../providers/character_provider.dart';
import '../widgets/character_carousel.dart';

/// Home page with character selection carousel and daily rituals.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: MysticBackgroundScaffold(
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(context, ref),

              const Spacer(flex: 1),

              // App Title
              _buildAppTitle(),

              const SizedBox(height: AppConstants.spacingSmall),

              // Tagline based on selected character
              _buildCharacterTagline(ref),

              const Spacer(flex: 1),

              // Character Carousel (~55-60% of screen)
              const CharacterCarousel(),

              const Spacer(flex: 1),

              // Daily Rituals Section
              _buildDailyRitualsSection(context),

              const SizedBox(height: AppConstants.spacingLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
        vertical: AppConstants.spacingSmall,
      ),
      child: Row(
        children: [
          // Welcome Message (Left)
          Expanded(
            child: _buildWelcomeSection(userName),
          ),

          // Moon Phase (Center-Right)
          _buildMoonPhase(),

          const SizedBox(width: AppConstants.spacingMedium),

          // Coin Balance (Far Right)
          _buildCoinBalance(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.3, end: 0, duration: 600.ms);
  }

  Widget _buildWelcomeSection(String? userName) {
    final displayName = userName ?? 'Seeker';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome,',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          displayName,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMoonPhase() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSmall,
        vertical: AppConstants.spacingXSmall,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
        color: AppColors.glassFill,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.nightlight_round,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppConstants.spacingXSmall),
          Text(
            'Waning Gibbous',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinBalance() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSmall,
        vertical: AppConstants.spacingXSmall,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '\u{1F48E}', // Diamond emoji
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(width: AppConstants.spacingXSmall),
          Text(
            '100',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          AppColors.primary,
          AppColors.primaryLight,
          AppColors.primary,
        ],
      ).createShader(bounds),
      child: Text(
        AppConstants.appName,
        style: AppTypography.displayMedium.copyWith(
          color: Colors.white,
          shadows: [
            Shadow(
              color: AppColors.primaryGlow,
              blurRadius: 20,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          delay: 200.ms,
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildCharacterTagline(WidgetRef ref) {
    final character = ref.watch(selectedCharacterProvider);

    return Text(
      'Choose your guide',
      style: AppTypography.mysticalQuote.copyWith(
        color: character.themeColor.withOpacity(0.8),
      ),
    )
        .animate()
        .fadeIn(delay: 400.ms, duration: 600.ms);
  }

  Widget _buildDailyRitualsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.spacingSmall,
              bottom: AppConstants.spacingSmall,
            ),
            child: Text(
              'DAILY RITUALS',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 2.0,
              ),
            ),
          ),

          // Action Cards Row
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.style_rounded,
                  title: 'Daily Tarot',
                  subtitle: 'Your card of the day',
                  color: AppColors.secondary,
                  onTap: () {
                    // Navigate to daily tarot
                  },
                ),
              ),
              const SizedBox(width: AppConstants.spacingMedium),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.public_rounded,
                  title: 'Cosmic Insight',
                  subtitle: 'Planetary transits',
                  color: AppColors.mysticTeal,
                  onTap: () {
                    // Navigate to cosmic insight
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 600.ms)
        .slideY(begin: 0.2, end: 0, delay: 800.ms, duration: 600.ms);
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                  color.withOpacity(0.15),
                  AppColors.glassFill,
                ],
              ),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with glow
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingSmall),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),

                const SizedBox(height: AppConstants.spacingSmall),

                // Title
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: AppConstants.spacingXSmall),

                // Subtitle
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
