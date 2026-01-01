import '../domain/models/character_model.dart';

/// Mock character data structured like a Firestore response.
/// Acts as a local cache until Firebase integration is complete.
abstract class CharacterData {
  CharacterData._();

  /// Static list of all available tarot reader characters.
  /// Structured to mirror Firestore document format.
  static const List<CharacterModel> characters = [
    CharacterModel(
      id: 'madame_luna',
      name: 'Madame Luna',
      title: 'The Moon Child',
      description:
          'Intuitive and warm, Madame Luna channels the energy of the moon '
          'to guide you through matters of the heart. Her readings focus on '
          'love, relationships, and emotional connections.',
      imagePath: 'assets/images/characters/madame_luna.png',
      isLocked: false,
      themeColorHex: '#9D00FF', // Electric Purple
    ),
    CharacterModel(
      id: 'elder_weiss',
      name: 'Elder Weiss',
      title: 'The Ancient Sage',
      description:
          'With centuries of wisdom, Elder Weiss offers profound insights '
          'into your career and life path. His readings illuminate the road '
          'ahead and help you find your true calling.',
      imagePath: 'assets/images/characters/elder_weiss.png',
      isLocked: true,
      themeColorHex: '#FFD700', // Gold
    ),
    CharacterModel(
      id: 'nova',
      name: 'Nova',
      title: 'The Stargazer',
      description:
          'A futuristic oracle who blends cold logic with ancient astrology. '
          'Nova analyzes cosmic patterns to deliver precise, data-driven '
          'predictions about your future.',
      imagePath: 'assets/images/characters/nova.png',
      isLocked: true,
      themeColorHex: '#00FFFF', // Cyan
    ),
    CharacterModel(
      id: 'shadow',
      name: 'Shadow',
      title: 'The Truth Seeker',
      description:
          'Shadow does not sugarcoat. This brutally honest oracle reveals '
          'the dark truths you need to hear, exposing hidden obstacles and '
          'uncomfortable realities on your path.',
      imagePath: 'assets/images/characters/shadow.png',
      isLocked: true,
      themeColorHex: '#FF0033', // Deep Red
    ),
  ];

  /// Simulates a Firestore response format.
  /// Returns character data as a list of JSON maps.
  static List<Map<String, dynamic>> toFirestoreFormat() {
    return characters.map((c) => c.toJson()).toList();
  }

  /// Finds a character by ID, returns null if not found.
  static CharacterModel? findById(String id) {
    try {
      return characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns only unlocked (free) characters.
  static List<CharacterModel> get freeCharacters {
    return characters.where((c) => !c.isLocked).toList();
  }

  /// Returns only locked (premium) characters.
  static List<CharacterModel> get lockedCharacters {
    return characters.where((c) => c.isLocked).toList();
  }
}
