import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/natal_chart_model.dart';

/// Colors for zodiac elements.
class ZodiacColors {
  static const fire = Color(0xFFFF6B35);
  static const earth = Color(0xFF7CB342);
  static const air = Color(0xFF42A5F5);
  static const water = Color(0xFF5C6BC0);

  static Color forElement(String element) {
    switch (element.toLowerCase()) {
      case 'fire':
        return fire;
      case 'earth':
        return earth;
      case 'air':
        return air;
      case 'water':
        return water;
      default:
        return Colors.grey;
    }
  }
}

/// Zodiac sign data for the wheel.
class ZodiacSign {
  final String name;
  final String symbol;
  final String element;
  final int startDegree;

  const ZodiacSign({
    required this.name,
    required this.symbol,
    required this.element,
    required this.startDegree,
  });
}

/// All zodiac signs in order.
const List<ZodiacSign> zodiacSigns = [
  ZodiacSign(name: 'Aries', symbol: '♈', element: 'Fire', startDegree: 0),
  ZodiacSign(name: 'Taurus', symbol: '♉', element: 'Earth', startDegree: 30),
  ZodiacSign(name: 'Gemini', symbol: '♊', element: 'Air', startDegree: 60),
  ZodiacSign(name: 'Cancer', symbol: '♋', element: 'Water', startDegree: 90),
  ZodiacSign(name: 'Leo', symbol: '♌', element: 'Fire', startDegree: 120),
  ZodiacSign(name: 'Virgo', symbol: '♍', element: 'Earth', startDegree: 150),
  ZodiacSign(name: 'Libra', symbol: '♎', element: 'Air', startDegree: 180),
  ZodiacSign(name: 'Scorpio', symbol: '♏', element: 'Water', startDegree: 210),
  ZodiacSign(name: 'Sagittarius', symbol: '♐', element: 'Fire', startDegree: 240),
  ZodiacSign(name: 'Capricorn', symbol: '♑', element: 'Earth', startDegree: 270),
  ZodiacSign(name: 'Aquarius', symbol: '♒', element: 'Air', startDegree: 300),
  ZodiacSign(name: 'Pisces', symbol: '♓', element: 'Water', startDegree: 330),
];

/// Custom painter for the natal chart zodiac wheel.
class NatalChartPainter extends CustomPainter {
  final NatalChart? chart;
  final Color primaryColor;
  final Color backgroundColor;

  NatalChartPainter({
    this.chart,
    this.primaryColor = const Color(0xFF9D00FF),
    this.backgroundColor = const Color(0xFF1A1A2E),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw outer ring with signs
    _drawZodiacRing(canvas, center, radius);

    // Draw house divisions
    _drawHouseDivisions(canvas, center, radius * 0.75);

    // Draw inner circle
    _drawInnerCircle(canvas, center, radius * 0.3);

    // Draw planets if chart is available
    if (chart != null) {
      _drawPlanets(canvas, center, radius * 0.55);
    }
  }

  void _drawZodiacRing(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..color = backgroundColor.withOpacity(0.5);

    // Draw base ring
    canvas.drawCircle(center, radius - 15, ringPaint);

    // Draw sign sections
    for (int i = 0; i < 12; i++) {
      final sign = zodiacSigns[i];
      final startAngle = _degreesToRadians(sign.startDegree - 90);
      final sweepAngle = _degreesToRadians(30);

      // Draw colored arc for each sign
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..color = ZodiacColors.forElement(sign.element).withOpacity(0.3);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 15),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );

      // Draw sign symbol
      final midAngle = startAngle + sweepAngle / 2;
      final symbolOffset = Offset(
        center.dx + (radius - 15) * math.cos(midAngle),
        center.dy + (radius - 15) * math.sin(midAngle),
      );

      _drawText(
        canvas,
        sign.symbol,
        symbolOffset,
        ZodiacColors.forElement(sign.element),
        18,
      );
    }

    // Draw outer border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = primaryColor.withOpacity(0.5);

    canvas.drawCircle(center, radius, borderPaint);
    canvas.drawCircle(center, radius - 30, borderPaint);
  }

  void _drawHouseDivisions(Canvas canvas, Offset center, double radius) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = primaryColor.withOpacity(0.3);

    for (int i = 0; i < 12; i++) {
      final angle = _degreesToRadians(i * 30 - 90);
      final innerPoint = Offset(
        center.dx + radius * 0.4 * math.cos(angle),
        center.dy + radius * 0.4 * math.sin(angle),
      );
      final outerPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, linePaint);
    }
  }

  void _drawInnerCircle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.1),
          backgroundColor.withOpacity(0.5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = primaryColor.withOpacity(0.5);

    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawPlanets(Canvas canvas, Offset center, double radius) {
    final planets = chart!.allPlanets;

    for (final planet in planets) {
      // Convert degree to position on wheel
      // In astrology, 0° Aries starts at left and goes counter-clockwise
      // In our wheel, we start at top and go clockwise
      final angle = _degreesToRadians(planet.degree - 90);

      final planetOffset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      // Draw planet dot
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = ZodiacColors.forElement(planet.element);

      canvas.drawCircle(planetOffset, 8, dotPaint);

      // Draw glow
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = ZodiacColors.forElement(planet.element).withOpacity(0.3);

      canvas.drawCircle(planetOffset, 12, glowPaint);

      // Draw planet symbol
      _drawText(
        canvas,
        planet.planetSymbol,
        planetOffset,
        Colors.white,
        12,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    Color color,
    double fontSize,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant NatalChartPainter oldDelegate) {
    return oldDelegate.chart != chart;
  }
}

/// Widget wrapper for the natal chart painter.
class NatalChartWheel extends StatelessWidget {
  final NatalChart? chart;
  final double size;
  final Color? primaryColor;

  const NatalChartWheel({
    super.key,
    this.chart,
    this.size = 300,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: NatalChartPainter(
          chart: chart,
          primaryColor: primaryColor ?? const Color(0xFF9D00FF),
        ),
      ),
    );
  }
}
