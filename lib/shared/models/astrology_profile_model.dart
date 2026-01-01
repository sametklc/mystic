/// Represents a zodiac sign
enum ZodiacSign {
  aries('Koç', 'Aries', '♈'),
  taurus('Boğa', 'Taurus', '♉'),
  gemini('İkizler', 'Gemini', '♊'),
  cancer('Yengeç', 'Cancer', '♋'),
  leo('Aslan', 'Leo', '♌'),
  virgo('Başak', 'Virgo', '♍'),
  libra('Terazi', 'Libra', '♎'),
  scorpio('Akrep', 'Scorpio', '♏'),
  sagittarius('Yay', 'Sagittarius', '♐'),
  capricorn('Oğlak', 'Capricorn', '♑'),
  aquarius('Kova', 'Aquarius', '♒'),
  pisces('Balık', 'Pisces', '♓');

  final String turkishName;
  final String englishName;
  final String symbol;

  const ZodiacSign(this.turkishName, this.englishName, this.symbol);
}

/// Represents a celestial body in astrology
enum CelestialBody {
  sun('Güneş', 'Sun', '☉'),
  moon('Ay', 'Moon', '☽'),
  mercury('Merkür', 'Mercury', '☿'),
  venus('Venüs', 'Venus', '♀'),
  mars('Mars', 'Mars', '♂'),
  jupiter('Jüpiter', 'Jupiter', '♃'),
  saturn('Satürn', 'Saturn', '♄'),
  uranus('Uranüs', 'Uranus', '♅'),
  neptune('Neptün', 'Neptune', '♆'),
  pluto('Plüton', 'Pluto', '♇'),
  ascendant('Yükselen', 'Ascendant', 'AC'),
  midheaven('Gökyüzü Ortası', 'Midheaven', 'MC');

  final String turkishName;
  final String englishName;
  final String symbol;

  const CelestialBody(this.turkishName, this.englishName, this.symbol);
}

/// Represents a planetary placement in a birth chart
class PlanetaryPlacement {
  final CelestialBody body;
  final ZodiacSign sign;
  final int degree;
  final int house;

  const PlanetaryPlacement({
    required this.body,
    required this.sign,
    required this.degree,
    required this.house,
  });

  String get formattedPosition => '${sign.symbol} ${degree}°';
}

/// Represents the user's complete astrological profile
class AstrologyProfileModel {
  /// Sun sign - Core identity
  final ZodiacSign sunSign;

  /// Moon sign - Emotional nature
  final ZodiacSign moonSign;

  /// Rising/Ascendant sign - Outer personality
  final ZodiacSign ascendantSign;

  /// All planetary placements
  final List<PlanetaryPlacement> placements;

  /// Dominant element (Fire, Earth, Air, Water)
  final String dominantElement;

  /// Dominant modality (Cardinal, Fixed, Mutable)
  final String dominantModality;

  /// Generated aura description
  final String auraDescription;

  /// Power level (1-100) - for dramatic effect
  final int powerLevel;

  const AstrologyProfileModel({
    required this.sunSign,
    required this.moonSign,
    required this.ascendantSign,
    required this.placements,
    required this.dominantElement,
    required this.dominantModality,
    required this.auraDescription,
    required this.powerLevel,
  });

  /// Get the main three signs as formatted string
  String get mainSignsFormatted =>
      'Güneş: ${sunSign.turkishName} | Ay: ${moonSign.turkishName} | Yükselen: ${ascendantSign.turkishName}';

  /// Get short cosmic signature
  String get cosmicSignature =>
      '${sunSign.symbol} ${moonSign.symbol} ${ascendantSign.symbol}';
}
