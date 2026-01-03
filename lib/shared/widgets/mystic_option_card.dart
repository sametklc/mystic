import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// A reusable, standardized option card for onboarding and selection screens.
///
/// Features:
/// - Uniform height (70px by default)
/// - Consistent padding and typography
/// - Animated selection states
/// - Optional icon, title, and description
/// - Handles long text gracefully with FittedBox/ellipsis
class MysticOptionCard extends StatelessWidget {
  /// Primary text displayed on the card
  final String title;

  /// Optional description text below the title
  final String? description;

  /// Optional icon to display on the left
  final IconData? icon;

  /// Whether this card is currently selected
  final bool isSelected;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Theme color for the card (used when selected)
  final Color? color;

  /// Fixed height of the card (default: 70)
  final double height;

  /// Animation delay for staggered animations
  final Duration animationDelay;

  /// Whether to show a checkmark when selected
  final bool showCheckmark;

  const MysticOptionCard({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.color,
    this.height = 70,
    this.animationDelay = Duration.zero,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected ? themeColor.withOpacity(0.12) : AppColors.glassFill,
          border: Border.all(
            color: isSelected ? themeColor.withOpacity(0.6) : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Optional icon
            if (icon != null) ...[
              _buildIconContainer(themeColor),
              const SizedBox(width: 14),
            ],

            // Text content (title + optional description)
            Expanded(
              child: _buildTextContent(themeColor),
            ),

            // Selection indicator
            if (showCheckmark && isSelected) ...[
              const SizedBox(width: 12),
              _buildCheckmark(themeColor),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay, duration: 400.ms)
        .slideX(
          begin: 0.08,
          end: 0,
          delay: animationDelay,
          duration: 400.ms,
          curve: Curves.easeOutCubic,
        );
  }

  Widget _buildIconContainer(Color themeColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? themeColor.withOpacity(0.2)
            : AppColors.backgroundSecondary.withOpacity(0.5),
        border: Border.all(
          color: isSelected
              ? themeColor.withOpacity(0.4)
              : AppColors.glassBorder.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: isSelected ? themeColor : AppColors.textSecondary,
        size: 22,
      ),
    );
  }

  Widget _buildTextContent(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with FittedBox for long text
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: isSelected ? themeColor : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 15,
            ),
            maxLines: 1,
          ),
        ),

        // Optional description
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: AppTypography.bodySmall.copyWith(
              color: isSelected
                  ? themeColor.withOpacity(0.85)
                  : AppColors.textTertiary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildCheckmark(Color themeColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: themeColor.withOpacity(0.15),
        border: Border.all(
          color: themeColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.check_rounded,
        color: themeColor,
        size: 14,
      ),
    )
        .animate(target: isSelected ? 1 : 0)
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// A compact variant of MysticOptionCard for smaller selections
class MysticOptionCardCompact extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? color;
  final Duration animationDelay;

  const MysticOptionCardCompact({
    super.key,
    required this.title,
    this.isSelected = false,
    this.onTap,
    this.color,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? themeColor.withOpacity(0.12) : AppColors.glassFill,
          border: Border.all(
            color: isSelected ? themeColor.withOpacity(0.6) : AppColors.glassBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: isSelected ? themeColor : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: animationDelay, duration: 350.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          delay: animationDelay,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
