import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/user_provider.dart';
import '../models/ai_persona.dart';

/// A list tile widget for displaying an AI persona in the iOS chat home.
/// Styled similar to WhatsApp/iMessage conversation tiles.
class AIPersonaTile extends ConsumerWidget {
  final AIPersona persona;
  final VoidCallback onTap;

  const AIPersonaTile({
    super.key,
    required this.persona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final isLocked = persona.isPremium && !isPremium;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLocked
                    ? AppColors.glassBorder
                    : persona.themeColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(isLocked),

                const SizedBox(width: AppConstants.spacingMedium),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            persona.name,
                            style: AppTypography.titleMedium.copyWith(
                              color: isLocked
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLocked) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        persona.subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: isLocked
                              ? AppColors.textTertiary
                              : persona.themeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        persona.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppConstants.spacingSmall),

                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  color: isLocked
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isLocked) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isLocked
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  persona.themeColor.withValues(alpha: 0.8),
                  persona.themeColor.withValues(alpha: 0.4),
                ],
              ),
        color: isLocked ? AppColors.surface : null,
        border: Border.all(
          color: isLocked
              ? AppColors.glassBorder
              : persona.themeColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: isLocked
            ? null
            : [
                BoxShadow(
                  color: persona.themeColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ClipOval(
        child: ColorFiltered(
          colorFilter: isLocked
              ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
          child: Image.asset(
            persona.imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  persona.name[0],
                  style: AppTypography.headlineSmall.copyWith(
                    color: isLocked ? AppColors.textTertiary : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
