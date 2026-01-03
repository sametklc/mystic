import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/services/services.dart';
import '../../../../shared/widgets/widgets.dart';

/// The final onboarding screen - Cosmic Signature Reveal.
/// Shows the zodiac wheel animation and reveals the user's astrological profile.
class OnboardingRevealScreen extends ConsumerStatefulWidget {
  /// Callback when the user completes onboarding
  final VoidCallback? onComplete;

  const OnboardingRevealScreen({
    super.key,
    this.onComplete,
  });

  @override
  ConsumerState<OnboardingRevealScreen> createState() =>
      _OnboardingRevealScreenState();
}

class _OnboardingRevealScreenState extends ConsumerState<OnboardingRevealScreen>
    with SingleTickerProviderStateMixin {
  bool _showWheel = false;
  bool _showResult = false;
  bool _showCards = false;
  bool _isExiting = false;
  AstrologyProfileModel? _profile;

  // Glow animation for wheel after spin
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Setup glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _startReveal();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _startReveal() async {
    // Short delay before showing wheel
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _showWheel = true);

    // Calculate profile from saved birth data
    final user = ref.read(userProvider);
    if (user.birthDate != null && user.birthLatitude != null) {
      // Parse the date
      final dateParts = user.birthDate!.split('-');
      final birthDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );

      // Parse time if available
      DateTime? birthTime;
      if (user.birthTime != null) {
        final timeParts = user.birthTime!.split(':');
        birthTime = DateTime(
          birthDate.year,
          birthDate.month,
          birthDate.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      }

      final birthData = BirthDataModel(
        birthDate: birthDate,
        birthTime: birthTime,
        birthLocation: user.birthCity,
      );

      _profile = await AstrologyService.calculateProfile(birthData);
    }
  }

  void _onSpinComplete() {
    HapticFeedback.heavyImpact();

    // Start the glow pulse animation
    _glowController.repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showResult = true);

      // Staggered card appearance
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() => _showCards = true);
      });
    });
  }

  Future<void> _onEnterApp() async {
    HapticFeedback.mediumImpact();
    setState(() => _isExiting = true);

    await Future.delayed(const Duration(milliseconds: 600));

    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userProvider).name ?? 'Seeker';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive wheel size - dominates the screen
    final wheelSize = screenWidth * 0.75;

    return Scaffold(
      body: MysticBackgroundScaffold(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppConstants.spacingMedium),

              // ===== TITLE AREA =====
              _buildTitleSection(userName),

              // ===== SPACER (flex: 2) =====
              const Spacer(flex: 2),

              // ===== HERO: ZODIAC WHEEL =====
              _buildZodiacWheel(wheelSize),

              // ===== SPACER (flex: 1) =====
              const Spacer(flex: 1),

              // ===== THE REVELATION: SUN & RISING CARDS =====
              if (_showCards) _buildCelestialPillars(screenWidth),

              // ===== SPACER (flex: 2) =====
              if (_showCards) const Spacer(flex: 2),
              if (!_showCards) const Spacer(flex: 3),

              // ===== ACTION: ENTER BUTTON =====
              if (_showResult) _buildEnterButton(),

              const SizedBox(height: AppConstants.spacingLarge),
            ],
          ),
        ),
      ),
    );
  }

  /// Title section that fades when result appears
  Widget _buildTitleSection(String userName) {
    if (!_showWheel) return const SizedBox(height: 60);

    if (_showResult) {
      // Show personalized welcome when result is ready
      return Column(
        children: [
          Text(
            'Welcome, $userName',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Cosmic Signature',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              letterSpacing: 2,
            ),
          ),
        ],
      )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideY(begin: -0.2, end: 0, duration: 600.ms);
    }

    // Initial revealing message
    Widget title = Text(
      'Revealing your cosmic signature...',
      textAlign: TextAlign.center,
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    ).animate().fadeIn(duration: 600.ms);

    if (_isExiting) {
      title = title.animate().fadeOut(duration: 400.ms);
    }

    return title;
  }

  /// The Hero Element - Large Zodiac Wheel
  Widget _buildZodiacWheel(double size) {
    if (!_showWheel) return SizedBox(height: size, width: size);

    Widget wheel = AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: _showResult
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(_glowAnimation.value),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: AppColors.mysticTeal.withOpacity(_glowAnimation.value * 0.5),
                      blurRadius: 60,
                      spreadRadius: 5,
                    ),
                  ],
                )
              : null,
          child: ZodiacWheel(
            size: size,
            isSpinning: !_showResult,
            spinDuration: const Duration(seconds: 4),
            highlightedSign: _profile?.sunSign,
            enableHaptics: true,
            onSpinComplete: _onSpinComplete,
          ),
        );
      },
    );

    wheel = wheel
        .animate()
        .fadeIn(duration: 800.ms)
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 800.ms,
          curve: Curves.easeOutBack,
        );

    if (_isExiting) {
      wheel = wheel.animate().fadeOut(duration: 500.ms).scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(0.8, 0.8),
            duration: 500.ms,
          );
    }

    return wheel;
  }

  /// The Celestial Pillars - Sun & Rising Cards
  Widget _buildCelestialPillars(double screenWidth) {
    if (_profile == null) return const SizedBox.shrink();

    Widget pillars = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLarge),
      child: Row(
        children: [
          // ===== LEFT CARD: SUN SIGN (The Core) =====
          Expanded(
            child: _CelestialCard(
              title: 'SUN SIGN',
              subtitle: 'Your Core Identity',
              signName: _profile!.sunSign.englishName,
              signSymbol: _profile!.sunSign.symbol,
              primaryColor: const Color(0xFFFFD700), // Gold
              secondaryColor: const Color(0xFFFF8C00), // Dark Orange
              iconData: Icons.wb_sunny_rounded,
            ),
          ),

          const SizedBox(width: 16),

          // ===== RIGHT CARD: RISING SIGN (The Mask) =====
          Expanded(
            child: _CelestialCard(
              title: 'RISING SIGN',
              subtitle: 'Your First Impression',
              signName: _profile!.ascendantSign.englishName,
              signSymbol: _profile!.ascendantSign.symbol,
              primaryColor: const Color(0xFFB0C4DE), // Silver/Light Steel Blue
              secondaryColor: const Color(0xFF20B2AA), // Teal
              iconData: Icons.north_east_rounded,
            ),
          ),
        ],
      ),
    );

    pillars = pillars
        .animate()
        .fadeIn(duration: 700.ms)
        .slideY(begin: 0.3, end: 0, duration: 700.ms, curve: Curves.easeOutCubic);

    if (_isExiting) {
      pillars = pillars.animate().fadeOut(duration: 400.ms).slideY(
            begin: 0,
            end: 0.2,
            duration: 400.ms,
          );
    }

    return pillars;
  }

  Widget _buildEnterButton() {
    Widget button = GestureDetector(
      onTap: _onEnterApp,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLarge),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXLarge,
          vertical: AppConstants.spacingMedium,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.mysticTeal,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AppConstants.spacingSmall),
            Text(
              'Enter the Mystic Realm',
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    button = button
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms)
        .slideY(begin: 0.3, end: 0, delay: 500.ms, duration: 600.ms);

    if (_isExiting) {
      button = button.animate().fadeOut(duration: 300.ms);
    }

    return button;
  }
}

/// A Celestial Pillar Card - Glassmorphic design with colored glow
class _CelestialCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String signName;
  final String signSymbol;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData iconData;

  const _CelestialCard({
    required this.title,
    required this.subtitle,
    required this.signName,
    required this.signSymbol,
    required this.primaryColor,
    required this.secondaryColor,
    required this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.15),
                secondaryColor.withOpacity(0.08),
              ],
            ),
            border: Border.all(
              width: 2,
              color: primaryColor.withOpacity(0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Label
              Text(
                title,
                style: AppTypography.labelSmall.copyWith(
                  color: primaryColor,
                  letterSpacing: 2,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              // Large Zodiac Symbol
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withOpacity(0.3),
                      secondaryColor.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    signSymbol,
                    style: TextStyle(
                      fontSize: 28,
                      color: primaryColor,
                      shadows: [
                        Shadow(
                          color: primaryColor.withOpacity(0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Sign Name
              Text(
                signName,
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
