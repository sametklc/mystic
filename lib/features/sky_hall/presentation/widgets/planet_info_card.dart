import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import '../../domain/models/natal_chart_model.dart';
import 'natal_chart_painter.dart';

/// Card displaying information about a planet position.
class PlanetInfoCard extends StatelessWidget {
  final PlanetPosition planet;
  final bool isExpanded;
  final VoidCallback? onTap;

  const PlanetInfoCard({
    super.key,
    required this.planet,
    this.isExpanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final elementColor = ZodiacColors.forElement(planet.element);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  elementColor.withOpacity(0.15),
                  AppColors.glassFill,
                ],
              ),
              border: Border.all(
                color: elementColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Planet symbol with glow
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: elementColor.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: elementColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          planet.planetSymbol,
                          style: TextStyle(
                            fontSize: 22,
                            color: elementColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppConstants.spacingSmall),

                    // Planet name and sign
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                planet.planetName,
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (planet.isRetrograde) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'R',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                planet.signSymbol,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: elementColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${planet.sign} ${planet.signDegree.toStringAsFixed(1)}°',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // House indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.glassBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${planet.house}',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'House',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Expanded content
                if (isExpanded && planet.interpretation != null) ...[
                  const SizedBox(height: AppConstants.spacingMedium),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingSmall),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    child: Text(
                      planet.interpretation!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSmall),
                  Row(
                    children: [
                      _buildChip(planet.element, elementColor),
                      const SizedBox(width: 8),
                      _buildChip(planet.modality, AppColors.textTertiary),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
        ),
      ),
    );
  }
}

/// Compact version for horizontal scrolling lists.
class PlanetInfoChip extends StatelessWidget {
  final PlanetPosition planet;
  final VoidCallback? onTap;

  const PlanetInfoChip({
    super.key,
    required this.planet,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final elementColor = ZodiacColors.forElement(planet.element);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: elementColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
          border: Border.all(color: elementColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              planet.planetSymbol,
              style: TextStyle(fontSize: 16, color: elementColor),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  planet.planetName,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${planet.signSymbol} ${planet.sign}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
