/// Models for natal chart astrology data.

/// Position of a planet in the zodiac.
class PlanetPosition {
  final String planetName;
  final String planetSymbol;
  final String sign;
  final String signSymbol;
  final int house;
  final double degree;
  final double signDegree;
  final bool isRetrograde;
  final String element;
  final String modality;
  final String? interpretation;

  const PlanetPosition({
    required this.planetName,
    required this.planetSymbol,
    required this.sign,
    required this.signSymbol,
    required this.house,
    required this.degree,
    required this.signDegree,
    this.isRetrograde = false,
    required this.element,
    required this.modality,
    this.interpretation,
  });

  factory PlanetPosition.fromJson(Map<String, dynamic> json) {
    return PlanetPosition(
      planetName: json['planet_name'] ?? '',
      planetSymbol: json['planet_symbol'] ?? '?',
      sign: json['sign'] ?? '',
      signSymbol: json['sign_symbol'] ?? '?',
      house: json['house'] ?? 1,
      degree: (json['degree'] ?? 0).toDouble(),
      signDegree: (json['sign_degree'] ?? 0).toDouble(),
      isRetrograde: json['is_retrograde'] ?? false,
      element: json['element'] ?? '',
      modality: json['modality'] ?? '',
      interpretation: json['interpretation'],
    );
  }

  Map<String, dynamic> toJson() => {
    'planet_name': planetName,
    'planet_symbol': planetSymbol,
    'sign': sign,
    'sign_symbol': signSymbol,
    'house': house,
    'degree': degree,
    'sign_degree': signDegree,
    'is_retrograde': isRetrograde,
    'element': element,
    'modality': modality,
    'interpretation': interpretation,
  };
}

/// An aspect between two planets.
class Aspect {
  final String planet1;
  final String planet2;
  final String aspectType;
  final String aspectSymbol;
  final double orb;
  final bool isApplying;
  final String? interpretation;

  const Aspect({
    required this.planet1,
    required this.planet2,
    required this.aspectType,
    required this.aspectSymbol,
    required this.orb,
    this.isApplying = false,
    this.interpretation,
  });

  factory Aspect.fromJson(Map<String, dynamic> json) {
    return Aspect(
      planet1: json['planet1'] ?? '',
      planet2: json['planet2'] ?? '',
      aspectType: json['aspect_type'] ?? '',
      aspectSymbol: json['aspect_symbol'] ?? '?',
      orb: (json['orb'] ?? 0).toDouble(),
      isApplying: json['is_applying'] ?? false,
      interpretation: json['interpretation'],
    );
  }
}

/// Complete natal chart response.
class NatalChart {
  final String? name;
  final String birthDatetime;
  final Map<String, dynamic> location;
  final PlanetPosition sun;
  final PlanetPosition moon;
  final PlanetPosition rising;
  final PlanetPosition mercury;
  final PlanetPosition venus;
  final PlanetPosition mars;
  final PlanetPosition jupiter;
  final PlanetPosition saturn;
  final PlanetPosition? uranus;
  final PlanetPosition? neptune;
  final PlanetPosition? pluto;
  final List<Aspect>? aspects;
  final String? sunMoonRisingSummary;

  const NatalChart({
    this.name,
    required this.birthDatetime,
    required this.location,
    required this.sun,
    required this.moon,
    required this.rising,
    required this.mercury,
    required this.venus,
    required this.mars,
    required this.jupiter,
    required this.saturn,
    this.uranus,
    this.neptune,
    this.pluto,
    this.aspects,
    this.sunMoonRisingSummary,
  });

  factory NatalChart.fromJson(Map<String, dynamic> json) {
    return NatalChart(
      name: json['name'],
      birthDatetime: json['birth_datetime'] ?? '',
      location: json['location'] ?? {},
      sun: PlanetPosition.fromJson(json['sun'] ?? {}),
      moon: PlanetPosition.fromJson(json['moon'] ?? {}),
      rising: PlanetPosition.fromJson(json['rising'] ?? {}),
      mercury: PlanetPosition.fromJson(json['mercury'] ?? {}),
      venus: PlanetPosition.fromJson(json['venus'] ?? {}),
      mars: PlanetPosition.fromJson(json['mars'] ?? {}),
      jupiter: PlanetPosition.fromJson(json['jupiter'] ?? {}),
      saturn: PlanetPosition.fromJson(json['saturn'] ?? {}),
      uranus: json['uranus'] != null
          ? PlanetPosition.fromJson(json['uranus'])
          : null,
      neptune: json['neptune'] != null
          ? PlanetPosition.fromJson(json['neptune'])
          : null,
      pluto: json['pluto'] != null
          ? PlanetPosition.fromJson(json['pluto'])
          : null,
      aspects: (json['aspects'] as List<dynamic>?)
          ?.map((a) => Aspect.fromJson(a))
          .toList(),
      sunMoonRisingSummary: json['sun_moon_rising_summary'],
    );
  }

  /// Get all major planets as a list for iteration.
  List<PlanetPosition> get allPlanets => [
    sun,
    moon,
    rising,
    mercury,
    venus,
    mars,
    jupiter,
    saturn,
    if (uranus != null) uranus!,
    if (neptune != null) neptune!,
    if (pluto != null) pluto!,
  ];

  /// Get element distribution.
  Map<String, int> get elementDistribution {
    final counts = <String, int>{'Fire': 0, 'Earth': 0, 'Air': 0, 'Water': 0};
    for (final planet in allPlanets) {
      counts[planet.element] = (counts[planet.element] ?? 0) + 1;
    }
    return counts;
  }

  /// Get dominant element.
  String get dominantElement {
    final dist = elementDistribution;
    return dist.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
