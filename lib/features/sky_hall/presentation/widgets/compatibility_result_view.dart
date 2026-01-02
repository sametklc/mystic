import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../domain/models/synastry_model.dart';

/// Display synastry compatibility results with detailed AI analysis.
class CompatibilityResultView extends StatefulWidget {
  final SynastryReport report;
  final VoidCallback onBack;

  const CompatibilityResultView({
    super.key,
    required this.report,
    required this.onBack,
  });

  @override
  State<CompatibilityResultView> createState() => _CompatibilityResultViewState();
}

class _CompatibilityResultViewState extends State<CompatibilityResultView> {
  // Track expanded state for each analysis section
  bool _chemistryExpanded = false;
  bool _emotionalExpanded = false;
  bool _challengesExpanded = false;

  SynastryReport get report => widget.report;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.glassFill,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Back',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.spacingLarge),

          // Main Score Circle
          _buildScoreCircle(),

          const SizedBox(height: AppConstants.spacingMedium),

          // Names
          _buildNamesRow(),

          const SizedBox(height: AppConstants.spacingSmall),

          // Level Label
          Text(
            report.compatibilityLevel,
            style: AppTypography.headlineSmall.copyWith(
              color: Color(report.compatibilityColorValue),
            ),
          ).animate().fadeIn(delay: 400.ms),

          // Summary text
          if (report.detailedAnalysis?.summary.isNotEmpty == true) ...[
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              report.detailedAnalysis!.summary,
              style: GoogleFonts.cinzel(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 500.ms),
          ],

          const SizedBox(height: AppConstants.spacingLarge),

          // Category Scores
          _buildCategoryScores(),

          const SizedBox(height: AppConstants.spacingLarge),

          // NEW: Detailed AI Analysis Sections
          if (report.detailedAnalysis?.hasContent == true) ...[
            _buildDetailedAnalysisSections(),
            const SizedBox(height: AppConstants.spacingLarge),
          ],

          // Aspect Summary
          _buildAspectSummary(),

          const SizedBox(height: AppConstants.spacingLarge),

          // Key Aspects
          _buildKeyAspects(),

          const SizedBox(height: AppConstants.spacingLarge),
        ],
      ),
    );
  }

  /// Build the three expandable analysis sections
  Widget _buildDetailedAnalysisSections() {
    final analysis = report.detailedAnalysis!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COSMIC INSIGHTS',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSmall),

        // Chemistry Section (Fire icon - Orange)
        if (analysis.chemistryAnalysis.isNotEmpty)
          _buildExpandableAnalysisCard(
            title: 'Chemistry & Attraction',
            content: analysis.chemistryAnalysis,
            icon: Icons.local_fire_department,
            color: Colors.deepOrange,
            isExpanded: _chemistryExpanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _chemistryExpanded = !_chemistryExpanded);
            },
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

        const SizedBox(height: AppConstants.spacingSmall),

        // Emotional Connection Section (Heart icon - Pink)
        if (analysis.emotionalConnection.isNotEmpty)
          _buildExpandableAnalysisCard(
            title: 'Emotional Connection',
            content: analysis.emotionalConnection,
            icon: Icons.favorite,
            color: Colors.pink,
            isExpanded: _emotionalExpanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _emotionalExpanded = !_emotionalExpanded);
            },
          ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

        const SizedBox(height: AppConstants.spacingSmall),

        // Challenges Section (Warning icon - Amber)
        if (analysis.challenges.isNotEmpty)
          _buildExpandableAnalysisCard(
            title: 'Growth Opportunities',
            content: analysis.challenges,
            icon: Icons.warning_amber_rounded,
            color: Colors.amber,
            isExpanded: _challengesExpanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _challengesExpanded = !_challengesExpanded);
            },
          ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
      ],
    );
  }

  /// Build an expandable analysis card
  Widget _buildExpandableAnalysisCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: color.withOpacity(isExpanded ? 0.5 : 0.3),
            width: isExpanded ? 1.5 : 1,
          ),
          boxShadow: isExpanded
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (always visible)
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMedium),
                child: Row(
                  children: [
                    // Icon with glow
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),

                    // Title
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.titleSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Expand indicator
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: color.withOpacity(0.7),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),

              // Content (expandable)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(
                    left: AppConstants.spacingMedium,
                    right: AppConstants.spacingMedium,
                    bottom: AppConstants.spacingMedium,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppConstants.spacingMedium),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    ),
                    child: Text(
                      content,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCircle() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: const Size(180, 180),
            painter: _CircleProgressPainter(
              progress: report.compatibilityScore / 100,
              color: Color(report.compatibilityColorValue),
              backgroundColor: AppColors.glassFill,
            ),
          ),

          // Score text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${report.compatibilityScore}',
                style: AppTypography.displayLarge.copyWith(
                  color: Color(report.compatibilityColorValue),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '%',
                style: AppTypography.titleLarge.copyWith(
                  color: Color(report.compatibilityColorValue).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
        );
  }

  Widget _buildNamesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          report.user1Name ?? 'You',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.favorite,
            color: Colors.pink,
            size: 20,
          ),
        ),
        Text(
          report.user2Name ?? 'Partner',
          style: AppTypography.titleMedium.copyWith(
            color: Colors.pink,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildCategoryScores() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingMedium),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            children: [
              _buildScoreRow(
                icon: Icons.favorite_outline,
                label: 'Emotional',
                score: report.emotionalCompatibility,
                color: Colors.pink,
              ),
              const SizedBox(height: AppConstants.spacingMedium),
              _buildScoreRow(
                icon: Icons.psychology_outlined,
                label: 'Intellectual',
                score: report.intellectualCompatibility,
                color: Colors.blue,
              ),
              const SizedBox(height: AppConstants.spacingMedium),
              _buildScoreRow(
                icon: Icons.local_fire_department_outlined,
                label: 'Physical',
                score: report.physicalCompatibility,
                color: Colors.orange,
              ),
              const SizedBox(height: AppConstants.spacingMedium),
              _buildScoreRow(
                icon: Icons.auto_awesome_outlined,
                label: 'Spiritual',
                score: report.spiritualCompatibility,
                color: AppColors.mysticTeal,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildScoreRow({
    required IconData icon,
    required String label,
    required int score,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '$score%',
                    style: AppTypography.labelMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAspectSummary() {
    return Row(
      children: [
        Expanded(
          child: _buildAspectCountCard(
            count: report.harmoniousAspectsCount,
            label: 'Harmonious',
            icon: Icons.thumb_up_outlined,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: AppConstants.spacingMedium),
        Expanded(
          child: _buildAspectCountCard(
            count: report.challengingAspectsCount,
            label: 'Challenging',
            icon: Icons.warning_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  Widget _buildAspectCountCard({
    required int count,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: AppTypography.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyAspects() {
    if (report.keyAspects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KEY ASPECTS',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSmall),
        ...report.keyAspects.take(5).map((aspect) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
              child: _buildAspectCard(aspect),
            )),
      ],
    ).animate().fadeIn(delay: 700.ms, duration: 400.ms);
  }

  Widget _buildAspectCard(SynastryAspect aspect) {
    final isPositive = aspect.harmonyScore > 0;
    final color = isPositive ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSmall),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Aspect symbol
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                aspect.aspectSymbol,
                style: TextStyle(
                  fontSize: 18,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Planets and type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${aspect.person1Planet} ${aspect.aspectType} ${aspect.person2Planet}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  aspect.interpretation,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Score indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPositive ? '+${aspect.harmonyScore}' : '${aspect.harmonyScore}',
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for circular progress indicator.
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      2 * math.pi * progress, // Progress angle
      false,
      progressPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
