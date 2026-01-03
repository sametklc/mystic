import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../profile/presentation/pages/profile_screen.dart';
import '../../../sky_hall/data/providers/sky_hall_provider.dart';
import '../widgets/character_carousel.dart';
import '../widgets/cosmic_insight_card.dart';
import '../widgets/daily_tarot_card.dart';

/// Gold color for premium section headers
const Color _goldColor = Color(0xFFFFD700);
const Color _goldDark = Color(0xFFB8860B);

/// Home page with character selection carousel and daily rituals.
/// Features a cinematic, ethereal design language.
/// Compact layout - everything fits on a single screen without scrolling.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Fetch daily insight on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dailyInsightProvider.notifier).fetchDailyInsight();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return MysticBackgroundScaffold(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            // Carousel takes 50% of available height - the Hero element
            final carouselHeight = availableHeight * 0.50;
            // Minimum height for daily rituals cards (compact/panoramic)
            const minRitualsHeight = 120.0;

            return Column(
              children: [
                // ===== HEADER (Fixed, Compact) =====
                _buildHeader(context),

                const SizedBox(height: 4),

                // ===== SECTION: CHOOSE YOUR GUIDE =====
                _buildSectionHeader('CHOOSE YOUR GUIDE'),

                const SizedBox(height: 8),

                // ===== CHARACTER CAROUSEL (Dynamic Height: 42%) =====
                SizedBox(
                  height: carouselHeight,
                  child: const CharacterCarousel(),
                ),

                const SizedBox(height: 8),

                // ===== SECTION: DAILY RITUALS =====
                _buildSectionHeader('DAILY RITUALS'),

                const SizedBox(height: 8),

                // ===== DAILY RITUALS CARDS (Expanded - fills remaining) =====
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: minRitualsHeight),
                    child: _buildDailyRitualsSection(context),
                  ),
                ),

                // ===== BOTTOM PADDING for Navigation Bar =====
                SizedBox(height: 80 + bottomPadding),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Premium section header with gold text
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Left decorative line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _goldDark.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title text with gold gradient
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                _goldDark,
                _goldColor,
                _goldDark,
              ],
            ).createShader(bounds),
            child: Text(
              title,
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
                letterSpacing: 3.5,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right decorative line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _goldDark.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 500.ms);
  }

  Widget _buildHeader(BuildContext context) {
    final userName = ref.watch(userNameProvider);
    final insightState = ref.watch(dailyInsightProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
        vertical: 8,
      ),
      child: Row(
        children: [
          // Welcome Message (Left)
          Expanded(
            child: _buildWelcomeSection(userName),
          ),

          // Moon Phase (Center-Right)
          _buildMoonPhase(insightState),

          const SizedBox(width: AppConstants.spacingSmall),

          // Coin Balance (Far Right)
          _buildCoinBalance(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.2, end: 0, duration: 500.ms);
  }

  Widget _buildWelcomeSection(String? userName) {
    final displayName = userName ?? 'Seeker';
    final user = ref.watch(userProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
      },
      child: Row(
        children: [
          // Profile Avatar
          _buildProfileAvatar(user),
          const SizedBox(width: 12),
          // Welcome Text
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome,',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              Text(
                displayName,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(user) {
    return Container(
      width: 44,
      height: 44,
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
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: user.hasProfileImage
            ? Image.network(
                user.profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarFallback(user),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildAvatarFallback(user);
                },
              )
            : _buildAvatarFallback(user),
      ),
    );
  }

  Widget _buildAvatarFallback(user) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Text(
          user.initials,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMoonPhase(DailyInsightState insightState) {
    final moonPhase = insightState.hasInsight
        ? insightState.insight!.moonPhase
        : 'Loading...';
    final moonIcon = insightState.hasInsight
        ? insightState.insight!.moonPhaseIconData
        : Icons.nightlight_round;

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
            moonIcon,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppConstants.spacingXSmall),
          Text(
            moonPhase,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
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
            '\u{1F48E}',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(width: AppConstants.spacingXSmall),
          Text(
            '100',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRitualsSection(BuildContext context) {
    final insightState = ref.watch(dailyInsightProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 400 ? 20 : 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Daily Tarot Card
          Expanded(
            child: const DailyTarotCard()
                .animate()
                .fadeIn(delay: 400.ms, duration: 500.ms)
                .slideX(begin: -0.1, end: 0, delay: 400.ms, duration: 500.ms),
          ),
          const SizedBox(width: 16),
          // Cosmic Insight Card
          Expanded(
            child: CosmicInsightCard(
              insight: insightState.insight,
              isLoading: insightState.isLoading,
              hasError: insightState.hasError,
              onTap: () {
                if (insightState.hasInsight) {
                  _showCosmicInsightSheet(context, insightState.insight!);
                }
              },
              onRetry: () {
                ref.read(dailyInsightProvider.notifier).fetchDailyInsight(forceRefresh: true);
              },
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 500.ms)
                .slideX(begin: 0.1, end: 0, delay: 500.ms, duration: 500.ms),
          ),
        ],
      ),
    );
  }

  void _showCosmicInsightSheet(BuildContext context, insight) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CosmicInsightBottomSheet(insight: insight),
    );
  }
}
