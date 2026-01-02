/// Helper class for mapping tarot card names to local asset paths.
///
/// This provides a fallback image system when Visionary Mode (AI) is disabled.
/// Standard Rider-Waite style tarot deck images are used.
class TarotDeckAssets {
  TarotDeckAssets._();

  /// Base path for tarot card assets.
  static const String _basePath = 'assets/cards';

  /// Major Arcana card mappings (index -> filename).
  static const Map<int, String> _majorArcanaByIndex = {
    0: '00_fool',
    1: '01_magician',
    2: '02_high_priestess',
    3: '03_empress',
    4: '04_emperor',
    5: '05_hierophant',
    6: '06_lovers',
    7: '07_chariot',
    8: '08_strength',
    9: '09_hermit',
    10: '10_wheel_of_fortune',
    11: '11_justice',
    12: '12_hanged_man',
    13: '13_death',
    14: '14_temperance',
    15: '15_devil',
    16: '16_tower',
    17: '17_star',
    18: '18_moon',
    19: '19_sun',
    20: '20_judgement',
    21: '21_world',
  };

  /// Major Arcana card mappings (name -> filename).
  static const Map<String, String> _majorArcanaByName = {
    'the fool': '00_fool',
    'the magician': '01_magician',
    'the high priestess': '02_high_priestess',
    'the empress': '03_empress',
    'the emperor': '04_emperor',
    'the hierophant': '05_hierophant',
    'the lovers': '06_lovers',
    'the chariot': '07_chariot',
    'strength': '08_strength',
    'the hermit': '09_hermit',
    'wheel of fortune': '10_wheel_of_fortune',
    'justice': '11_justice',
    'the hanged man': '12_hanged_man',
    'death': '13_death',
    'temperance': '14_temperance',
    'the devil': '15_devil',
    'the tower': '16_tower',
    'the star': '17_star',
    'the moon': '18_moon',
    'the sun': '19_sun',
    'judgement': '20_judgement',
    'the world': '21_world',
  };

  /// Minor Arcana suits.
  static const List<String> _suits = ['wands', 'cups', 'swords', 'pentacles'];

  /// Court card names.
  static const List<String> _courtCards = ['page', 'knight', 'queen', 'king'];

  /// Get the asset path for a Major Arcana card by index.
  ///
  /// [index] should be 0-21 for the 22 Major Arcana cards.
  /// Returns the full asset path (e.g., 'assets/cards/major/00_fool.png').
  static String getMajorArcanaByIndex(int index) {
    final filename = _majorArcanaByIndex[index];
    if (filename == null) {
      return getPlaceholder();
    }
    return '$_basePath/major/$filename.png';
  }

  /// Get the asset path for a Major Arcana card by name.
  ///
  /// [name] should be the full card name (e.g., 'The Fool', 'The Magician').
  /// Case-insensitive matching is used.
  /// Returns the full asset path or placeholder if not found.
  static String getMajorArcanaByName(String name) {
    final normalizedName = name.toLowerCase().trim();
    final filename = _majorArcanaByName[normalizedName];
    if (filename == null) {
      // Try partial matching for variations
      for (final entry in _majorArcanaByName.entries) {
        if (normalizedName.contains(entry.key) || entry.key.contains(normalizedName)) {
          return '$_basePath/major/${entry.value}.png';
        }
      }
      return getPlaceholder();
    }
    return '$_basePath/major/$filename.png';
  }

  /// Get the asset path for a Minor Arcana card.
  ///
  /// [suit] should be one of: wands, cups, swords, pentacles
  /// [value] should be: ace, 2-10, page, knight, queen, king
  /// Returns the full asset path (e.g., 'assets/cards/minor/wands/ace_of_wands.png').
  static String getMinorArcana(String suit, String value) {
    final normalizedSuit = suit.toLowerCase().trim();
    final normalizedValue = value.toLowerCase().trim();

    if (!_suits.contains(normalizedSuit)) {
      return getPlaceholder();
    }

    final filename = '${normalizedValue}_of_$normalizedSuit';
    return '$_basePath/minor/$normalizedSuit/$filename.png';
  }

  /// Get the asset path for any card by its full name.
  ///
  /// Supports both Major and Minor Arcana cards.
  /// Examples:
  /// - 'The Fool' -> 'assets/cards/major/00_fool.png'
  /// - 'Ace of Cups' -> 'assets/cards/minor/cups/ace_of_cups.png'
  /// - 'Queen of Swords' -> 'assets/cards/minor/swords/queen_of_swords.png'
  static String getCardByName(String name) {
    final normalizedName = name.toLowerCase().trim();

    // Check if it's a Minor Arcana card (contains " of ")
    if (normalizedName.contains(' of ')) {
      final parts = normalizedName.split(' of ');
      if (parts.length == 2) {
        return getMinorArcana(parts[1], parts[0]);
      }
    }

    // Otherwise, treat as Major Arcana
    return getMajorArcanaByName(name);
  }

  /// Get placeholder image path for unknown cards.
  static String getPlaceholder() {
    return '$_basePath/card_back.png';
  }

  /// Get the card back image path.
  static String getCardBack() {
    return '$_basePath/card_back.png';
  }

  /// Check if asset exists for a card name.
  /// Note: This is a simple name check, not a file system check.
  static bool hasAssetForCard(String name) {
    final normalizedName = name.toLowerCase().trim();

    // Check Major Arcana
    if (_majorArcanaByName.containsKey(normalizedName)) {
      return true;
    }

    // Check for partial matches in Major Arcana
    for (final key in _majorArcanaByName.keys) {
      if (normalizedName.contains(key) || key.contains(normalizedName)) {
        return true;
      }
    }

    // Check Minor Arcana pattern
    if (normalizedName.contains(' of ')) {
      final parts = normalizedName.split(' of ');
      if (parts.length == 2) {
        final suit = parts[1].trim();
        return _suits.contains(suit);
      }
    }

    return false;
  }

  /// Get all Major Arcana asset paths.
  /// Useful for preloading/caching.
  static List<String> getAllMajorArcanaAssets() {
    return _majorArcanaByIndex.entries
        .map((e) => '$_basePath/major/${e.value}.png')
        .toList();
  }

  /// Get all asset file names that should be added to the assets folder.
  /// This is a helper for documentation purposes.
  static List<String> getRequiredAssetFiles() {
    final files = <String>[];

    // Major Arcana
    files.add('=== MAJOR ARCANA (assets/cards/major/) ===');
    for (final filename in _majorArcanaByIndex.values) {
      files.add('$filename.png');
    }

    // Minor Arcana
    for (final suit in _suits) {
      files.add('\n=== ${suit.toUpperCase()} (assets/cards/minor/$suit/) ===');
      files.add('ace_of_$suit.png');
      for (int i = 2; i <= 10; i++) {
        files.add('${i}_of_$suit.png');
      }
      for (final court in _courtCards) {
        files.add('${court}_of_$suit.png');
      }
    }

    // Card back
    files.add('\n=== CARD BACK (assets/cards/) ===');
    files.add('card_back.png');

    return files;
  }
}
