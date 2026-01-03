import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/constants.dart';

/// A mystical progress bar with star nodes for onboarding steps.
/// Each step is represented by a star that lights up when completed.
class MysticProgressBar extends StatelessWidget {
  /// Total number of steps
  final int totalSteps;

  /// Current step (0-indexed)
  final int currentStep;

  /// Labels for each step (optional)
  final List<String>? stepLabels;

  const MysticProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background line
              Positioned(
                left: 40,
                right: 40,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),

              // Progress line
              Positioned(
                left: 40,
                right: 40,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final progress = currentStep / (totalSteps - 1);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        height: 2,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.mysticTeal,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Star nodes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalSteps, (index) {
                  final isCompleted = index < currentStep;
                  final isCurrent = index == currentStep;
                  return _StarNode(
                    isCompleted: isCompleted,
                    isCurrent: isCurrent,
                    index: index,
                  );
                }),
              ),
            ],
          ),
        ),

        // Step labels
        if (stepLabels != null && stepLabels!.length == totalSteps) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;
              return Expanded(
                child: Text(
                  stepLabels![index],
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: isCurrent
                        ? AppColors.primary
                        : isCompleted
                            ? AppColors.textSecondary
                            : AppColors.textTertiary,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// A star node for the progress bar.
class _StarNode extends StatelessWidget {
  final bool isCompleted;
  final bool isCurrent;
  final int index;

  const _StarNode({
    required this.isCompleted,
    required this.isCurrent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 32.0 : 24.0;
    final iconSize = isCurrent ? 18.0 : 14.0;

    Widget node = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted || isCurrent
            ? AppColors.primary.withOpacity(0.2)
            : AppColors.surface,
        border: Border.all(
          color: isCompleted || isCurrent
              ? AppColors.primary
              : AppColors.glassBorder,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : isCompleted
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
      ),
      child: Center(
        child: Icon(
          isCompleted
              ? Icons.check_rounded
              : isCurrent
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
          size: iconSize,
          color: isCompleted || isCurrent
              ? AppColors.primary
              : AppColors.textTertiary,
        ),
      ),
    );

    // Add pulse animation for current step
    if (isCurrent) {
      node = node
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.1, 1.1),
            duration: 1500.ms,
            curve: Curves.easeInOut,
          );
    }

    // Add entrance animation
    return node
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: index * 100),
          duration: 400.ms,
        )
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          delay: Duration(milliseconds: index * 100),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }
}
