import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/gem_service.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../paywall/paywall.dart';
import '../../domain/models/synastry_model.dart';

/// Display synastry compatibility results with detailed AI analysis.
class CompatibilityResultView extends ConsumerStatefulWidget {
  final SynastryReport report;
  final VoidCallback onBack;

  const CompatibilityResultView({
    super.key,
    required this.report,
    required this.onBack,
  });

  @override
  ConsumerState<CompatibilityResultView> createState() => _CompatibilityResultViewState();
}

class _CompatibilityResultViewState extends ConsumerState<CompatibilityResultView> {
  // Track expanded state for each analysis section
  bool _chemistryExpanded = false;
  bool _emotionalExpanded = false;
  bool _challengesExpanded = false;

  // Share functionality
  final GlobalKey _shareableKey = GlobalKey();
  bool _isGeneratingShare = false;

  // Track if gems have been deducted for this viewing
  bool _gemsDeducted = false;

  SynastryReport get report => widget.report;

  @override
  void initState() {
    super.initState();
    // Deduct gems for premium users when viewing full results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deductGemsIfPremium();
    });
  }

  void _deductGemsIfPremium() {
    if (_gemsDeducted) return;

    final isPremium = ref.read(isPremiumProvider);
    if (isPremium) {
      ref.read(userProvider.notifier).spendGems(GemConfig.loveMatchCost);
      _gemsDeducted = true;
      debugPrint('💎 Deducted ${GemConfig.loveMatchCost} gems for Love Match');
    }
  }

  void debugPrint(String message) {
    // ignore: avoid_print
    print(message);
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);

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

          // ============================================
          // ALWAYS VISIBLE - Score Circle & Names
          // ============================================

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

          const SizedBox(height: AppConstants.spacingLarge),

          // ============================================
          // LOCKED CONTENT - Blur + Unlock Card for Free
          // ============================================
          if (isPremium) ...[
            // Premium users see everything
            // Summary text
            if (report.detailedAnalysis?.summary.isNotEmpty == true) ...[
              Text(
                report.detailedAnalysis!.summary,
                style: GoogleFonts.cinzel(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: AppConstants.spacingLarge),
            ],

            // Category Scores
            _buildCategoryScores(),

            const SizedBox(height: AppConstants.spacingLarge),

            // Detailed AI Analysis Sections
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
          ] else ...[
            // Free users see blurred content with unlock card
            _buildLockedContent(),
          ],

          const SizedBox(height: AppConstants.spacingLarge * 2),
        ],
      ),
    );
  }

  /// Build locked content with blur effect and unlock card for free users
  Widget _buildLockedContent() {
    const goldAccent = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);

    return Stack(
      children: [
        // Blurred content preview
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  // Category Scores (blurred)
                  _buildCategoryScores(),
                  const SizedBox(height: AppConstants.spacingMedium),
                  // Aspect Summary (blurred)
                  _buildAspectSummary(),
                ],
              ),
            ),
          ),
        ),

        // Unlock Card Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),
        ),

        // Unlock Card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _navigateToPaywall,
            child: Container(
              margin: const EdgeInsets.all(AppConstants.spacingMedium),
              padding: const EdgeInsets.all(AppConstants.spacingLarge),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1025),
                    const Color(0xFF2D1B3D),
                  ],
                ),
                border: Border.all(
                  color: goldAccent.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: goldAccent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon with glow
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          goldAccent.withOpacity(0.3),
                          goldAccent.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: goldAccent.withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [goldAccent, goldDark],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.favorite,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.spacingMedium),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.pink.shade200, goldAccent],
                    ).createShader(bounds),
                    child: Text(
                      'Get Detailed Love Report',
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.spacingSmall),

                  // Description
                  Text(
                    'Unlock emotional, intellectual & physical compatibility analysis, key aspects, and personalized advice.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppConstants.spacingMedium),

                  // CTA Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink.shade400, Colors.pink.shade600],
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, goldAccent],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Unlock Full Report',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
        ),
      ],
    );
  }

  void _navigateToPaywall() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallView(
          onClose: () => Navigator.of(context).pop(),
        ),
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

  // ===========================================================================
  // PREMIUM SHARE IMAGE GENERATOR - Cosmic Glassmorphism Design
  // ===========================================================================

  /// Generate premium shareable PNG image (Instagram Story format: 1080x1920)
  Future<Uint8List?> _generateShareableImage() async {
    const double W = 1080; // Story width
    const double H = 1920; // Story height

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final compatColor = Color(report.compatibilityColorValue);

    // ===========================================
    // LAYER 1: Deep Space Background
    // ===========================================
    _drawCosmicBackground(canvas, W, H);

    // ===========================================
    // LAYER 2: Twinkling Stars
    // ===========================================
    _drawTwinklingStars(canvas, W, H);

    // ===========================================
    // LAYER 3: Header - COSMIC LOVE MATCH
    // ===========================================
    _drawGlowText(
      canvas,
      '✨ COSMIC LOVE MATCH ✨',
      Offset(W / 2, 100),
      fontSize: 44,
      color: Colors.white,
      glowColor: Colors.purple.withOpacity(0.6),
      isCentered: true,
      fontWeight: FontWeight.bold,
    );

    // ===========================================
    // LAYER 4: Names with Heart
    // ===========================================
    final namesText = '${report.user1Name ?? "You"}  💕  ${report.user2Name ?? "Partner"}';
    _drawGlowText(
      canvas,
      namesText,
      Offset(W / 2, 180),
      fontSize: 34,
      color: Colors.pink.shade200,
      glowColor: Colors.pink.withOpacity(0.4),
      isCentered: true,
    );

    // ===========================================
    // LAYER 5: Score Circle & Percentage
    // ===========================================
    _drawPremiumScoreCircle(canvas, W / 2, 340, 110, compatColor);

    _drawGlowText(
      canvas,
      '${report.compatibilityScore}%',
      Offset(W / 2, 340),
      fontSize: 58,
      color: compatColor,
      glowColor: compatColor.withOpacity(0.5),
      isCentered: true,
      fontWeight: FontWeight.bold,
    );

    // ===========================================
    // LAYER 6: Compatibility Level Badge
    // ===========================================
    _drawGlassContainer(
      canvas,
      Rect.fromCenter(center: Offset(W / 2, 480), width: 340, height: 54),
      fillColor: compatColor.withOpacity(0.15),
      borderColor: compatColor.withOpacity(0.5),
      borderWidth: 1.5,
      cornerRadius: 27,
    );
    _drawGlowText(
      canvas,
      report.compatibilityLevel.toUpperCase(),
      Offset(W / 2, 480),
      fontSize: 24,
      color: compatColor,
      glowColor: compatColor.withOpacity(0.3),
      isCentered: true,
      fontWeight: FontWeight.w600,
    );

    // ===========================================
    // LAYER 7: Key Cosmic Insights Title
    // ===========================================
    _drawGlowText(
      canvas,
      '✦  KEY COSMIC INSIGHTS  ✦',
      Offset(W / 2, 580),
      fontSize: 26,
      color: Colors.white.withOpacity(0.85),
      glowColor: Colors.purple.withOpacity(0.3),
      isCentered: true,
      fontWeight: FontWeight.w600,
    );

    // ===========================================
    // LAYER 8: 3 Insight Cards with Full Interpretations
    // ===========================================
    final topAspects = report.keyAspects.take(3).toList();
    double currentY = 640;

    for (int i = 0; i < topAspects.length; i++) {
      final aspect = topAspects[i];
      final cardHeight = _drawFullInsightCard(canvas, W, currentY, aspect);
      currentY += cardHeight + 20; // 20px gap between cards
    }

    // ===========================================
    // LAYER 9: Footer Branding
    // ===========================================
    _drawGlowText(
      canvas,
      'mystic.app',
      Offset(W / 2, H - 60),
      fontSize: 22,
      color: Colors.white.withOpacity(0.4),
      glowColor: Colors.purple.withOpacity(0.15),
      isCentered: true,
    );

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(W.toInt(), H.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  /// Draw full insight card with complete interpretation text
  double _drawFullInsightCard(Canvas canvas, double width, double y, SynastryAspect aspect) {
    const marginX = 40.0;
    final cardWidth = width - (marginX * 2);

    final isPositive = aspect.harmonyScore > 0;
    final color = isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFB923C);
    final emoji = isPositive ? '💚' : '⚡';

    // Calculate text height for interpretation
    final interpretation = aspect.interpretation;
    final maxCharsPerLine = 45;
    final lines = (interpretation.length / maxCharsPerLine).ceil();
    final textHeight = lines * 24.0; // ~24px per line
    final cardHeight = 90 + textHeight; // Header + padding + text

    // Glass card background
    _drawGlassContainer(
      canvas,
      Rect.fromLTWH(marginX, y, cardWidth, cardHeight),
      fillColor: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.3),
      cornerRadius: 20,
    );

    // Header row: Emoji + Planet info
    final headerY = y + 35;

    // Emoji circle
    _drawGlassContainer(
      canvas,
      Rect.fromCircle(center: Offset(marginX + 40, headerY), radius: 22),
      fillColor: color.withOpacity(0.2),
      borderColor: color.withOpacity(0.5),
      cornerRadius: 22,
      withShadow: false,
    );
    _drawText(
      canvas,
      emoji,
      Offset(marginX + 40, headerY),
      fontSize: 20,
      color: Colors.white,
      isCentered: true,
    );

    // Aspect title (planets)
    final title = '${aspect.person1Planet} ${aspect.aspectSymbol} ${aspect.person2Planet}';
    _drawText(
      canvas,
      title,
      Offset(marginX + 80, headerY),
      fontSize: 20,
      color: Colors.white.withOpacity(0.95),
      fontWeight: FontWeight.w700,
    );

    // Aspect type badge
    _drawText(
      canvas,
      aspect.aspectType.toUpperCase(),
      Offset(cardWidth + marginX - 60, headerY),
      fontSize: 12,
      color: color.withOpacity(0.8),
      fontWeight: FontWeight.w600,
    );

    // Interpretation text (wrapped)
    _drawWrappedText(
      canvas,
      interpretation,
      Offset(marginX + 20, y + 65),
      maxWidth: cardWidth - 40,
      fontSize: 17,
      color: Colors.white.withOpacity(0.8),
      lineHeight: 1.5,
    );

    return cardHeight;
  }

  /// Draw wrapped text that fits within maxWidth
  void _drawWrappedText(
    Canvas canvas,
    String text,
    Offset position,
    {
      required double maxWidth,
      double fontSize = 16,
      Color color = Colors.white,
      double lineHeight = 1.4,
    }
  ) {
    final textStyle = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontFamily: 'Inter',
      height: lineHeight,
    );

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: TextAlign.left,
      maxLines: 10,
      ellipsis: '...',
    );

    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));

    canvas.drawParagraph(paragraph, position);
  }

  // ===========================================================================
  // PREMIUM HELPER FUNCTIONS
  // ===========================================================================

  /// Draw layered cosmic background with nebulae
  void _drawCosmicBackground(Canvas canvas, double width, double height) {
    // Base dark gradient
    final basePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(width, height),
        [
          const Color(0xFF050510),
          const Color(0xFF0A0A1A),
          const Color(0xFF0D0820),
          const Color(0xFF050510),
        ],
        [0.0, 0.3, 0.7, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), basePaint);

    // Nebula 1: Top-left purple
    _drawNebula(canvas, Offset(0, 0), 600, const Color(0xFF2D1B4E), 0.15);

    // Nebula 2: Center-right magenta
    _drawNebula(canvas, Offset(width, height * 0.4), 500, const Color(0xFF4A1942), 0.12);

    // Nebula 3: Bottom-left teal
    _drawNebula(canvas, Offset(0, height * 0.8), 400, const Color(0xFF1A3A4A), 0.10);

    // Nebula 4: Top-right pink
    _drawNebula(canvas, Offset(width, 200), 350, const Color(0xFF3D1A3D), 0.08);
  }

  /// Draw a single nebula (radial gradient blob)
  void _drawNebula(Canvas canvas, Offset center, double radius, Color color, double opacity) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.5),
          color.withOpacity(0),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  /// Draw twinkling stars with glow effect
  void _drawTwinklingStars(Canvas canvas, double width, double height) {
    final random = math.Random(42);

    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;
      final brightness = random.nextDouble();
      final size = random.nextDouble() * 2 + 0.5;

      // Glow layer
      if (brightness > 0.7) {
        final glowPaint = Paint()
          ..color = Colors.white.withOpacity(brightness * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(x, y), size * 3, glowPaint);
      }

      // Star core
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(0.3 + brightness * 0.5);
      canvas.drawCircle(Offset(x, y), size, starPaint);
    }

    // Add a few larger "bright" stars
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * width;
      final y = random.nextDouble() * height;

      // Outer glow
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), 6, glowPaint);

      // Inner bright core
      final corePaint = Paint()..color = Colors.white.withOpacity(0.9);
      canvas.drawCircle(Offset(x, y), 2, corePaint);
    }
  }

  /// Draw premium score circle with multiple glow layers
  void _drawPremiumScoreCircle(Canvas canvas, double cx, double cy, double radius, Color color) {
    // Outer glow (largest, most diffuse)
    final outerGlow = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset(cx, cy), radius, outerGlow);

    // Background track
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);

    // Progress arc glow
    final arcGlow = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * (report.compatibilityScore / 100),
      false,
      arcGlow,
    );

    // Main progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * (report.compatibilityScore / 100),
      false,
      progressPaint,
    );

    // Inner highlight (white reflection)
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius - 6),
      -math.pi / 2,
      2 * math.pi * (report.compatibilityScore / 100) * 0.3,
      false,
      highlightPaint,
    );
  }

  /// Draw a glassmorphism container
  void _drawGlassContainer(
    Canvas canvas,
    Rect rect, {
    Color fillColor = const Color(0x14FFFFFF),
    Color borderColor = const Color(0x33FFFFFF),
    double borderWidth = 1.0,
    double cornerRadius = 16,
    bool withShadow = true,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius));

    // Shadow (behind)
    if (withShadow) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.translate(0, 4), Radius.circular(cornerRadius)),
        shadowPaint,
      );
    }

    // Glass fill
    final fillPaint = Paint()..color = fillColor;
    canvas.drawRRect(rrect, fillPaint);

    // Gradient border (light edge effect)
    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        [
          borderColor,
          borderColor.withOpacity(0.1),
          borderColor.withOpacity(0.3),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, borderPaint);
  }

  /// Draw premium score bar with glass effect
  void _drawPremiumScoreBar(Canvas canvas, double width, String emoji, String label, int score, Color color, double y) {
    const double marginX = 60;
    const double barHeight = 28;
    final barWidth = width - (marginX * 2);

    // Glass container for the whole bar
    _drawGlassContainer(
      canvas,
      Rect.fromLTWH(marginX, y - 8, barWidth, barHeight + 16),
      fillColor: Colors.white.withOpacity(0.05),
      borderColor: color.withOpacity(0.2),
      cornerRadius: (barHeight + 16) / 2,
      withShadow: false,
    );

    // Emoji
    _drawText(canvas, emoji, Offset(marginX + 25, y + barHeight / 2), fontSize: 20, isCentered: true);

    // Label
    _drawText(
      canvas,
      label,
      Offset(marginX + 60, y + barHeight / 2),
      fontSize: 18,
      color: Colors.white.withOpacity(0.9),
    );

    // Score value
    _drawText(
      canvas,
      '$score%',
      Offset(width - marginX - 45, y + barHeight / 2),
      fontSize: 18,
      color: color,
      fontWeight: FontWeight.bold,
    );

    // Progress bar background
    const progressBarX = 180.0;
    final progressBarWidth = width - marginX - progressBarX - 90;
    final progressRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(progressBarX, y + 4, progressBarWidth, barHeight - 8),
      const Radius.circular(10),
    );
    canvas.drawRRect(progressRect, Paint()..color = color.withOpacity(0.15));

    // Progress bar fill with gradient
    final fillWidth = progressBarWidth * (score / 100);
    if (fillWidth > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(progressBarX, y + 4, fillWidth, barHeight - 8),
        const Radius.circular(10),
      );

      // Gradient fill
      final fillPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(progressBarX, 0),
          Offset(progressBarX + fillWidth, 0),
          [color.withOpacity(0.8), color],
        );
      canvas.drawRRect(fillRect, fillPaint);

      // Glow on bar
      final glowPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRRect(fillRect, glowPaint);
    }
  }

  /// Draw glass aspect count card
  void _drawGlassAspectCard(
    Canvas canvas,
    Offset center,
    String count,
    String label,
    Color color,
    String emoji, {
    required bool isPositive,
  }) {
    const cardWidth = 200.0;
    const cardHeight = 100.0;
    final rect = Rect.fromCenter(center: center, width: cardWidth, height: cardHeight);

    // Glass container
    _drawGlassContainer(
      canvas,
      rect,
      fillColor: color.withOpacity(0.08),
      borderColor: color.withOpacity(0.4),
      cornerRadius: 20,
    );

    // Icon glow background
    final iconCenter = Offset(center.dx, center.dy - 15);
    final iconGlow = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(iconCenter, 20, iconGlow);

    // Emoji
    _drawText(canvas, emoji, iconCenter, fontSize: 28, isCentered: true);

    // Count with glow
    _drawGlowText(
      canvas,
      count,
      Offset(center.dx, center.dy + 18),
      fontSize: 32,
      color: color,
      glowColor: color.withOpacity(0.4),
      isCentered: true,
      fontWeight: FontWeight.bold,
    );

    // Label
    _drawText(
      canvas,
      label,
      Offset(center.dx, center.dy + 42),
      fontSize: 14,
      color: Colors.white.withOpacity(0.6),
      isCentered: true,
    );
  }

  /// Draw key insight card (for aspects)
  void _drawInsightCard(Canvas canvas, double width, double y, SynastryAspect aspect) {
    const marginX = 50.0;
    const cardHeight = 120.0;
    final cardWidth = width - (marginX * 2);

    final isPositive = aspect.harmonyScore > 0;
    final color = isPositive ? Colors.green : Colors.orange;

    // Glass card
    _drawGlassContainer(
      canvas,
      Rect.fromLTWH(marginX, y, cardWidth, cardHeight),
      fillColor: color.withOpacity(0.06),
      borderColor: color.withOpacity(0.25),
      cornerRadius: 20,
    );

    // Aspect symbol circle
    final symbolCenter = Offset(marginX + 50, y + cardHeight / 2);
    _drawGlassContainer(
      canvas,
      Rect.fromCircle(center: symbolCenter, radius: 28),
      fillColor: color.withOpacity(0.15),
      borderColor: color.withOpacity(0.4),
      cornerRadius: 28,
      withShadow: false,
    );
    _drawText(
      canvas,
      aspect.aspectSymbol,
      symbolCenter,
      fontSize: 24,
      color: color,
      isCentered: true,
    );

    // Title (planets)
    final title = '${aspect.person1Planet} ${aspect.aspectType} ${aspect.person2Planet}';
    _drawText(
      canvas,
      title,
      Offset(marginX + 100, y + 30),
      fontSize: 18,
      color: Colors.white.withOpacity(0.95),
      fontWeight: FontWeight.w600,
    );

    // Description (truncated interpretation)
    final desc = aspect.interpretation.length > 60
        ? '${aspect.interpretation.substring(0, 57)}...'
        : aspect.interpretation;
    _drawText(
      canvas,
      desc,
      Offset(marginX + 100, y + 58),
      fontSize: 14,
      color: Colors.white.withOpacity(0.6),
      maxWidth: cardWidth - 200,
    );

    // Score badge
    final scoreText = isPositive ? '+${aspect.harmonyScore}' : '${aspect.harmonyScore}';
    final badgeRect = Rect.fromCenter(
      center: Offset(width - marginX - 55, y + cardHeight / 2),
      width: 60,
      height: 36,
    );
    _drawGlassContainer(
      canvas,
      badgeRect,
      fillColor: color.withOpacity(0.2),
      borderColor: color.withOpacity(0.5),
      cornerRadius: 12,
      withShadow: false,
    );
    _drawGlowText(
      canvas,
      scoreText,
      badgeRect.center,
      fontSize: 16,
      color: color,
      glowColor: color.withOpacity(0.3),
      isCentered: true,
      fontWeight: FontWeight.bold,
    );
  }

  /// Draw text with outer glow effect
  void _drawGlowText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 24,
    Color color = Colors.white,
    Color glowColor = Colors.white,
    bool isCentered = false,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    // Draw glow layer first (blurred, behind)
    _drawText(
      canvas,
      text,
      offset,
      fontSize: fontSize,
      color: glowColor,
      isCentered: isCentered,
      fontWeight: fontWeight,
      withBlur: true,
    );

    // Draw sharp text on top
    _drawText(
      canvas,
      text,
      offset,
      fontSize: fontSize,
      color: color,
      isCentered: isCentered,
      fontWeight: fontWeight,
    );
  }

  /// Draw text on canvas (upgraded with blur support)
  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 24,
    Color color = Colors.white,
    bool isCentered = false,
    FontWeight fontWeight = FontWeight.normal,
    FontStyle fontStyle = FontStyle.normal,
    double? maxWidth,
    bool withBlur = false,
  }) {
    final textStyle = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
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

    if (withBlur) {
      canvas.saveLayer(null, Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawParagraph(paragraph, textOffset);
      canvas.restore();
    } else {
      canvas.drawParagraph(paragraph, textOffset);
    }
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAspectDetailBottomSheet(aspect),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacingSmall),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Aspect symbol
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
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

              // Score indicator + tap hint
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
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
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show detailed aspect interpretation in a glassmorphism bottom sheet
  void _showAspectDetailBottomSheet(SynastryAspect aspect) {
    HapticFeedback.mediumImpact();

    final isPositive = aspect.harmonyScore > 0;
    final color = isPositive ? Colors.green : Colors.orange;
    final aspectTitle = '${aspect.person1Planet} ${aspect.aspectType} ${aspect.person2Planet}';

    // Generate interpretive advice based on aspect type
    final advice = isPositive
        ? _getHarmoniousAdvice(aspect.aspectType, aspect.person1Planet, aspect.person2Planet)
        : _getChallengingAdvice(aspect.aspectType, aspect.person1Planet, aspect.person2Planet);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            border: Border(
              top: BorderSide(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingLarge),
                child: Row(
                  children: [
                    // Aspect symbol with glow
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.3),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          aspect.aspectSymbol,
                          style: TextStyle(
                            fontSize: 28,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aspectTitle,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isPositive ? Icons.favorite : Icons.warning_amber_rounded,
                                color: color,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPositive ? 'Harmonious Aspect' : 'Challenging Aspect',
                                style: AppTypography.labelSmall.copyWith(
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Score badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.3),
                            color.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        isPositive ? '+${aspect.harmonyScore}' : '${aspect.harmonyScore}',
                        style: AppTypography.titleSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLarge),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      color.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Body - Interpretation
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.spacingLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: What This Means
                      Text(
                        'COSMIC INTERPRETATION',
                        style: AppTypography.labelMedium.copyWith(
                          color: color,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Interpretation text
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppConstants.spacingMedium),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          border: Border.all(
                            color: AppColors.glassBorder,
                          ),
                        ),
                        child: Text(
                          aspect.interpretation,
                          style: GoogleFonts.lora(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                            height: 1.7,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppConstants.spacingLarge),

                      // Section: Orb details
                      _buildOrbInfo(aspect.orb, color),

                      const SizedBox(height: AppConstants.spacingLarge),

                      // Section: Advice
                      Text(
                        isPositive ? 'HOW TO NURTURE THIS ENERGY' : 'HOW TO NAVIGATE THIS ENERGY',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Advice card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppConstants.spacingMedium),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.15),
                              color.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isPositive ? Icons.lightbulb_outline : Icons.psychology_outlined,
                              color: color,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                advice,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppConstants.spacingLarge),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build orb information widget
  Widget _buildOrbInfo(double orb, Color color) {
    final orbStrength = orb <= 2.0 ? 'Very Strong' : (orb <= 5.0 ? 'Strong' : 'Moderate');
    final orbEmoji = orb <= 2.0 ? '⚡' : (orb <= 5.0 ? '✨' : '🌟');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
        vertical: AppConstants.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.glassFill,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Text(orbEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aspect Strength: $orbStrength',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Orb: ${orb.toStringAsFixed(1)}°',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Strength indicator
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: color.withValues(alpha: 0.2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (10 - orb.clamp(0, 10)) / 10,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get harmonious advice based on aspect type
  String _getHarmoniousAdvice(String aspectType, String planet1, String planet2) {
    final aspectLower = aspectType.toLowerCase();

    if (aspectLower.contains('trine')) {
      return 'This trine creates a natural flow of energy between you. The connection between $planet1 and $planet2 feels effortless. Lean into this ease—it\'s a gift that supports your bond during challenging times.';
    } else if (aspectLower.contains('sextile')) {
      return 'This sextile offers wonderful opportunities for growth together. The harmony between $planet1 and $planet2 opens doors—but you must walk through them. Be proactive in nurturing this connection.';
    } else if (aspectLower.contains('conjunction')) {
      return 'This conjunction merges your energies powerfully. The fusion of $planet1 and $planet2 creates intense understanding. Channel this unified force toward shared goals and mutual growth.';
    }

    return 'This harmonious aspect between $planet1 and $planet2 is a blessing in your relationship. Celebrate and nurture this positive energy—it forms the foundation of your connection.';
  }

  /// Get challenging advice based on aspect type
  String _getChallengingAdvice(String aspectType, String planet1, String planet2) {
    final aspectLower = aspectType.toLowerCase();

    if (aspectLower.contains('square')) {
      return 'This square creates dynamic tension between $planet1 and $planet2. Rather than avoiding friction, use it as fuel for growth. The challenges you face together can become your greatest teachers.';
    } else if (aspectLower.contains('opposition')) {
      return 'This opposition asks you to find balance between seemingly opposite needs. The tension between $planet1 and $planet2 invites compromise and understanding. Meet in the middle.';
    } else if (aspectLower.contains('quincunx') || aspectLower.contains('inconjunct')) {
      return 'This quincunx requires constant adjustment between $planet1 and $planet2. Flexibility and patience are your allies. Accept that some differences may never fully resolve—and that\'s okay.';
    }

    return 'This challenging aspect between $planet1 and $planet2 offers opportunities for profound growth. Approach differences with curiosity rather than judgment—they can deepen your bond.';
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
