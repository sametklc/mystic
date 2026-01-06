/// Helper class for mapping Tarot card names to asset paths.
///
/// Handles the 22 Major Arcana cards with proper asset mapping
/// and provides fallback for Minor Arcana or unknown cards.
class TarotImageHelper {
  TarotImageHelper._();

  /// Base path for Major Arcana card images
  static const String _majorArcanaBasePath = 'assets/cards/major/';

  /// Fallback card back image path
  static const String cardBackPath = 'assets/cards/card_back.png';

  /// List of all 22 Major Arcana card names (canonical names)
  static const List<String> majorArcanaCards = [
    'The Fool',
    'The Magician',
    'The High Priestess',
    'The Empress',
    'The Emperor',
    'The Hierophant',
    'The Lovers',
    'The Chariot',
    'Strength',
    'The Hermit',
    'Wheel of Fortune',
    'Justice',
    'The Hanged Man',
    'Death',
    'Temperance',
    'The Devil',
    'The Tower',
    'The Star',
    'The Moon',
    'The Sun',
    'Judgement',
    'The World',
  ];

  /// Minor Arcana suits for detection
  static const List<String> _minorArcanaSuits = [
    'wands',
    'cups',
    'swords',
    'pentacles',
    'coins', // Alternative name for pentacles
  ];

  /// Minor Arcana ranks for detection
  static const List<String> _minorArcanaRanks = [
    'ace',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'page',
    'knight',
    'queen',
    'king',
  ];

  /// Get the asset path for a given card name.
  ///
  /// Takes the card name from the API (e.g., "The Fool", "Wheel of Fortune")
  /// and returns the corresponding asset path.
  ///
  /// For Major Arcana: Returns `assets/cards/major/{snake_case_name}.png`
  /// For Minor Arcana or unknown: Returns the card back fallback image.
  static String getCardAssetPath(String cardName) {
    // Normalize the card name
    final normalizedName = cardName.trim();

    // Check if it's a Major Arcana card
    if (isMajorArcana(normalizedName)) {
      return _getMajorArcanaPath(normalizedName);
    }

    // For Minor Arcana or unknown cards, return fallback
    return cardBackPath;
  }

  /// Check if the given card name is a Major Arcana card.
  static bool isMajorArcana(String cardName) {
    final lowerName = cardName.toLowerCase().trim();

    // Direct match check
    for (final majorCard in majorArcanaCards) {
      if (majorCard.toLowerCase() == lowerName) {
        return true;
      }
    }

    // Check for common variations
    final variations = _getMajorArcanaVariations();
    return variations.containsKey(lowerName);
  }

  /// Check if the given card name is a Minor Arcana card.
  static bool isMinorArcana(String cardName) {
    final lowerName = cardName.toLowerCase();

    // Check if it contains a suit name
    for (final suit in _minorArcanaSuits) {
      if (lowerName.contains(suit)) {
        return true;
      }
    }

    // Check for pattern like "Ace of Cups", "King of Swords"
    if (lowerName.contains(' of ')) {
      final parts = lowerName.split(' of ');
      if (parts.length == 2) {
        final rank = parts[0].trim();
        final suit = parts[1].trim();
        return _minorArcanaRanks.contains(rank) ||
            _minorArcanaSuits.any((s) => suit.contains(s));
      }
    }

    return false;
  }

  /// Asset file names mapping (index -> filename without extension)
  static const List<String> _assetFileNames = [
    '00_fool',
    '01_magician',
    '02_high_priestess',
    '03_empress',
    '04_emperor',
    '05_hierophant',
    '06_lovers',
    '07_chariot',
    '08_strength',
    '09_hermit',
    '10_wheel_of_fortune',
    '11_justice',
    '12_hanged_man',
    '13_death',
    '14_temperance',
    '15_devil',
    '16_tower',
    '17_star',
    '18_moon',
    '19_sun',
    '20_judgement',
    '21_world',
  ];

  /// Convert card name to snake_case file path for Major Arcana.
  static String _getMajorArcanaPath(String cardName) {
    // Get the card index (0-21)
    final index = getMajorArcanaNumber(cardName);

    if (index >= 0 && index < _assetFileNames.length) {
      return '$_majorArcanaBasePath${_assetFileNames[index]}.png';
    }

    // Fallback to card back if not found
    return cardBackPath;
  }

  /// Get a map of common card name variations to canonical names.
  static Map<String, String> _getMajorArcanaVariations() {
    return {
      // The Fool variations
      'the fool': 'The Fool',
      'fool': 'The Fool',
      '0 the fool': 'The Fool',

      // The Magician variations
      'the magician': 'The Magician',
      'magician': 'The Magician',
      'i the magician': 'The Magician',

      // The High Priestess variations
      'the high priestess': 'The High Priestess',
      'high priestess': 'The High Priestess',
      'the priestess': 'The High Priestess',
      'ii the high priestess': 'The High Priestess',

      // The Empress variations
      'the empress': 'The Empress',
      'empress': 'The Empress',
      'iii the empress': 'The Empress',

      // The Emperor variations
      'the emperor': 'The Emperor',
      'emperor': 'The Emperor',
      'iv the emperor': 'The Emperor',

      // The Hierophant variations
      'the hierophant': 'The Hierophant',
      'hierophant': 'The Hierophant',
      'the pope': 'The Hierophant',
      'v the hierophant': 'The Hierophant',

      // The Lovers variations
      'the lovers': 'The Lovers',
      'lovers': 'The Lovers',
      'vi the lovers': 'The Lovers',

      // The Chariot variations
      'the chariot': 'The Chariot',
      'chariot': 'The Chariot',
      'vii the chariot': 'The Chariot',

      // Strength variations
      'strength': 'Strength',
      'viii strength': 'Strength',
      'fortitude': 'Strength',

      // The Hermit variations
      'the hermit': 'The Hermit',
      'hermit': 'The Hermit',
      'ix the hermit': 'The Hermit',

      // Wheel of Fortune variations
      'wheel of fortune': 'Wheel of Fortune',
      'the wheel of fortune': 'Wheel of Fortune',
      'wheel': 'Wheel of Fortune',
      'x wheel of fortune': 'Wheel of Fortune',

      // Justice variations
      'justice': 'Justice',
      'xi justice': 'Justice',

      // The Hanged Man variations
      'the hanged man': 'The Hanged Man',
      'hanged man': 'The Hanged Man',
      'xii the hanged man': 'The Hanged Man',

      // Death variations
      'death': 'Death',
      'xiii death': 'Death',
      'the death': 'Death',

      // Temperance variations
      'temperance': 'Temperance',
      'xiv temperance': 'Temperance',

      // The Devil variations
      'the devil': 'The Devil',
      'devil': 'The Devil',
      'xv the devil': 'The Devil',

      // The Tower variations
      'the tower': 'The Tower',
      'tower': 'The Tower',
      'xvi the tower': 'The Tower',

      // The Star variations
      'the star': 'The Star',
      'star': 'The Star',
      'xvii the star': 'The Star',

      // The Moon variations
      'the moon': 'The Moon',
      'moon': 'The Moon',
      'xviii the moon': 'The Moon',

      // The Sun variations
      'the sun': 'The Sun',
      'sun': 'The Sun',
      'xix the sun': 'The Sun',

      // Judgement variations
      'judgement': 'Judgement',
      'judgment': 'Judgement', // American spelling
      'xx judgement': 'Judgement',
      'the judgement': 'Judgement',

      // The World variations
      'the world': 'The World',
      'world': 'The World',
      'xxi the world': 'The World',
    };
  }

  /// Get the card number (0-21) for a Major Arcana card.
  /// Returns -1 if not found.
  static int getMajorArcanaNumber(String cardName) {
    final lowerName = cardName.toLowerCase().trim();
    final variations = _getMajorArcanaVariations();

    String canonicalName;
    if (variations.containsKey(lowerName)) {
      canonicalName = variations[lowerName]!;
    } else {
      canonicalName = cardName;
    }

    final index = majorArcanaCards.indexWhere(
      (card) => card.toLowerCase() == canonicalName.toLowerCase(),
    );

    return index;
  }

  /// Get the display name for a card (canonical form).
  static String getDisplayName(String cardName) {
    final lowerName = cardName.toLowerCase().trim();
    final variations = _getMajorArcanaVariations();

    if (variations.containsKey(lowerName)) {
      return variations[lowerName]!;
    }

    // Return original if not found in variations
    return cardName;
  }
}
