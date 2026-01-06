import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../paywall/paywall.dart';
import '../../data/providers/sky_hall_provider.dart';
import '../widgets/natal_chart_painter.dart';
import '../widgets/planet_info_card.dart';
import '../widgets/daily_horoscope_widget.dart';
import '../widgets/astro_guide_chat_widget.dart';

/// Sky Hall - Astrology feature page with 3 sub-tabs: Daily, Chart, Guide.
class SkyHallPage extends ConsumerStatefulWidget {
  const SkyHallPage({super.key});

  @override
  ConsumerState<SkyHallPage> createState() => _SkyHallPageState();
}

class _SkyHallPageState extends ConsumerState<SkyHallPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _expandedPlanetIndex;
  String? _lastProfileId;

  @override
  void initState() {
    super.initState();
    // 3 tabs: Daily, Chart, Guide
    _tabController = TabController(length: 3, vsync: this);

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
    // Use current profile data (changes based on selected profile)
    final profile = ref.read(currentProfileProvider);
    if (profile?.birthDate != null && profile?.birthLatitude != null) {
      ref.read(natalChartProvider.notifier).calculateChart(
            date: profile!.birthDate!,
            time: profile.birthTime ?? '12:00',
            latitude: profile.birthLatitude!,
            longitude: profile.birthLongitude ?? 0,
            timezone: profile.birthTimezone ?? 'UTC',
            name: profile.name,
          );
    } else {
      // Clear chart if no birth data
      ref.read(natalChartProvider.notifier).clearChart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartState = ref.watch(natalChartProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final userName = currentProfile?.name ?? 'Seeker';

    // Reload chart when profile changes
    if (currentProfile?.id != _lastProfileId) {
      _lastProfileId = currentProfile?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNatalChart();
      });
    }

    return MysticBackgroundScaffold(
      child: SafeArea(
        bottom: false, // Bottom nav handles this
        child: Column(
          children: [
            // Header
            _buildHeader(userName),

            // Tab Bar (Trinity Tabs)
            _buildTrinityTabBar(),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Daily (Cosmic Pulse)
                  const DailyHoroscopeWidget(),

                  // Tab 2: Chart (Natal Wheel)
                  _buildChartTab(chartState),

                  // Tab 3: Guide (Astro Chat)
                  const AstroGuideChatWidget(),
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
                  content: Text('View your daily forecast, natal chart, and chat with your astro guide'),
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

  Widget _buildTrinityTabBar() {
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
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_sunny_outlined, size: 16),
                SizedBox(width: 4),
                Text('Daily'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radio_button_unchecked, size: 16),
                SizedBox(width: 4),
                Text('Chart'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16),
                SizedBox(width: 4),
                Text('Guide'),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildChartTab(NatalChartState chartState) {
    // Check premium status first
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      return _buildLockedChartState();
    }

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
              '\u2728',
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

  /// Locked state widget for non-premium users
  Widget _buildLockedChartState() {
    const goldAccent = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);

    return Stack(
      children: [
        // Blurred zodiac wheel background
        Positioned.fill(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Opacity(
                opacity: 0.4,
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width - 40,
                    height: MediaQuery.of(context).size.width - 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.mysticTeal.withOpacity(0.3),
                          AppColors.primary.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.2, 0.6, 1.0],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _ZodiacWheelPainter(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Centered content
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing lock icon with gold color
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        goldAccent.withOpacity(0.3),
                        goldAccent.withOpacity(0.1),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: goldAccent.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          goldAccent,
                          goldDark,
                        ],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: AppConstants.spacingLarge),

                // Headline
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      goldAccent,
                      goldDark,
                      goldAccent,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'Discover Your Soul\'s Blueprint',
                    style: AppTypography.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                const SizedBox(height: AppConstants.spacingMedium),

                // Subtext
                Text(
                  'Unlock the secrets written in the stars at the moment of your birth. Your natal chart reveals your cosmic DNA—personality traits, life purpose, and hidden potentials.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                const SizedBox(height: AppConstants.spacingXLarge),

                // CTA Button - "Reveal My Chart"
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaywallView(
                          onClose: () => Navigator.of(context).pop(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1025),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: goldAccent.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: goldAccent.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [goldAccent, goldDark],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [goldAccent, goldDark],
                          ).createShader(bounds),
                          child: Text(
                            'Reveal My Chart',
                            style: AppTypography.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      curve: Curves.easeOut,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for a simple zodiac wheel silhouette
class _ZodiacWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring
    final outerPaint = Paint()
      ..color = AppColors.mysticTeal.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius * 0.95, outerPaint);
    canvas.drawCircle(center, radius * 0.75, outerPaint);
    canvas.drawCircle(center, radius * 0.55, outerPaint);

    // Division lines (12 zodiac sections)
    final linePaint = Paint()
      ..color = AppColors.mysticTeal.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final startPoint = Offset(
        center.dx + radius * 0.55 * math.cos(angle),
        center.dy + radius * 0.55 * math.sin(angle),
      );
      final endPoint = Offset(
        center.dx + radius * 0.95 * math.cos(angle),
        center.dy + radius * 0.95 * math.sin(angle),
      );
      canvas.drawLine(startPoint, endPoint, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
