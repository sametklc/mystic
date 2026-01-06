import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';

/// Legal URLs
const String _termsOfUseUrl = 'https://www.notion.so/Terms-of-Use-2df077c6b38c80e2a37edcd22431a6c1';
const String _privacyPolicyUrl = 'https://www.notion.so/Privacy-Policy-2de077c6b38c807e9908f36948afca8d';

/// --------------------------------------------------------------------------
/// PREMIUM PAYWALL SCREEN WITH REVENUECAT INTEGRATION
/// --------------------------------------------------------------------------

class PaywallView extends ConsumerStatefulWidget {
  final VoidCallback? onPurchase;
  final VoidCallback? onRestore;
  final VoidCallback? onClose;

  const PaywallView({
    super.key,
    this.onPurchase,
    this.onRestore,
    this.onClose,
  });

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  Package? _selectedPackage;
  bool _isLoading = false;
  String? _errorMessage;

  // DATA: Feature List
  static const List<_FeatureData> _features = [
    _FeatureData(Icons.star_rounded, 'Natal Chart Analysis'),
    _FeatureData(Icons.style_rounded, 'Tarot Readings'),
    _FeatureData(Icons.favorite_rounded, 'Love Match Reports'),
    _FeatureData(Icons.psychology_rounded, 'AI Astrologer Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(packagesProvider);

    return MysticBackgroundScaffold(
      gradientColors: const [
        Color(0xFF1A0A2E),
        Color(0xFF0D0620),
        Color(0xFF050511),
        Color(0xFF0A0515),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final isCompact = screenHeight < 700;
              final horizontalPadding = isCompact ? 20.0 : 24.0;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    // 1. CLOSE BUTTON
                    _buildCloseButton(),

                    const Spacer(flex: 1),

                    // 2. HEADER
                    _buildHeader(isCompact),

                    SizedBox(height: isCompact ? 16 : 24),

                    // 3. COSMIC FEATURES GRID
                    _buildCosmicGrid(isCompact),

                    SizedBox(height: isCompact ? 16 : 24),

                    // 4. PRICING CARDS (from RevenueCat)
                    packagesAsync.when(
                      data: (packages) => _buildPricingSection(packages, isCompact),
                      loading: () => _buildLoadingPricing(),
                      error: (e, _) => _buildErrorPricing(e.toString()),
                    ),

                    const Spacer(flex: 2),

                    // 5. ERROR MESSAGE
                    if (_errorMessage != null) _buildErrorMessage(),

                    // 6. CTA BUTTON
                    PremiumCTAButton(
                      text: 'Start My Premium Journey',
                      onPressed: _selectedPackage != null ? _onPurchaseTapped : null,
                      isLoading: _isLoading,
                    ),

                    SizedBox(height: isCompact ? 10 : 16),

                    // 7. FOOTER
                    _buildFooter(isCompact),

                    SizedBox(height: isCompact ? 6 : 10),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPricing() {
    return const SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
        ),
      ),
    );
  }

  Widget _buildErrorPricing(String error) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load pricing',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.refresh(packagesProvider),
              child: Text(
                'Retry',
                style: AppTypography.labelMedium.copyWith(
                  color: const Color(0xFFFFD700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection(List<Package> packages, bool isCompact) {
    if (packages.isEmpty) {
      return _buildErrorPricing('No packages available');
    }

    // Select first package by default
    _selectedPackage ??= packages.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Choose Your Plan',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: isCompact ? 13 : 14,
            ),
          ),
        ),
        ...packages.map((package) {
          final option = _packageToPricingOption(package);
          return StackPricingCard(
            option: option,
            isSelected: _selectedPackage?.identifier == package.identifier,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPackage = package);
            },
            isCompact: isCompact,
          );
        }),
      ],
    );
  }

  PricingOption _packageToPricingOption(Package package) {
    final product = package.storeProduct;
    final identifier = package.identifier;

    // Determine badge based on package type
    String? badge;
    bool isPopular = false;
    bool isBestValue = false;

    if (identifier.contains('yearly') || identifier.contains('annual')) {
      badge = 'BEST VALUE';
      isBestValue = true;
    } else if (identifier.contains('pro') || identifier.contains('premium')) {
      badge = 'POPULAR';
      isPopular = true;
    }

    return PricingOption(
      id: identifier,
      title: product.title.replaceAll(RegExp(r'\(.*\)'), '').trim(),
      price: product.priceString,
      period: _getPeriodString(package.packageType),
      subtext: product.description,
      badge: badge,
      isPopular: isPopular,
      isBestValue: isBestValue,
    );
  }

  String _getPeriodString(PackageType type) {
    switch (type) {
      case PackageType.weekly:
        return '/week';
      case PackageType.monthly:
        return '/month';
      case PackageType.twoMonth:
        return '/2 months';
      case PackageType.threeMonth:
        return '/3 months';
      case PackageType.sixMonth:
        return '/6 months';
      case PackageType.annual:
        return '/year';
      case PackageType.lifetime:
        return 'lifetime';
      default:
        return '';
    }
  }

  void _onPurchaseTapped() async {
    if (_selectedPackage == null) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = ref.read(revenueCatServiceProvider);
    final result = await service.purchasePackage(_selectedPackage!);

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.success) {
        // Add gem reward to user's balance
        if (result.gemsRewarded > 0) {
          ref.read(userProvider.notifier).addGems(result.gemsRewarded);
        }

        widget.onPurchase?.call();
        Navigator.of(context).pop();

        // Show success message with gems
        final gemMessage = result.gemsRewarded > 0
            ? 'Welcome to Premium! +${result.gemsRewarded} 💎 gems added!'
            : 'Welcome to Premium! Enjoy your cosmic journey.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gemMessage),
            backgroundColor: const Color(0xFF9D00FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage);
      }
    }
  }

  void _onRestoreTapped() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = ref.read(revenueCatServiceProvider);
    final result = await service.restorePurchases();

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.success && result.isPremium) {
        widget.onRestore?.call();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchases restored successfully!'),
            backgroundColor: const Color(0xFF9D00FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else if (result.success) {
        setState(() => _errorMessage = 'No previous purchases found');
      } else {
        setState(() => _errorMessage = result.errorMessage);
      }
    }
  }

  void _onCloseTapped() {
    HapticFeedback.lightImpact();
    widget.onClose?.call();
    Navigator.of(context).maybePop();
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        _errorMessage!,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.error,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildCloseButton() {
    return Align(
      alignment: Alignment.topRight,
      child: GestureDetector(
        onTap: _onCloseTapped,
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Icon(
            Icons.close,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    const goldColor = Color(0xFFFFD700);
    final iconSize = isCompact ? 28.0 : 34.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Icon
        Container(
          padding: EdgeInsets.all(isCompact ? 10 : 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: goldColor.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: goldColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome,
            color: goldColor,
            size: iconSize,
          ),
        ),
        SizedBox(height: isCompact ? 10 : 14),

        // Title
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFE55C), goldColor, Color(0xFFFF8C00)],
            ).createShader(bounds),
            child: Text(
              'Unlock Your Cosmic Destiny',
              textAlign: TextAlign.center,
              style: AppTypography.headlineLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isCompact ? 24 : 28,
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),

        // Subtitle
        Text(
          'Unlimited access to stars & AI insights',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildCosmicGrid(bool isCompact) {
    final spacing = isCompact ? 10.0 : 12.0;
    final double tileHeight = isCompact ? 60.0 : 68.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: tileHeight,
          child: Row(
            children: [
              Expanded(
                child: FeatureTile(
                  icon: _features[0].icon,
                  label: _features[0].label,
                  isCompact: isCompact,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: FeatureTile(
                  icon: _features[1].icon,
                  label: _features[1].label,
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
        SizedBox(
          height: tileHeight,
          child: Row(
            children: [
              Expanded(
                child: FeatureTile(
                  icon: _features[2].icon,
                  label: _features[2].label,
                  isCompact: isCompact,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: FeatureTile(
                  icon: _features[3].icon,
                  label: _features[3].label,
                  isCompact: isCompact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isCompact) {
    final fontSize = isCompact ? 10.0 : 11.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFooterLink('Restore', fontSize, _onRestoreTapped),
        _buildDot(),
        _buildFooterLink('Terms', fontSize, () => _openUrl(_termsOfUseUrl)),
        _buildDot(),
        _buildFooterLink('Privacy', fontSize, () => _openUrl(_privacyPolicyUrl)),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildFooterLink(String text, double fontSize, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: fontSize,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textTertiary,
      ),
    );
  }
}

// --------------------------------------------------------------------------
// HELPER CLASSES & WIDGETS
// --------------------------------------------------------------------------

class _FeatureData {
  final IconData icon;
  final String label;
  const _FeatureData(this.icon, this.label);
}

class PricingOption {
  final String id;
  final String title;
  final String price;
  final String period;
  final String subtext;
  final String? badge;
  final bool isPopular;
  final bool isBestValue;

  const PricingOption({
    required this.id,
    required this.title,
    required this.price,
    required this.period,
    required this.subtext,
    this.badge,
    this.isPopular = false,
    this.isBestValue = false,
  });
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCompact;

  const FeatureTile({
    super.key,
    required this.icon,
    required this.label,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double badgeSize = isCompact ? 36.0 : 44.0;
    final double iconSize = isCompact ? 20.0 : 24.0;
    final double fontSize = isCompact ? 12.0 : 13.0;

    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700),
            Color(0x00000000),
            Color(0xFF9D00FF),
          ],
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF151025).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16.5),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
            SizedBox(width: isCompact ? 10 : 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StackPricingCard extends StatelessWidget {
  final PricingOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;

  const StackPricingCard({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double cardHeight = isCompact ? 56.0 : 64.0;
    final bool hasBadge = option.badge != null;
    const goldColor = Color(0xFFFFD700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        margin: EdgeInsets.only(top: hasBadge ? 12 : 6, bottom: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? goldColor
                      : (hasBadge
                          ? goldColor.withValues(alpha: 0.3)
                          : AppColors.glassBorder),
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? goldColor.withValues(alpha: 0.08)
                    : AppColors.glassFill,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16),
                    child: Row(
                      children: [
                        _buildRadio(isSelected, isCompact, goldColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.title,
                                style: AppTypography.titleSmall.copyWith(
                                  color: isSelected
                                      ? goldColor
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isCompact ? 13 : 15,
                                ),
                              ),
                              Text(
                                option.subtext,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: isCompact ? 10 : 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              option.price,
                              style: AppTypography.titleMedium.copyWith(
                                color: isSelected
                                    ? goldColor
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isCompact ? 15 : 17,
                              ),
                            ),
                            Text(
                              option.period,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: isCompact ? 10 : 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (hasBadge)
              Positioned(
                top: -10,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: option.isBestValue
                          ? const [goldColor, Color(0xFFFF8C00)]
                          : const [Color(0xFF9D00FF), Color(0xFFBB66FF)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    option.badge!,
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(bool isSelected, bool isCompact, Color color) {
    final size = isCompact ? 20.0 : 22.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? color : AppColors.textTertiary,
          width: 2,
        ),
        color: isSelected ? color : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check,
              color: AppColors.textOnPrimary, size: isCompact ? 12 : 14)
          : null,
    );
  }
}

class PremiumCTAButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PremiumCTAButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    const goldColor = Color(0xFFFFD700);
    final isEnabled = onPressed != null && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE55C), goldColor, Color(0xFFFF8C00)],
          ),
          boxShadow: [
            BoxShadow(
              color: goldColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.textOnPrimary),
                      ),
                    )
                  : Text(
                      text,
                      style: AppTypography.button.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
