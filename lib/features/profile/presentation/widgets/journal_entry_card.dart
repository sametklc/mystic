import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../paywall/paywall.dart';
import '../../../tarot/data/tarot_deck_assets.dart';
import '../../domain/models/grimoire_entry_model.dart';

/// A card displaying a journal entry in the Grimoire.
/// Shows lock overlay for non-premium users.
class JournalEntryCard extends ConsumerWidget {
  final GrimoireEntryModel entry;
  final VoidCallback? onTap;
  final int index;

  const JournalEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPremium) {
          onTap?.call();
        } else {
          // Navigate to paywall
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaywallView(
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundTertiary,
              AppColors.backgroundSecondary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Corner decoration
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Content - Blurred if not premium
              ImageFiltered(
                imageFilter: isPremium
                    ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                    : ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail or icon
                      _buildThumbnail(),

                      const SizedBox(width: 14),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date and moon phase
                            Row(
                              children: [
                                Text(
                                  entry.formattedDate,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textTertiary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (entry.moonPhase != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.nightlight_round,
                                    size: 12,
                                    color: AppColors.secondary.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.moonPhase!,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.secondary.withValues(alpha: 0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Question
                            Text(
                              entry.questionPreview,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 10),

                            // Card name
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                    ),
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 12,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        entry.cardName,
                                        style: GoogleFonts.cinzel(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (!entry.isUpright) ...[
                                        const SizedBox(width: 4),
                                        Transform.rotate(
                                          angle: 3.14159,
                                          child: Icon(
                                            Icons.arrow_upward,
                                            size: 10,
                                            color: AppColors.primary.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Lock overlay for non-premium users
              if (!isPremium) _buildLockOverlay(),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .slideX(begin: 0.05, end: 0, duration: 400.ms);
  }

  Widget _buildLockOverlay() {
    const goldAccent = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: 0.4),
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Lock icon with glow
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1025),
                border: Border.all(
                  color: goldAccent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: goldAccent.withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [goldAccent, goldDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    // Get local asset path for fallback
    final assetPath = TarotDeckAssets.getCardByName(entry.cardName);

    return Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: _buildThumbnailImage(assetPath),
      ),
    );
  }

  Widget _buildThumbnailImage(String assetPath) {
    // Priority 1: Network image (AI-generated)
    if (entry.hasImage) {
      return Image.network(
        entry.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: AppColors.backgroundSecondary,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local asset
          return _buildAssetThumbnail(assetPath);
        },
      );
    }

    // Priority 2: Local asset image (standard deck)
    return _buildAssetThumbnail(assetPath);
  }

  Widget _buildAssetThumbnail(String assetPath) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholderThumbnail();
      },
    );
  }

  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTertiary,
            AppColors.backgroundSecondary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          size: 24,
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
