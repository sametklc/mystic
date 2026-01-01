import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/astrology_profile_model.dart';

/// Custom painter for the mystical zodiac wheel
class ZodiacWheelPainter extends CustomPainter {
  /// Current rotation angle in radians
  final double rotation;

  /// Glow intensity (0.0 - 1.0)
  final double glowIntensity;

  /// Whether to show zodiac symbols
  final bool showSymbols;

  /// Highlighted sign (if any)
  final ZodiacSign? highlightedSign;

  /// Animation progress for reveal (0.0 - 1.0)
  final double revealProgress;

  // Pre-allocated paints for performance
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _sectionPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _glowPaint = Paint()..style = PaintingStyle.fill;
  final Paint _symbolPaint = Paint()..style = PaintingStyle.fill;

  ZodiacWheelPainter({
    required this.rotation,
    this.glowIntensity = 0.5,
    this.showSymbols = true,
    this.highlightedSign,
    this.revealProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 0.9;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Draw outer glow
    _drawOuterGlow(canvas, radius);

    // Draw the main wheel rings
    _drawWheelRings(canvas, radius);

    // Draw zodiac sections
    _drawZodiacSections(canvas, radius);

    // Draw zodiac symbols
    if (showSymbols && revealProgress > 0.3) {
      _drawZodiacSymbols(canvas, radius);
    }

    // Draw center orb
    _drawCenterOrb(canvas, radius);

    // Draw decorative elements
    _drawDecorativeElements(canvas, radius);

    canvas.restore();
  }

  void _drawOuterGlow(Canvas canvas, double radius) {
    final glowRadius = radius * 1.3;
    final gradient = ui.Gradient.radial(
      Offset.zero,
      glowRadius,
      [
        AppColors.secondary.withOpacity(glowIntensity * 0.4),
        AppColors.primary.withOpacity(glowIntensity * 0.2),
        Colors.transparent,
      ],
      [0.3, 0.6, 1.0],
    );

    _glowPaint.shader = gradient;
    canvas.drawCircle(Offset.zero, glowRadius, _glowPaint);
  }

  void _drawWheelRings(Canvas canvas, double radius) {
    // Outer ring
    _ringPaint
      ..color = AppColors.primary.withOpacity(0.8 * revealProgress)
      ..strokeWidth = 2.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity);
    canvas.drawCircle(Offset.zero, radius, _ringPaint);

    // Middle ring
    _ringPaint
      ..color = AppColors.secondary.withOpacity(0.5 * revealProgress)
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, radius * 0.75, _ringPaint);

    // Inner ring
    _ringPaint
      ..color = AppColors.primary.withOpacity(0.6 * revealProgress)
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset.zero, radius * 0.5, _ringPaint);

    // Innermost ring
    _ringPaint
      ..color = AppColors.mysticTeal.withOpacity(0.4 * revealProgress)
      ..strokeWidth = 0.5;
    canvas.drawCircle(Offset.zero, radius * 0.3, _ringPaint);
  }

  void _drawZodiacSections(Canvas canvas, double radius) {
    const sectionAngle = pi * 2 / 12;

    for (var i = 0; i < 12; i++) {
      final startAngle = i * sectionAngle - pi / 2;
      final sign = ZodiacSign.values[i];
      final isHighlighted = sign == highlightedSign;

      // Draw section line
      _sectionPaint
        ..color = isHighlighted
            ? AppColors.primary.withOpacity(revealProgress)
            : AppColors.glassBorder.withOpacity(0.5 * revealProgress)
        ..strokeWidth = isHighlighted ? 2.0 : 1.0
        ..maskFilter = isHighlighted
            ? MaskFilter.blur(BlurStyle.normal, 4 * glowIntensity)
            : null;

      final innerRadius = radius * 0.5;
      final outerRadius = radius;

      final startPoint = Offset(
        cos(startAngle) * innerRadius,
        sin(startAngle) * innerRadius,
      );
      final endPoint = Offset(
        cos(startAngle) * outerRadius,
        sin(startAngle) * outerRadius,
      );

      canvas.drawLine(startPoint, endPoint, _sectionPaint);

      // Draw highlight arc for selected sign
      if (isHighlighted && revealProgress > 0.5) {
        final highlightPaint = Paint()
          ..color = AppColors.primary.withOpacity(0.2 * revealProgress)
          ..style = PaintingStyle.fill;

        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(cos(startAngle) * outerRadius, sin(startAngle) * outerRadius)
          ..arcTo(
            Rect.fromCircle(center: Offset.zero, radius: outerRadius),
            startAngle,
            sectionAngle,
            false,
          )
          ..lineTo(0, 0)
          ..close();

        canvas.drawPath(path, highlightPaint);
      }
    }
  }

  void _drawZodiacSymbols(Canvas canvas, double radius) {
    const sectionAngle = pi * 2 / 12;
    final symbolRadius = radius * 0.85;
    final opacity = ((revealProgress - 0.3) / 0.7).clamp(0.0, 1.0);

    for (var i = 0; i < 12; i++) {
      final angle = i * sectionAngle + sectionAngle / 2 - pi / 2;
      final sign = ZodiacSign.values[i];
      final isHighlighted = sign == highlightedSign;

      final position = Offset(
        cos(angle) * symbolRadius,
        sin(angle) * symbolRadius,
      );

      // Counter-rotate text so it's readable
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(-rotation);

      final textPainter = TextPainter(
        text: TextSpan(
          text: sign.symbol,
          style: TextStyle(
            fontSize: isHighlighted ? 22 : 18,
            color: isHighlighted
                ? AppColors.primary.withOpacity(opacity)
                : AppColors.textSecondary.withOpacity(opacity * 0.7),
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            shadows: isHighlighted
                ? [
                    Shadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 10 * glowIntensity,
                    ),
                  ]
                : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }
  }

  void _drawCenterOrb(Canvas canvas, double radius) {
    final orbRadius = radius * 0.2;

    // Outer glow
    final outerGlow = ui.Gradient.radial(
      Offset.zero,
      orbRadius * 2,
      [
        AppColors.primary.withOpacity(0.4 * glowIntensity * revealProgress),
        AppColors.secondary.withOpacity(0.2 * glowIntensity * revealProgress),
        Colors.transparent,
      ],
      [0.0, 0.5, 1.0],
    );

    _glowPaint.shader = outerGlow;
    canvas.drawCircle(Offset.zero, orbRadius * 2, _glowPaint);

    // Inner orb gradient
    final orbGradient = ui.Gradient.radial(
      Offset(-orbRadius * 0.3, -orbRadius * 0.3),
      orbRadius * 1.5,
      [
        AppColors.primaryLight.withOpacity(0.9 * revealProgress),
        AppColors.primary.withOpacity(0.7 * revealProgress),
        AppColors.secondary.withOpacity(0.5 * revealProgress),
      ],
      [0.0, 0.5, 1.0],
    );

    _glowPaint.shader = orbGradient;
    canvas.drawCircle(Offset.zero, orbRadius, _glowPaint);

    // Inner core
    final coreGradient = ui.Gradient.radial(
      Offset.zero,
      orbRadius * 0.5,
      [
        Colors.white.withOpacity(0.9 * revealProgress),
        AppColors.primaryLight.withOpacity(0.6 * revealProgress),
      ],
    );

    _glowPaint.shader = coreGradient;
    canvas.drawCircle(Offset.zero, orbRadius * 0.4, _glowPaint);
  }

  void _drawDecorativeElements(Canvas canvas, double radius) {
    // Draw small stars/dots around the wheel
    final dotPaint = Paint()
      ..color = AppColors.starWhite.withOpacity(0.6 * revealProgress)
      ..style = PaintingStyle.fill;

    final random = Random(42); // Seeded for consistency

    for (var i = 0; i < 24; i++) {
      final angle = (i / 24) * pi * 2;
      final distance = radius * (0.92 + random.nextDouble() * 0.15);
      final size = 1.0 + random.nextDouble() * 1.5;

      final position = Offset(
        cos(angle) * distance,
        sin(angle) * distance,
      );

      canvas.drawCircle(position, size, dotPaint);
    }
  }

  @override
  bool shouldRepaint(ZodiacWheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.highlightedSign != highlightedSign ||
        oldDelegate.revealProgress != revealProgress;
  }
}
