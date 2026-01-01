import 'dart:math';

import '../models/astrology_profile_model.dart';
import '../models/birth_data_model.dart';

/// Mock astrology calculation service.
/// In production, this would connect to a real ephemeris API or library.
class AstrologyService {
  static final Random _random = Random();

  /// List of mystical aura descriptions
  static const List<String> _auraDescriptions = [
    'Güçlü bir auran var. Kozmik enerjiler seni seçti.',
    'Yıldızlar senin için özel bir yol çizmiş.',
    'Nadir görülen bir enerji taşıyorsun.',
    'Kadim bilgelik ruhunda yankılanıyor.',
    'Evrenin gizli mesajlarını algılayabilirsin.',
    'Mistik bir güç seninle birlikte doğmuş.',
    'Kozmik bir hediye taşıyorsun içinde.',
    'Yıldızların rehberliğinde yürüyorsun.',
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
        return 'Ateş';
      case ZodiacSign.taurus:
      case ZodiacSign.virgo:
      case ZodiacSign.capricorn:
        return 'Toprak';
      case ZodiacSign.gemini:
      case ZodiacSign.libra:
      case ZodiacSign.aquarius:
        return 'Hava';
      case ZodiacSign.cancer:
      case ZodiacSign.scorpio:
      case ZodiacSign.pisces:
        return 'Su';
    }
  }

  /// Get modality for a zodiac sign
  static String _getModality(ZodiacSign sign) {
    switch (sign) {
      case ZodiacSign.aries:
      case ZodiacSign.cancer:
      case ZodiacSign.libra:
      case ZodiacSign.capricorn:
        return 'Öncü';
      case ZodiacSign.taurus:
      case ZodiacSign.leo:
      case ZodiacSign.scorpio:
      case ZodiacSign.aquarius:
        return 'Sabit';
      case ZodiacSign.gemini:
      case ZodiacSign.virgo:
      case ZodiacSign.sagittarius:
      case ZodiacSign.pisces:
        return 'Değişken';
    }
  }
}
