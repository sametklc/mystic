import 'package:flutter/material.dart';

/// Model representing the daily cosmic insight.
class DailyInsight {
  final String date;
  final String moonPhase;
  final String moonPhaseIcon;
  final double moonIllumination;
  final String moonSign;
  final String moonSignSymbol;
  final String moonElement;
  final bool mercuryRetrograde;
  final String mercuryStatus;
  final String advice;
  final String sunSign;

  const DailyInsight({
    required this.date,
    required this.moonPhase,
    required this.moonPhaseIcon,
    required this.moonIllumination,
    required this.moonSign,
    required this.moonSignSymbol,
    required this.moonElement,
    required this.mercuryRetrograde,
    required this.mercuryStatus,
    required this.advice,
    required this.sunSign,
  });

  factory DailyInsight.fromJson(Map<String, dynamic> json) {
    return DailyInsight(
      date: json['date'] as String,
      moonPhase: json['moon_phase'] as String,
      moonPhaseIcon: json['moon_phase_icon'] as String,
      moonIllumination: (json['moon_illumination'] as num).toDouble(),
      moonSign: json['moon_sign'] as String,
      moonSignSymbol: json['moon_sign_symbol'] as String,
      moonElement: json['moon_element'] as String,
      mercuryRetrograde: json['mercury_retrograde'] as bool,
      mercuryStatus: json['mercury_status'] as String,
      advice: json['advice'] as String,
      sunSign: json['sun_sign'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'moon_phase': moonPhase,
      'moon_phase_icon': moonPhaseIcon,
      'moon_illumination': moonIllumination,
      'moon_sign': moonSign,
      'moon_sign_symbol': moonSignSymbol,
      'moon_element': moonElement,
      'mercury_retrograde': mercuryRetrograde,
      'mercury_status': mercuryStatus,
      'advice': advice,
      'sun_sign': sunSign,
    };
  }

  /// Get the appropriate icon data for the moon phase.
  IconData get moonPhaseIconData {
    switch (moonPhaseIcon) {
      case 'new_moon':
        return Icons.dark_mode;
      case 'waxing_crescent':
        return Icons.nightlight_round;
      case 'first_quarter':
        return Icons.first_page; // Use custom icon in production
      case 'waxing_gibbous':
        return Icons.brightness_3;
      case 'full_moon':
        return Icons.circle;
      case 'waning_gibbous':
        return Icons.brightness_2;
      case 'last_quarter':
        return Icons.last_page; // Use custom icon in production
      case 'waning_crescent':
        return Icons.nightlight_outlined;
      default:
        return Icons.nightlight_round;
    }
  }

  /// Get element color for theming.
  Color get elementColor {
    switch (moonElement.toLowerCase()) {
      case 'fire':
        return const Color(0xFFFF6B35);
      case 'earth':
        return const Color(0xFF7CB342);
      case 'air':
        return const Color(0xFF64B5F6);
      case 'water':
        return const Color(0xFF26A69A);
      default:
        return const Color(0xFF9D00FF);
    }
  }
}
