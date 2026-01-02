import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/providers/sky_hall_provider.dart';
import '../widgets/natal_chart_painter.dart';
import '../widgets/planet_info_card.dart';
import 'love_match_screen.dart';

/// Sky Hall - Astrology feature page with natal chart and love match.
class SkyHallPage extends ConsumerStatefulWidget {
  const SkyHallPage({super.key});

  @override
  ConsumerState<SkyHallPage> createState() => _SkyHallPageState();
}

class _SkyHallPageState extends ConsumerState<SkyHallPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _expandedPlanetIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load natal chart on init if we have birth data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNatalChart();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadNatalChart() {
    final user = ref.read(userProvider);
    if (user.birthDate != null && user.birthLatitude != null) {
      ref.read(natalChartProvider.notifier).calculateChart(
            date: user.birthDate!,
            time: user.birthTime ?? '12:00',
            latitude: user.birthLatitude!,
            longitude: user.birthLongitude ?? 0,
            timezone: user.birthTimezone ?? 'UTC',
            name: user.name,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartState = ref.watch(natalChartProvider);
    final userName = ref.watch(userNameProvider);

    return MysticBackgroundScaffold(
      child: SafeArea(
        bottom: false, // Bottom nav handles this
        child: Column(
            children: [
              // Header
              _buildHeader(userName ?? 'Seeker'),

              // Tab Bar
              _buildTabBar(),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // My Chart Tab
                    _buildMyChartTab(chartState),

                    // Love Match Tab
                    const LoveMatchScreen(),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      child: Row(
        children: [
          // Star icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.mysticTeal.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.2),
                ],
              ),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.mysticTeal,
              size: 24,
            ),
          ),

          const SizedBox(width: AppConstants.spacingMedium),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SKY HALL',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.mysticTeal,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  'Celestial Map of $userName',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Info button
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('View your natal chart and check love compatibility'),
                  backgroundColor: AppColors.mysticTeal.withOpacity(0.9),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassFill,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(
                Icons.info_outline,
                color: AppColors.mysticTeal,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMedium),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.mysticTeal.withOpacity(0.4),
              AppColors.primary.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound - 2),
          border: Border.all(
            color: AppColors.mysticTeal.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.mysticTeal.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.labelMedium,
        dividerHeight: 0,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(text: 'My Chart'),
          Tab(text: 'Love Match'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildMyChartTab(NatalChartState chartState) {
    if (chartState.isLoading) {
      return _buildLoadingState();
    }

    if (chartState.hasError) {
      return _buildErrorState(chartState.error!);
    }

    if (!chartState.hasChart) {
      return _buildEmptyState();
    }

    final chart = chartState.chart!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Natal Chart Wheel
          Center(
            child: NatalChartWheel(
              chart: chart,
              size: MediaQuery.of(context).size.width - 80,
              primaryColor: AppColors.mysticTeal,
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 600.ms).scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
              ),

          const SizedBox(height: AppConstants.spacingLarge),

          // Big Three Summary
          if (chart.sunMoonRisingSummary != null)
            _buildSummaryCard(chart.sunMoonRisingSummary!),

          const SizedBox(height: AppConstants.spacingLarge),

          // Planet Cards
          _buildPlanetsList(chart),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String summary) {
    return ClipRRect(
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
                AppColors.mysticTeal.withOpacity(0.15),
                AppColors.primary.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: AppColors.mysticTeal.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AppColors.mysticTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Cosmic Essence',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.mysticTeal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSmall),
              Text(
                summary,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildPlanetsList(chart) {
    final planets = chart.allPlanets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
          child: Text(
            'PLANETARY POSITIONS',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
        ),
        for (int i = 0; i < planets.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
            child: PlanetInfoCard(
              planet: planets[i],
              isExpanded: _expandedPlanetIndex == i,
              onTap: () {
                setState(() {
                  _expandedPlanetIndex = _expandedPlanetIndex == i ? null : i;
                });
              },
            ),
          ).animate().fadeIn(
                delay: Duration(milliseconds: 600 + i * 50),
                duration: 300.ms,
              ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.mysticTeal),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMedium),
          Text(
            'Reading the stars...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Text(
              'Failed to calculate chart',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              error,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingLarge),
            ElevatedButton(
              onPressed: _loadNatalChart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mysticTeal,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✨',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Text(
              'Birth Data Needed',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              'Complete your birth details to see your celestial map.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
