import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  // Share functionality
  final GlobalKey _shareableKey = GlobalKey();
  bool _isGeneratingShare = false;

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

          // Share Button
          _buildShareButton(),

          const SizedBox(height: AppConstants.spacingLarge * 2),
        ],
      ),
    );
  }

  /// Share button
  Widget _buildShareButton() {
    return Builder(
      builder: (context) {
        return GestureDetector(
          onTap: _isGeneratingShare ? null : () => _shareResult(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.pink.shade400,
                  Colors.purple.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGeneratingShare)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else
                  Icon(Icons.share_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  _isGeneratingShare ? 'Creating...' : 'Share',
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(delay: 800.ms, duration: 400.ms);
  }

  /// Generate and share the result as Instagram story image
  Future<void> _shareResult(BuildContext context) async {
    setState(() => _isGeneratingShare = true);
    HapticFeedback.mediumImpact();

    try {
      // Create the shareable image off-screen
      final image = await _generateShareableImage();

      if (image == null) {
        throw Exception('Failed to generate image');
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final fileName = 'love_match_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(image);

      // Get the render box for share position (required for iPad)
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      // Share the image
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '✨ Our cosmic compatibility: ${report.compatibilityScore}% ${report.compatibilityLevel} ✨',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingShare = false);
      }
    }
  }

  /// Generate shareable PNG image (Instagram Story format: 1080x1920)
  Future<Uint8List?> _generateShareableImage() async {
    // Instagram Story dimensions
    const double storyWidth = 1080;
    const double storyHeight = 1920;

    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(0, storyHeight),
        [
          const Color(0xFF0D0D1A),
          const Color(0xFF1A0A2E),
          const Color(0xFF0D0D1A),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, storyWidth, storyHeight),
      bgPaint,
    );

    // Draw decorative stars
    _drawStars(canvas, storyWidth, storyHeight);

    // Draw content
    final compatColor = Color(report.compatibilityColorValue);

    // Title
    _drawText(
      canvas,
      '✨ COSMIC LOVE MATCH ✨',
      const Offset(storyWidth / 2, 180),
      fontSize: 48,
      color: Colors.white.withOpacity(0.9),
      isCentered: true,
      fontWeight: FontWeight.bold,
    );

    // Names
    final namesText = '${report.user1Name ?? "You"} & ${report.user2Name ?? "Partner"}';
    _drawText(
      canvas,
      namesText,
      const Offset(storyWidth / 2, 280),
      fontSize: 36,
      color: Colors.pink.shade200,
      isCentered: true,
    );

    // Main score circle
    _drawScoreCircle(canvas, storyWidth / 2, 580, 180, compatColor);

    // Score text
    _drawText(
      canvas,
      '${report.compatibilityScore}%',
      const Offset(storyWidth / 2, 580),
      fontSize: 72,
      color: compatColor,
      isCentered: true,
      fontWeight: FontWeight.bold,
    );

    // Compatibility level
    _drawText(
      canvas,
      report.compatibilityLevel.toUpperCase(),
      const Offset(storyWidth / 2, 820),
      fontSize: 40,
      color: compatColor,
      isCentered: true,
      fontWeight: FontWeight.w600,
    );

    // Category scores
    const scoreStartY = 980.0;
    const scoreSpacing = 100.0;

    _drawScoreBar(canvas, '❤️  Emotional', report.emotionalCompatibility, Colors.pink, scoreStartY);
    _drawScoreBar(canvas, '🧠  Intellectual', report.intellectualCompatibility, Colors.blue, scoreStartY + scoreSpacing);
    _drawScoreBar(canvas, '🔥  Physical', report.physicalCompatibility, Colors.orange, scoreStartY + scoreSpacing * 2);
    _drawScoreBar(canvas, '✨  Spiritual', report.spiritualCompatibility, const Color(0xFF00D9FF), scoreStartY + scoreSpacing * 3);

    // Aspect counts
    _drawAspectCounts(canvas, storyWidth, 1480);

    // Summary (if available)
    if (report.detailedAnalysis?.summary.isNotEmpty == true) {
      final summary = report.detailedAnalysis!.summary;
      final truncatedSummary = summary.length > 120 ? '${summary.substring(0, 117)}...' : summary;
      _drawText(
        canvas,
        '"$truncatedSummary"',
        const Offset(storyWidth / 2, 1650),
        fontSize: 28,
        color: Colors.white.withOpacity(0.7),
        isCentered: true,
        maxWidth: storyWidth - 120,
      );
    }

    // App branding
    _drawText(
      canvas,
      'mystic.app',
      const Offset(storyWidth / 2, 1850),
      fontSize: 24,
      color: Colors.white.withOpacity(0.4),
      isCentered: true,
    );

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(storyWidth.toInt(), storyHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  void _drawStars(Canvas canvas, double width, double height) {
    final random = math.Random(42); // Fixed seed for consistent stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.3);

    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final radius = random.nextDouble() * 2 + 0.5;
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  void _drawScoreCircle(Canvas canvas, double cx, double cy, double radius, Color color) {
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * (report.compatibilityScore / 100),
      false,
      progressPaint,
    );

    // Glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * (report.compatibilityScore / 100),
      false,
      glowPaint,
    );
  }

  void _drawScoreBar(Canvas canvas, String label, int score, Color color, double y) {
    const double barX = 100;
    const double barWidth = 880;
    const double barHeight = 24;

    // Label
    _drawText(canvas, label, Offset(barX, y - 30), fontSize: 28, color: Colors.white.withOpacity(0.8));

    // Score
    _drawText(canvas, '$score%', Offset(barX + barWidth - 60, y - 30), fontSize: 28, color: color, fontWeight: FontWeight.bold);

    // Background bar
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barX, y, barWidth, barHeight),
      const Radius.circular(12),
    );
    canvas.drawRRect(bgRect, Paint()..color = color.withOpacity(0.2));

    // Progress bar
    final progressRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(barX, y, barWidth * (score / 100), barHeight),
      const Radius.circular(12),
    );
    canvas.drawRRect(progressRect, Paint()..color = color);
  }

  void _drawAspectCounts(Canvas canvas, double width, double y) {
    // Harmonious
    _drawAspectBadge(
      canvas,
      width / 2 - 180,
      y,
      '${report.harmoniousAspectsCount}',
      'Harmonious',
      Colors.green,
      '👍',
    );

    // Challenging
    _drawAspectBadge(
      canvas,
      width / 2 + 180,
      y,
      '${report.challengingAspectsCount}',
      'Challenging',
      Colors.orange,
      '⚡',
    );
  }

  void _drawAspectBadge(Canvas canvas, double cx, double cy, String count, String label, Color color, String emoji) {
    // Background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 200, height: 120),
      const Radius.circular(20),
    );
    canvas.drawRRect(bgRect, Paint()..color = color.withOpacity(0.15));
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Emoji
    _drawText(canvas, emoji, Offset(cx, cy - 25), fontSize: 32, isCentered: true);

    // Count
    _drawText(canvas, count, Offset(cx, cy + 10), fontSize: 36, color: color, isCentered: true, fontWeight: FontWeight.bold);

    // Label
    _drawText(canvas, label, Offset(cx, cy + 45), fontSize: 20, color: Colors.white.withOpacity(0.6), isCentered: true);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 24,
    Color color = Colors.white,
    bool isCentered = false,
    FontWeight fontWeight = FontWeight.normal,
    double? maxWidth,
  }) {
    final textStyle = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: isCentered ? TextAlign.center : TextAlign.left,
      maxLines: maxWidth != null ? 3 : 1,
      ellipsis: '...',
    );

    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth ?? 1000));

    final textOffset = isCentered
        ? Offset(offset.dx - paragraph.width / 2, offset.dy - paragraph.height / 2)
        : offset;

    canvas.drawParagraph(paragraph, textOffset);
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
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
