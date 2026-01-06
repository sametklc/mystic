import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/gem_service.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../../paywall/paywall.dart';

/// Legal URLs
const String _termsOfUseUrl = 'https://www.notion.so/Terms-of-Use-2df077c6b38c80e2a37edcd22431a6c1';
const String _privacyPolicyUrl = 'https://www.notion.so/Privacy-Policy-2de077c6b38c807e9908f36948afca8d';

/// Diamond Shop Screen for purchasing consumable diamond packs
/// Only accessible to premium users
class DiamondShopScreen extends ConsumerStatefulWidget {
  const DiamondShopScreen({super.key});

  @override
  ConsumerState<DiamondShopScreen> createState() => _DiamondShopScreenState();
}

class _DiamondShopScreenState extends ConsumerState<DiamondShopScreen> {
  bool _isLoading = false;
  bool _isRestoring = false;
  String? _errorMessage;
  String? _purchasingProductId;

  // Diamond color scheme
  static const Color _diamondColor = Color(0xFF00D9FF);
  static const Color _diamondGlow = Color(0xFF00A8CC);
  static const Color _goldColor = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final currentGems = ref.watch(gemsProvider);

    // If not premium, show paywall
    if (!isPremium) {
      return PaywallView(
        onClose: () => Navigator.of(context).pop(),
      );
    }

    final diamondPackagesAsync = ref.watch(diamondPackagesProvider);

    return MysticBackgroundScaffold(
      gradientColors: const [
        Color(0xFF0A1628),
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

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 20.0 : 24.0,
                ),
                child: Column(
                  children: [
                    // Close Button
                    _buildCloseButton(),

                    const Spacer(flex: 1),

                    // Header with current balance
                    _buildHeader(currentGems, isCompact),

                    SizedBox(height: isCompact ? 24 : 32),

                    // Diamond Packs
                    diamondPackagesAsync.when(
                      data: (packages) => _buildDiamondPacks(packages, isCompact),
                      loading: () => _buildLoadingPacks(),
                      error: (e, _) => _buildErrorPacks(e.toString()),
                    ),

                    const Spacer(flex: 2),

                    // Error Message
                    if (_errorMessage != null) _buildErrorMessage(),

                    // Info text
                    _buildInfoText(isCompact),

                    SizedBox(height: isCompact ? 12 : 16),

                    // Footer with Restore, Terms, Privacy
                    _buildFooter(isCompact),

                    SizedBox(height: isCompact ? 16 : 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Align(
      alignment: Alignment.topRight,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
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

  Widget _buildHeader(int currentGems, bool isCompact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Diamond Icon with glow
        Container(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _diamondColor.withOpacity(0.3),
                _diamondGlow.withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: _diamondColor.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _diamondColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Text(
            '💎',
            style: TextStyle(fontSize: isCompact ? 32 : 40),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              _diamondColor,
              Colors.white,
              _diamondColor,
            ],
          ).createShader(bounds),
          child: Text(
            'Diamond Shop',
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 26 : 30,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 8 : 12),

        // Current balance
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _diamondColor.withOpacity(0.1),
            border: Border.all(
              color: _diamondColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Current Balance: $currentGems',
                style: AppTypography.titleSmall.copyWith(
                  color: _diamondColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPacks() {
    return const SizedBox(
      height: 300,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_diamondColor),
        ),
      ),
    );
  }

  Widget _buildErrorPacks(String error) {
    return SizedBox(
      height: 300,
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
              'Unable to load diamond packs',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.refresh(diamondPackagesProvider),
              child: Text(
                'Retry',
                style: AppTypography.labelMedium.copyWith(
                  color: _diamondColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiamondPacks(List<Package> packages, bool isCompact) {
    // If no packages from RevenueCat, show static options
    if (packages.isEmpty) {
      return _buildStaticPacks(isCompact);
    }

    return Column(
      children: packages.map((package) {
        final diamondAmount = GemConfig.getDiamondAmountForProduct(
          package.storeProduct.identifier,
        );
        return _buildDiamondPackCard(
          package: package,
          diamondAmount: diamondAmount ?? 0,
          price: package.storeProduct.priceString,
          isCompact: isCompact,
        );
      }).toList(),
    );
  }

  Widget _buildStaticPacks(bool isCompact) {
    // Fallback static packs when RevenueCat offerings are not available
    return Column(
      children: [
        _buildStaticPackCard(
          diamondAmount: GemConfig.diamondPack100Amount,
          price: '\$${GemConfig.diamondPack100Price.toStringAsFixed(2)}',
          productId: GemConfig.diamondPack100Id,
          isCompact: isCompact,
        ),
        _buildStaticPackCard(
          diamondAmount: GemConfig.diamondPack500Amount,
          price: '\$${GemConfig.diamondPack500Price.toStringAsFixed(2)}',
          productId: GemConfig.diamondPack500Id,
          badge: 'POPULAR',
          isCompact: isCompact,
        ),
        _buildStaticPackCard(
          diamondAmount: GemConfig.diamondPack1000Amount,
          price: '\$${GemConfig.diamondPack1000Price.toStringAsFixed(2)}',
          productId: GemConfig.diamondPack1000Id,
          badge: 'BEST VALUE',
          isBestValue: true,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildStaticPackCard({
    required int diamondAmount,
    required String price,
    required String productId,
    String? badge,
    bool isBestValue = false,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: () => _showUnavailableMessage(),
      child: _buildPackCardContent(
        diamondAmount: diamondAmount,
        price: price,
        badge: badge,
        isBestValue: isBestValue,
        isCompact: isCompact,
        isLoading: false,
      ),
    );
  }

  Widget _buildDiamondPackCard({
    required Package package,
    required int diamondAmount,
    required String price,
    required bool isCompact,
  }) {
    final productId = package.storeProduct.identifier;
    final isThisLoading = _isLoading && _purchasingProductId == productId;

    // Determine badge based on amount
    String? badge;
    bool isBestValue = false;
    if (diamondAmount >= 1000) {
      badge = 'BEST VALUE';
      isBestValue = true;
    } else if (diamondAmount >= 500) {
      badge = 'POPULAR';
    }

    return GestureDetector(
      onTap: isThisLoading ? null : () => _onPurchaseTapped(package),
      child: _buildPackCardContent(
        diamondAmount: diamondAmount,
        price: price,
        badge: badge,
        isBestValue: isBestValue,
        isCompact: isCompact,
        isLoading: isThisLoading,
      ),
    );
  }

  Widget _buildPackCardContent({
    required int diamondAmount,
    required String price,
    String? badge,
    bool isBestValue = false,
    required bool isCompact,
    required bool isLoading,
  }) {
    final cardHeight = isCompact ? 72.0 : 80.0;
    final hasBadge = badge != null;

    return Container(
      height: cardHeight,
      margin: EdgeInsets.only(top: hasBadge ? 14 : 8, bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card background
          Container(
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isBestValue
                    ? _goldColor.withOpacity(0.5)
                    : _diamondColor.withOpacity(0.3),
                width: isBestValue ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (isBestValue ? _goldColor : _diamondColor).withOpacity(0.1),
                  AppColors.glassFill,
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16 : 20,
                  ),
                  child: Row(
                    children: [
                      // Diamond icon
                      Container(
                        width: isCompact ? 44 : 52,
                        height: isCompact ? 44 : 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isBestValue
                                ? [_goldColor, const Color(0xFFFF8C00)]
                                : [_diamondColor, _diamondGlow],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isBestValue ? _goldColor : _diamondColor)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '💎',
                            style: TextStyle(fontSize: isCompact ? 20 : 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Diamond amount
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$diamondAmount Diamonds',
                              style: AppTypography.titleMedium.copyWith(
                                color: isBestValue
                                    ? _goldColor
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isCompact ? 16 : 18,
                              ),
                            ),
                            Text(
                              _getValueText(diamondAmount),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: isCompact ? 11 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price button
                      isLoading
                          ? SizedBox(
                              width: isCompact ? 70 : 80,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _diamondColor,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 14 : 18,
                                vertical: isCompact ? 8 : 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: isBestValue
                                      ? [_goldColor, const Color(0xFFFF8C00)]
                                      : [_diamondColor, _diamondGlow],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isBestValue ? _goldColor : _diamondColor)
                                            .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                price,
                                style: AppTypography.labelMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 13 : 14,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Badge
          if (hasBadge)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isBestValue
                        ? [_goldColor, const Color(0xFFFF8C00)]
                        : [const Color(0xFF9D00FF), const Color(0xFFBB66FF)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badge,
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
    );
  }

  String _getValueText(int amount) {
    if (amount >= 1000) {
      return 'Best value - Save 30%';
    } else if (amount >= 500) {
      return 'Great value - Save 20%';
    }
    return 'Starter pack';
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.error.withOpacity(0.1),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(
              Icons.close,
              color: AppColors.error,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(bool isCompact) {
    return Text(
      'Diamonds are used to access premium features like AI readings and compatibility reports.',
      textAlign: TextAlign.center,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textTertiary,
        fontSize: isCompact ? 11 : 12,
      ),
    );
  }

  Widget _buildFooter(bool isCompact) {
    final fontSize = isCompact ? 10.0 : 11.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildFooterLink(
          _isRestoring ? 'Restoring...' : 'Restore',
          fontSize,
          _isRestoring ? null : _onRestoreTapped,
        ),
        _buildDot(),
        _buildFooterLink('Terms', fontSize, () => _openUrl(_termsOfUseUrl)),
        _buildDot(),
        _buildFooterLink('Privacy', fontSize, () => _openUrl(_privacyPolicyUrl)),
      ],
    );
  }

  Widget _buildFooterLink(String text, double fontSize, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: AppTypography.labelSmall.copyWith(
            color: onTap == null
                ? AppColors.textTertiary.withOpacity(0.5)
                : AppColors.textTertiary,
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

  Future<void> _onRestoreTapped() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    final service = ref.read(revenueCatServiceProvider);
    final result = await service.restorePurchases();

    if (mounted) {
      setState(() => _isRestoring = false);

      if (result.success && result.isPremium) {
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
        setState(() => _errorMessage = result.errorMessage ?? 'Failed to restore');
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showUnavailableMessage() {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = 'Diamond packs are not available yet. Please try again later.';
    });
  }

  Future<void> _onPurchaseTapped(Package package) async {
    HapticFeedback.mediumImpact();

    final productId = package.storeProduct.identifier;

    setState(() {
      _isLoading = true;
      _purchasingProductId = productId;
      _errorMessage = null;
    });

    final service = ref.read(revenueCatServiceProvider);
    final result = await service.purchaseConsumable(package);

    // CRITICAL: Add diamonds REGARDLESS of mounted state!
    // Purchase was successful, user paid money - they MUST get their diamonds
    if (result.success && result.diamondsAwarded > 0) {
      ref.read(userProvider.notifier).addGems(result.diamondsAwarded);
      debugPrint('💎 Added ${result.diamondsAwarded} diamonds to user balance');
    }

    // UI updates only if still mounted
    if (mounted) {
      setState(() {
        _isLoading = false;
        _purchasingProductId = null;
      });

      if (result.success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('+${result.diamondsAwarded} diamonds added!'),
              ],
            ),
            backgroundColor: _diamondGlow,
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
}
