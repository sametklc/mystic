import 'natal_chart_model.dart';

/// Detailed 3-section AI analysis for synastry.
class DetailedAnalysis {
  final String chemistryAnalysis;
  final String emotionalConnection;
  final String challenges;
  final String summary;

  const DetailedAnalysis({
    required this.chemistryAnalysis,
    required this.emotionalConnection,
    required this.challenges,
    required this.summary,
  });

  factory DetailedAnalysis.fromJson(Map<String, dynamic> json) {
    return DetailedAnalysis(
      chemistryAnalysis: json['chemistry_analysis'] ?? '',
      emotionalConnection: json['emotional_connection'] ?? '',
      challenges: json['challenges'] ?? '',
      summary: json['summary'] ?? '',
    );
  }

  bool get hasContent =>
      chemistryAnalysis.isNotEmpty ||
      emotionalConnection.isNotEmpty ||
      challenges.isNotEmpty;
}

/// An aspect between two people's charts.
class SynastryAspect {
  final String person1Planet;
  final String person2Planet;
  final String aspectType;
  final String aspectSymbol;
  final double orb;
  final int harmonyScore;
  final String interpretation;

  const SynastryAspect({
    required this.person1Planet,
    required this.person2Planet,
    required this.aspectType,
    required this.aspectSymbol,
    required this.orb,
    required this.harmonyScore,
    required this.interpretation,
  });

  factory SynastryAspect.fromJson(Map<String, dynamic> json) {
    return SynastryAspect(
      person1Planet: json['person1_planet'] ?? '',
      person2Planet: json['person2_planet'] ?? '',
      aspectType: json['aspect_type'] ?? '',
      aspectSymbol: json['aspect_symbol'] ?? '?',
      orb: (json['orb'] ?? 0).toDouble(),
      harmonyScore: json['harmony_score'] ?? 0,
      interpretation: json['interpretation'] ?? '',
    );
  }

  bool get isHarmonious => harmonyScore > 0;
  bool get isChallenging => harmonyScore < 0;
}

/// Complete synastry compatibility report.
class SynastryReport {
  final String? user1Name;
  final String? user2Name;
  final int compatibilityScore;
  final int emotionalCompatibility;
  final int intellectualCompatibility;
  final int physicalCompatibility;
  final int spiritualCompatibility;
  final List<SynastryAspect> keyAspects;
  final int harmoniousAspectsCount;
  final int challengingAspectsCount;
  final NatalChart user1Chart;
  final NatalChart user2Chart;
  final String aiSummaryPrompt;
  final String? aiSummary;
  final DetailedAnalysis? detailedAnalysis;

  const SynastryReport({
    this.user1Name,
    this.user2Name,
    required this.compatibilityScore,
    required this.emotionalCompatibility,
    required this.intellectualCompatibility,
    required this.physicalCompatibility,
    required this.spiritualCompatibility,
    required this.keyAspects,
    required this.harmoniousAspectsCount,
    required this.challengingAspectsCount,
    required this.user1Chart,
    required this.user2Chart,
    required this.aiSummaryPrompt,
    this.aiSummary,
    this.detailedAnalysis,
  });

  factory SynastryReport.fromJson(Map<String, dynamic> json) {
    return SynastryReport(
      user1Name: json['user1_name'],
      user2Name: json['user2_name'],
      compatibilityScore: json['compatibility_score'] ?? 0,
      emotionalCompatibility: json['emotional_compatibility'] ?? 0,
      intellectualCompatibility: json['intellectual_compatibility'] ?? 0,
      physicalCompatibility: json['physical_compatibility'] ?? 0,
      spiritualCompatibility: json['spiritual_compatibility'] ?? 0,
      keyAspects: (json['key_aspects'] as List<dynamic>?)
              ?.map((a) => SynastryAspect.fromJson(a))
              .toList() ??
          [],
      harmoniousAspectsCount: json['harmonious_aspects_count'] ?? 0,
      challengingAspectsCount: json['challenging_aspects_count'] ?? 0,
      user1Chart: NatalChart.fromJson(json['user1_chart'] ?? {}),
      user2Chart: NatalChart.fromJson(json['user2_chart'] ?? {}),
      aiSummaryPrompt: json['ai_summary_prompt'] ?? '',
      aiSummary: json['ai_summary'],
      detailedAnalysis: json['detailed_analysis'] != null
          ? DetailedAnalysis.fromJson(json['detailed_analysis'])
          : null,
    );
  }

  /// Get compatibility level description.
  String get compatibilityLevel {
    if (compatibilityScore >= 80) return 'Soulmate Connection';
    if (compatibilityScore >= 60) return 'Strong Bond';
    if (compatibilityScore >= 40) return 'Growing Together';
    if (compatibilityScore >= 20) return 'Learning Curve';
    return 'Challenging Path';
  }

  /// Get compatibility color (for UI).
  int get compatibilityColorValue {
    if (compatibilityScore >= 80) return 0xFF00FF88; // Green
    if (compatibilityScore >= 60) return 0xFF88FF00; // Yellow-Green
    if (compatibilityScore >= 40) return 0xFFFFCC00; // Yellow
    if (compatibilityScore >= 20) return 0xFFFF8800; // Orange
    return 0xFFFF4444; // Red
  }
}
