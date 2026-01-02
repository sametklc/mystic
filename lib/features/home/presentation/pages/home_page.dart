import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../sky_hall/data/providers/sky_hall_provider.dart';
import '../../../sky_hall/domain/models/daily_insight_model.dart';
import '../../../tarot/presentation/pages/tarot_selection_screen.dart';
import '../providers/character_provider.dart';
import '../widgets/character_carousel.dart';

/// Home page with character selection carousel and daily rituals.
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
    return MysticBackgroundScaffold(
      child: SafeArea(
        bottom: false, // Don't add bottom padding, bottom nav handles it
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use smaller spacing on shorter screens
            final isCompact = constraints.maxHeight < 700;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header Section
                    _buildHeader(context),

                    SizedBox(height: isCompact ? 8 : 16),

                    // App Title
                    _buildAppTitle(),

                    SizedBox(height: isCompact ? 4 : AppConstants.spacingSmall),

                    // Tagline based on selected character
                    _buildCharacterTagline(),

                    SizedBox(height: isCompact ? 8 : 16),

                    // Character Carousel (~55-60% of screen)
                    const CharacterCarousel(),

                    SizedBox(height: isCompact ? 8 : 16),

                    // Daily Rituals Section
                    _buildDailyRitualsSection(context, isCompact),

                    // Bottom padding for bottom navigation bar
                    SizedBox(height: isCompact ? 70 : 80),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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

          const SizedBox(width: AppConstants.spacingSmall),

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

  Widget _buildCharacterTagline() {
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

  Widget _buildDailyRitualsSection(BuildContext context, bool isCompact) {
    final insightState = ref.watch(dailyInsightProvider);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppConstants.spacingSmall : AppConstants.spacingMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section Header
          Padding(
            padding: EdgeInsets.only(
              left: AppConstants.spacingSmall,
              bottom: isCompact ? 4 : AppConstants.spacingSmall,
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
                  isCompact: isCompact,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TarotSelectionScreen(),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: isCompact ? AppConstants.spacingSmall : AppConstants.spacingMedium),
              Expanded(
                child: _buildCosmicInsightCard(context, insightState, isCompact),
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

  Widget _buildCosmicInsightCard(BuildContext context, DailyInsightState state, bool isCompact) {
    if (state.isLoading) {
      return _buildCosmicInsightLoading(isCompact);
    }

    if (state.hasInsight) {
      return _buildCosmicInsightSuccess(context, state.insight!, isCompact);
    }

    // Error or initial state - show placeholder
    return _buildActionCard(
      icon: Icons.public_rounded,
      title: 'Cosmic Insight',
      subtitle: state.hasError ? 'Tap to retry' : 'Loading...',
      color: AppColors.mysticTeal,
      isCompact: isCompact,
      onTap: () {
        ref.read(dailyInsightProvider.notifier).fetchDailyInsight(forceRefresh: true);
      },
    );
  }

  Widget _buildCosmicInsightLoading(bool isCompact) {
    final padding = isCompact ? AppConstants.spacingSmall : AppConstants.spacingMedium;
    final iconSize = isCompact ? 32.0 : 40.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Shimmer.fromColors(
          baseColor: AppColors.mysticTeal.withOpacity(0.1),
          highlightColor: AppColors.mysticTeal.withOpacity(0.3),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              color: AppColors.glassFill,
              border: Border.all(
                color: AppColors.mysticTeal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon placeholder
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mysticTeal.withOpacity(0.2),
                  ),
                ),
                SizedBox(height: isCompact ? 4 : AppConstants.spacingSmall),
                // Title placeholder
                Container(
                  width: 80,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.mysticTeal.withOpacity(0.2),
                  ),
                ),
                SizedBox(height: isCompact ? 2 : AppConstants.spacingXSmall),
                // Subtitle placeholder
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.mysticTeal.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCosmicInsightSuccess(BuildContext context, DailyInsight insight, bool isCompact) {
    final padding = isCompact ? AppConstants.spacingSmall : AppConstants.spacingMedium;
    final iconPadding = isCompact ? 6.0 : AppConstants.spacingSmall;
    final iconSize = isCompact ? 20.0 : 24.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showCosmicInsightSheet(context, insight);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.mysticTeal.withOpacity(0.15),
                  AppColors.glassFill,
                ],
              ),
              border: Border.all(
                color: AppColors.mysticTeal.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mysticTeal.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Moon Phase Icon with glow
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mysticTeal.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mysticTeal.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    insight.moonPhaseIconData,
                    color: AppColors.mysticTeal,
                    size: iconSize,
                  ),
                ),

                SizedBox(height: isCompact ? 4 : AppConstants.spacingSmall),

                // Moon Phase Name
                Text(
                  insight.moonPhase,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                SizedBox(height: isCompact ? 2 : AppConstants.spacingXSmall),

                // Moon Sign with symbol
                Row(
                  children: [
                    Text(
                      insight.moonSignSymbol,
                      style: TextStyle(
                        fontSize: 12,
                        color: insight.elementColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Moon in ${insight.moonSign}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCosmicInsightSheet(BuildContext context, DailyInsight insight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CosmicInsightBottomSheet(insight: insight),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    final padding = isCompact ? AppConstants.spacingSmall : AppConstants.spacingMedium;
    final iconPadding = isCompact ? 6.0 : AppConstants.spacingSmall;
    final iconSize = isCompact ? 20.0 : 24.0;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(padding),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with glow
                Container(
                  padding: EdgeInsets.all(iconPadding),
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
                    size: iconSize,
                  ),
                ),

                SizedBox(height: isCompact ? 4 : AppConstants.spacingSmall),

                // Title
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                SizedBox(height: isCompact ? 2 : AppConstants.spacingXSmall),

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

/// Bottom sheet showing detailed cosmic insight.
class _CosmicInsightBottomSheet extends StatelessWidget {
  final DailyInsight insight;

  const _CosmicInsightBottomSheet({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(
          color: AppColors.mysticTeal.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Moon Phase Icon (Large)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.mysticTeal.withOpacity(0.3),
                        AppColors.mysticTeal.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mysticTeal.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    insight.moonPhaseIconData,
                    color: AppColors.mysticTeal,
                    size: 48,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),

                const SizedBox(height: 20),

                // Moon Phase Name
                Text(
                  insight.moonPhase,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms),

                const SizedBox(height: 8),

                // Moon Sign with Element
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      insight.moonSignSymbol,
                      style: TextStyle(
                        fontSize: 18,
                        color: insight.elementColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Moon in ${insight.moonSign}',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: insight.elementColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        insight.moonElement,
                        style: AppTypography.labelSmall.copyWith(
                          color: insight.elementColor,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 400.ms),

                const SizedBox(height: 8),

                // Illumination
                Text(
                  '${insight.moonIllumination.toStringAsFixed(0)}% Illuminated',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 24),

                // Divider
                Container(
                  width: 100,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.mysticTeal.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Mercury Status
                if (insight.mercuryRetrograde)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mercury Retrograde',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms)
                      .shake(hz: 2, rotation: 0.02),

                // Advice
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.mysticTeal.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppColors.mysticTeal.withOpacity(0.7),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        insight.advice,
                        style: AppTypography.mysticalQuote.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 500.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 24),

                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.textTertiary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms),

                // Bottom padding for safe area
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
