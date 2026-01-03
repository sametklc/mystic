import 'dart:math';

import '../models/astrology_profile_model.dart';
import '../models/birth_data_model.dart';

/// Moon phase data model
class MoonPhaseData {
  final String name;
  final String emoji;
  final double illumination;

  const MoonPhaseData({
    required this.name,
    required this.emoji,
    required this.illumination,
  });
}

/// Mock astrology calculation service.
/// In production, this would connect to a real ephemeris API or library.
class AstrologyService {
  static final Random _random = Random();

  /// Calculate moon phase for a given date
  static MoonPhaseData getMoonPhase(DateTime date) {
    // Lunar cycle is approximately 29.53 days
    // Reference new moon: January 6, 2000
    final referenceNewMoon = DateTime(2000, 1, 6, 18, 14);
    final daysSinceNewMoon = date.difference(referenceNewMoon).inDays.toDouble();
    final lunarCycle = 29.53;

    // Calculate position in lunar cycle (0 to 1)
    final cyclePosition = (daysSinceNewMoon % lunarCycle) / lunarCycle;

    // Determine phase based on position
    if (cyclePosition < 0.0625) {
      return const MoonPhaseData(name: 'New Moon', emoji: '🌑', illumination: 0.0);
    } else if (cyclePosition < 0.1875) {
      return const MoonPhaseData(name: 'Waxing Crescent', emoji: '🌒', illumination: 0.25);
    } else if (cyclePosition < 0.3125) {
      return const MoonPhaseData(name: 'First Quarter', emoji: '🌓', illumination: 0.5);
    } else if (cyclePosition < 0.4375) {
      return const MoonPhaseData(name: 'Waxing Gibbous', emoji: '🌔', illumination: 0.75);
    } else if (cyclePosition < 0.5625) {
      return const MoonPhaseData(name: 'Full Moon', emoji: '🌕', illumination: 1.0);
    } else if (cyclePosition < 0.6875) {
      return const MoonPhaseData(name: 'Waning Gibbous', emoji: '🌖', illumination: 0.75);
    } else if (cyclePosition < 0.8125) {
      return const MoonPhaseData(name: 'Last Quarter', emoji: '🌗', illumination: 0.5);
    } else if (cyclePosition < 0.9375) {
      return const MoonPhaseData(name: 'Waning Crescent', emoji: '🌘', illumination: 0.25);
    } else {
      return const MoonPhaseData(name: 'New Moon', emoji: '🌑', illumination: 0.0);
    }
  }

  /// List of mystical aura descriptions
  static const List<String> _auraDescriptions = [
    'You possess a powerful aura. The cosmic energies have chosen you.',
    'The stars have drawn a special path just for you.',
    'You carry a rare and unique energy within.',
    'Ancient wisdom echoes through your soul.',
    'You can perceive the hidden messages of the universe.',
    'A mystical power was born alongside you.',
    'You carry a cosmic gift deep within.',
    'You walk under the guidance of the stars.',
  ];

  /// Calculate astrological profile from birth data (MOCK)
  /// In reality, this requires complex ephemeris calculations.
  static Future<AstrologyProfileModel> calculateProfile(
    BirthDataModel birthData,
  ) async {
    // Simulate calculation delay for dramatic effect
    await Future.delayed(const Duration(milliseconds: 500));

    // Get sun sign from birth date (simplified - real calculation is more complex)
    final sunSign = _getSunSignFromDate(birthData.birthDate!);

    // Mock moon and ascendant (would require precise calculations)
    final moonSign = _getRandomSign(exclude: sunSign);
    final ascendantSign = _getRandomSign(exclude: sunSign);

    // Generate mock placements
    final placements = _generateMockPlacements(sunSign, moonSign, ascendantSign);

    // Determine dominant element based on sun sign
    final dominantElement = _getElement(sunSign);

    // Determine dominant modality
    final dominantModality = _getModality(sunSign);

    // Pick a random aura description
    final auraDescription =
        _auraDescriptions[_random.nextInt(_auraDescriptions.length)];

    // Generate power level (70-99 for dramatic effect)
    final powerLevel = 70 + _random.nextInt(30);

    return AstrologyProfileModel(
      sunSign: sunSign,
      moonSign: moonSign,
      ascendantSign: ascendantSign,
      placements: placements,
      dominantElement: dominantElement,
      dominantModality: dominantModality,
      auraDescription: auraDescription,
      powerLevel: powerLevel,
    );
  }

  /// Get sun sign from birth date (simplified Western astrology dates)
  static ZodiacSign _getSunSignFromDate(DateTime date) {
    final month = date.month;
    final day = date.day;

    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) {
      return ZodiacSign.aries;
    } else if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) {
      return ZodiacSign.taurus;
    } else if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) {
      return ZodiacSign.gemini;
    } else if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) {
      return ZodiacSign.cancer;
    } else if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) {
      return ZodiacSign.leo;
    } else if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) {
      return ZodiacSign.virgo;
    } else if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) {
      return ZodiacSign.libra;
    } else if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) {
      return ZodiacSign.scorpio;
    } else if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      return ZodiacSign.sagittarius;
    } else if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
      return ZodiacSign.capricorn;
    } else if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) {
      return ZodiacSign.aquarius;
    } else {
      return ZodiacSign.pisces;
    }
  }

  /// Get a random zodiac sign, optionally excluding one
  static ZodiacSign _getRandomSign({ZodiacSign? exclude}) {
    final signs = ZodiacSign.values.where((s) => s != exclude).toList();
    return signs[_random.nextInt(signs.length)];
  }

  /// Generate mock planetary placements
  static List<PlanetaryPlacement> _generateMockPlacements(
    ZodiacSign sun,
    ZodiacSign moon,
    ZodiacSign ascendant,
  ) {
    return [
      PlanetaryPlacement(
        body: CelestialBody.sun,
        sign: sun,
        degree: _random.nextInt(30),
        house: 1 + _random.nextInt(12),
      ),
      PlanetaryPlacement(
        body: CelestialBody.moon,
        sign: moon,
        degree: _random.nextInt(30),
        house: 1 + _random.nextInt(12),
      ),
      PlanetaryPlacement(
        body: CelestialBody.ascendant,
        sign: ascendant,
        degree: _random.nextInt(30),
        house: 1,
      ),
      PlanetaryPlacement(
        body: CelestialBody.mercury,
        sign: _getRandomSign(),
        degree: _random.nextInt(30),
        house: 1 + _random.nextInt(12),
      ),
      PlanetaryPlacement(
        body: CelestialBody.venus,
        sign: _getRandomSign(),
        degree: _random.nextInt(30),
        house: 1 + _random.nextInt(12),
      ),
      PlanetaryPlacement(
        body: CelestialBody.mars,
        sign: _getRandomSign(),
        degree: _random.nextInt(30),
        house: 1 + _random.nextInt(12),
      ),
    ];
  }

  /// Get element for a zodiac sign
  static String _getElement(ZodiacSign sign) {
    switch (sign) {
      case ZodiacSign.aries:
      case ZodiacSign.leo:
      case ZodiacSign.sagittarius:
        return 'Fire';
      case ZodiacSign.taurus:
      case ZodiacSign.virgo:
      case ZodiacSign.capricorn:
        return 'Earth';
      case ZodiacSign.gemini:
      case ZodiacSign.libra:
      case ZodiacSign.aquarius:
        return 'Air';
      case ZodiacSign.cancer:
      case ZodiacSign.scorpio:
      case ZodiacSign.pisces:
        return 'Water';
    }
  }

  /// Get modality for a zodiac sign
  static String _getModality(ZodiacSign sign) {
    switch (sign) {
      case ZodiacSign.aries:
      case ZodiacSign.cancer:
      case ZodiacSign.libra:
      case ZodiacSign.capricorn:
        return 'Cardinal';
      case ZodiacSign.taurus:
      case ZodiacSign.leo:
      case ZodiacSign.scorpio:
      case ZodiacSign.aquarius:
        return 'Fixed';
      case ZodiacSign.gemini:
      case ZodiacSign.virgo:
      case ZodiacSign.sagittarius:
      case ZodiacSign.pisces:
        return 'Mutable';
    }
  }
}
