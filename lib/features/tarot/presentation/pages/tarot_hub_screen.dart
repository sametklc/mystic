import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../../sky_hall/presentation/pages/love_match_screen.dart';
import 'tarot_card_selection_screen.dart';
import 'tarot_selection_screen.dart';

// =============================================================================
// SPREAD DEFINITION MODEL
// =============================================================================

/// Data model for a Tarot spread type
class SpreadDefinition {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isPremium;
  final int cardCount;
  final List<String> positions;

  const SpreadDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.isPremium,
    required this.cardCount,
    required this.positions,
  });
}

// =============================================================================
// COMPLETE SPREAD DEFINITIONS - ALL 6 TYPES
// =============================================================================

const List<SpreadDefinition> allSpreadDefinitions = [
  // 1. Love Match - Relationship Analysis
  SpreadDefinition(
    id: 'love',
    title: 'Love Match',
    subtitle: 'Relationship Analysis',
    icon: Icons.favorite_rounded,
    gradientColors: [
      Color(0xFFFF6B9D), // Rose Pink
      Color(0xFF9D00FF), // Electric Purple
    ],
    isPremium: false,
    cardCount: 4,
    positions: ['You', 'Them', 'Dynamics', 'Future Potential'],
  ),

  // 2. Career Path - Work & Finance
  SpreadDefinition(
    id: 'career',
    title: 'Career Path',
    subtitle: 'Work & Finance',
    icon: Icons.work_rounded,
    gradientColors: [
      Color(0xFFFFD700), // Gold
      Color(0xFFFF8C00), // Deep Orange/Amber
    ],
    isPremium: false,
    cardCount: 4,
    positions: ['Current Role', 'Challenges', 'Opportunities', 'Outcome'],
  ),

  // 3. The Crossroads - Decision Making
  SpreadDefinition(
    id: 'decision',
    title: 'The Crossroads',
    subtitle: 'Decision Making',
    icon: Icons.call_split_rounded,
    gradientColors: [
      Color(0xFF00CED1), // Teal
      Color(0xFF00A86B), // Emerald
    ],
    isPremium: false,
    cardCount: 4,
    positions: ['Current Situation', 'Path A Result', 'Path B Result', 'Advice'],
  ),

  // 4. Mind-Body-Spirit - Holistic Check-in
  SpreadDefinition(
    id: 'mind_body_spirit',
    title: 'Mind-Body-Spirit',
    subtitle: 'Holistic Check-in',
    icon: Icons.self_improvement_rounded,
    gradientColors: [
      Color(0xFFE0E0E0), // White/Silver
      Color(0xFF00BCD4), // Cyan
    ],
    isPremium: false,
    cardCount: 3,
    positions: ['Mind (Mental State)', 'Body (Physical/Action)', 'Spirit (Lesson)'],
  ),

  // 5. Three Card - Past, Present, Future
  SpreadDefinition(
    id: 'three_card',
    title: 'Three Card',
    subtitle: 'Past, Present, Future',
    icon: Icons.view_column_rounded,
    gradientColors: [
      Color(0xFFFF8C00), // Amber
      Color(0xFFFF5722), // Deep Orange
    ],
    isPremium: false,
    cardCount: 3,
    positions: ['Past', 'Present', 'Future'],
  ),

  // 6. Celtic Cross - Complete Analysis
  SpreadDefinition(
    id: 'celtic_cross',
    title: 'Celtic Cross',
    subtitle: 'Complete Analysis',
    icon: Icons.grid_view_rounded,
    gradientColors: [
      Color(0xFFFFD700), // Gold
      Color(0xFF212121), // Near Black
    ],
    isPremium: false,
    cardCount: 10,
    positions: [
      'Present',
      'Challenge',
      'Past',
      'Future',
      'Above (Goals)',
      'Below (Subconscious)',
      'Advice',
      'External Influences',
      'Hopes/Fears',
      'Outcome',
    ],
  ),
];

// =============================================================================
// TAROT HUB SCREEN
// =============================================================================

/// The Portal - A mystical hub for Tarot readings and AI Oracle consultations.
/// Features glassmorphism design with cosmic background effects.
class TarotHubScreen extends ConsumerStatefulWidget {
  const TarotHubScreen({super.key});

  @override
  ConsumerState<TarotHubScreen> createState() => _TarotHubScreenState();
}

class _TarotHubScreenState extends ConsumerState<TarotHubScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late AnimationController _glowController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    // Breathing animation for the Oracle card (scale up/down)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Glow pulsing effect
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Star particles animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider) ?? 'Seeker';
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 700;

    return MysticBackgroundScaffold(
      child: Stack(
        children: [
          // Star Particles Background
          Positioned.fill(
            child: _StarParticles(controller: _particleController),
          ),

          // Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header with Greeting
                _buildHeader(userName, isCompact)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, end: 0),

                SizedBox(height: isCompact ? 12 : 20),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: The Daily Oracle (Single Card Chat)
                        _buildOracleSection(isCompact)
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),

                        SizedBox(height: isCompact ? 28 : 40),

                        // Section 2: Sacred Spreads (All 6 Types)
                        _buildSpreadsSection(isCompact)
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String userName, bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isCompact ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mystical Greeting
          Text(
            'Welcome, $userName',
            style: GoogleFonts.cinzel(
              fontSize: isCompact ? 22 : 26,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'THE PORTAL AWAITS',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary.withOpacity(0.7),
              letterSpacing: 4,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: THE DAILY ORACLE
  // ===========================================================================

  Widget _buildOracleSection(bool isCompact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          _buildSectionTitle(
            'THE ORACLE',
            Icons.visibility_rounded,
            AppColors.primary,
          ),

          const SizedBox(height: 16),

          // Oracle Card - Large prominent card with breathing animation
          _DailyOracleCard(
            breatheController: _breatheController,
            glowController: _glowController,
            isCompact: isCompact,
            onTap: () => _navigateToSingleCardReading(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: SACRED SPREADS
  // ===========================================================================

  Widget _buildSpreadsSection(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionTitle(
            'SACRED SPREADS',
            Icons.auto_awesome_mosaic_rounded,
            AppColors.secondary,
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Choose Your Ritual',
            style: GoogleFonts.cinzel(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Horizontal ListView of ALL 6 Spread Cards
        SizedBox(
          height: isCompact ? 185 : 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: allSpreadDefinitions.length,
            itemBuilder: (context, index) {
              final spread = allSpreadDefinitions[index];
              return _SpreadCard(
                spread: spread,
                onTap: () => _navigateToSpread(spread),
                animationDelay: index * 80, // Staggered animation
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            letterSpacing: 3,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // NAVIGATION METHODS
  // ===========================================================================

  void _navigateToSingleCardReading() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const TarotSelectionScreen(
            isTabMode: false,
            skipCharging: false,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToSpread(SpreadDefinition spread) {
    HapticFeedback.mediumImpact();

    // Navigate to card selection screen for all spreads
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return TarotCardSelectionScreen(spread: spread);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showComingSoonSnackbar(String spreadName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('$spreadName spread coming soon!')),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// =============================================================================
// THE DAILY ORACLE CARD (Top Section)
// =============================================================================

class _DailyOracleCard extends StatelessWidget {
  final AnimationController breatheController;
  final AnimationController glowController;
  final bool isCompact;
  final VoidCallback onTap;

  const _DailyOracleCard({
    required this.breatheController,
    required this.glowController,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([breatheController, glowController]),
      builder: (context, child) {
        final breatheValue = breatheController.value;
        final glowValue = glowController.value;

        // Breathing scale effect
        final scale = 1.0 + (breatheValue * 0.02);

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: isCompact ? 180 : 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2 + glowValue * 0.15),
                    blurRadius: 30 + glowValue * 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.1 + glowValue * 0.1),
                    blurRadius: 40,
                    spreadRadius: -5,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.secondary.withOpacity(0.1),
                          AppColors.backgroundSecondary.withOpacity(0.85),
                        ],
                      ),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3 + glowValue * 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background Mystic Pattern
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MysticPatternPainter(
                              color: AppColors.primary.withOpacity(0.05),
                            ),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              // Left side - Text Content
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Ask the Oracle',
                                      style: GoogleFonts.cinzel(
                                        fontSize: isCompact ? 22 : 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Daily Guidance',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Draw a single card for\nimmediate cosmic insight',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // CTA Button
                                    _buildCtaButton(),
                                  ],
                                ),
                              ),

                              // Right side - Breathing Tarot Card
                              Expanded(
                                flex: 2,
                                child: _BreathingTarotCard(
                                  glowValue: glowValue,
                                  breatheValue: breatheValue,
                                  isCompact: isCompact,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCtaButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.3),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Begin Reading',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BREATHING TAROT CARD (Visual in Oracle Section)
// =============================================================================

class _BreathingTarotCard extends StatelessWidget {
  final double glowValue;
  final double breatheValue;
  final bool isCompact;

  const _BreathingTarotCard({
    required this.glowValue,
    required this.breatheValue,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = isCompact ? 115.0 : 135.0;
    final cardWidth = cardHeight * 0.62;

    // Subtle floating effect
    final floatOffset = sin(breatheValue * pi) * 4;

    return Transform.translate(
      offset: Offset(0, floatOffset),
      child: Center(
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withOpacity(0.5),
                AppColors.secondary.withOpacity(0.4),
                AppColors.backgroundPurple,
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.7),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35 + glowValue * 0.25),
                blurRadius: 25 + glowValue * 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Card Back Pattern - Mystical Eye
              Center(
                child: Icon(
                  Icons.remove_red_eye_outlined,
                  size: isCompact ? 34 : 42,
                  color: AppColors.primary.withOpacity(0.85),
                ),
              ),
              // Corner Stars
              ..._buildCornerStars(),
              // Center glow ring
              Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCornerStars() {
    const size = 8.0;
    final color = AppColors.primary.withOpacity(0.6);
    return [
      Positioned(top: 6, left: 6, child: Icon(Icons.star, size: size, color: color)),
      Positioned(top: 6, right: 6, child: Icon(Icons.star, size: size, color: color)),
      Positioned(bottom: 6, left: 6, child: Icon(Icons.star, size: size, color: color)),
      Positioned(bottom: 6, right: 6, child: Icon(Icons.star, size: size, color: color)),
    ];
  }
}

// =============================================================================
// SPREAD CARD (Horizontal List Item)
// =============================================================================

class _SpreadCard extends StatelessWidget {
  final SpreadDefinition spread;
  final VoidCallback onTap;
  final int animationDelay;

  const _SpreadCard({
    required this.spread,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 145,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: spread.gradientColors.first.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Glassmorphism: White with low opacity + gradient
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      spread.gradientColors.first.withOpacity(0.12),
                      spread.gradientColors.last.withOpacity(0.08),
                      AppColors.backgroundSecondary.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                  border: Border.all(
                    color: spread.gradientColors.first.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Gradient Icon Circle
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: spread.gradientColors,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: spread.gradientColors.first.withOpacity(0.45),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              spread.icon,
                              size: 22,
                              color: Colors.white,
                            ),
                          ),

                          const Spacer(),

                          // Title
                          Text(
                            spread.title,
                            style: GoogleFonts.cinzel(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Subtitle
                          Text(
                            spread.subtitle,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Card count indicator
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.style_outlined,
                                size: 10,
                                color: spread.gradientColors.first.withOpacity(0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${spread.cardCount} cards',
                                style: AppTypography.labelSmall.copyWith(
                                  color: spread.gradientColors.first.withOpacity(0.8),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Premium Badge
                    if (spread.isPremium)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFD700),
                                Color(0xFFFF8C00),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Text(
                            'PREMIUM',
                            style: AppTypography.labelSmall.copyWith(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
      delay: Duration(milliseconds: animationDelay + 400),
      duration: 400.ms,
    )
        .slideX(
      begin: 0.25,
      end: 0,
      delay: Duration(milliseconds: animationDelay + 400),
      duration: 400.ms,
      curve: Curves.easeOutCubic,
    );
  }
}

// =============================================================================
// STAR PARTICLES BACKGROUND
// =============================================================================

class _StarParticles extends StatelessWidget {
  final AnimationController controller;

  const _StarParticles({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _StarParticlesPainter(progress: controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _StarParticlesPainter extends CustomPainter {
  final double progress;
  final Random _random = Random(42); // Fixed seed for consistent stars

  _StarParticlesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw 60 subtle twinkling stars
    for (int i = 0; i < 60; i++) {
      final x = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height;
      final y = (baseY + progress * size.height * 0.08 * (i % 4 + 1)) % size.height;

      final starSize = _random.nextDouble() * 1.8 + 0.4;
      final twinklePhase = (progress * 2 * pi) + (i * 0.5);
      final opacity = (_random.nextDouble() * 0.35 + 0.1) *
          (0.5 + 0.5 * sin(twinklePhase));

      paint.color = AppColors.starWhite.withOpacity(opacity.clamp(0.0, 0.45));
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// =============================================================================
// MYSTIC PATTERN PAINTER
// =============================================================================

class _MysticPatternPainter extends CustomPainter {
  final Color color;

  _MysticPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Radiating lines
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4);
      final endX = centerX + cos(angle) * size.width;
      final endY = centerY + sin(angle) * size.height;
      canvas.drawLine(Offset(centerX, centerY), Offset(endX, endY), paint);
    }

    // Concentric circles
    canvas.drawCircle(Offset(centerX, centerY), 25, paint);
    canvas.drawCircle(Offset(centerX, centerY), 50, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// SPREAD FULL SCREEN WRAPPER
// =============================================================================

class _SpreadFullScreen extends StatelessWidget {
  final SpreadDefinition spread;

  const _SpreadFullScreen({required this.spread});

  @override
  Widget build(BuildContext context) {
    // For now, only Love Match has a dedicated screen
    if (spread.id == 'love') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: MysticBackgroundScaffold(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              spread.gradientColors.first.withOpacity(0.3),
                              spread.gradientColors.last.withOpacity(0.2),
                            ],
                          ),
                        ),
                        child: Icon(
                          spread.icon,
                          color: spread.gradientColors.first,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spread.title.toUpperCase(),
                              style: AppTypography.labelMedium.copyWith(
                                color: spread.gradientColors.first,
                                letterSpacing: 3,
                              ),
                            ),
                            Text(
                              spread.subtitle,
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
                // Content
                const Expanded(child: LoveMatchScreen()),
              ],
            ),
          ),
        ),
      );
    }

    // Placeholder for other spreads
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(spread.title),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Text('${spread.title} coming soon!'),
      ),
    );
  }
}