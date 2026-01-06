import 'package:flutter/material.dart';

/// Enum representing the feature/capability each persona handles.
enum PersonaFeature {
  /// Tarot card readings and interpretations
  tarot,

  /// Horoscope and astrology insights
  horoscope,

  /// Love compatibility and relationship advice
  loveMatch,

  /// Daily wisdom and sanctuary features
  dailyWisdom,

  /// General spiritual guidance
  general,
}

/// Model representing an AI persona for the iOS chat interface.
///
/// These personas are presented as AI companions/guides designed
/// for App Store compliance - no fortune-telling terminology.
///
/// Each persona maps to specific app features:
/// - Mystic → Tarot features
/// - Nova → Horoscope/Astrology
/// - Rose → Love Match
/// - Astra → Daily Wisdom/Sanctuary
class AIPersona {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String imagePath;
  final Color themeColor;
  final Color gradientStart;
  final Color gradientEnd;
  final String characterId;
  final String lastMessage;
  final String welcomeMessage;
  final PersonaFeature feature;
  final bool isPremium;
  final IconData icon;

  const AIPersona({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.imagePath,
    required this.themeColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.characterId,
    required this.lastMessage,
    required this.welcomeMessage,
    required this.feature,
    required this.icon,
    this.isPremium = false,
  });

  /// List of all available AI personas.
  /// Designed to look like messaging app contacts.
  static const List<AIPersona> personas = [
    // Mystic - Spiritual Guide (Tarot)
    AIPersona(
      id: 'mystic',
      name: 'Mystic',
      subtitle: 'Spiritual Guide',
      description: 'Your personal spiritual companion for card-based insights and intuitive guidance.',
      imagePath: 'assets/images/guides/mystic.png',
      themeColor: Color(0xFF9D00FF),
      gradientStart: Color(0xFF9D00FF),
      gradientEnd: Color(0xFF6B00B3),
      characterId: 'madame_luna',
      lastMessage: 'Ready for your reading? ✨',
      welcomeMessage: 'Welcome, seeker. I\'m Mystic, your spiritual guide. I\'m here to help you explore life\'s questions through symbolic insights. What would you like to explore today?',
      feature: PersonaFeature.tarot,
      icon: Icons.auto_awesome,
      isPremium: false,
    ),

    // Nova - Astro Guide (Horoscope)
    AIPersona(
      id: 'nova',
      name: 'Nova',
      subtitle: 'Astro Guide',
      description: 'Your cosmic companion for daily insights and celestial guidance based on the stars.',
      imagePath: 'assets/images/guides/nova.png',
      themeColor: Color(0xFF00D4FF),
      gradientStart: Color(0xFF00D4FF),
      gradientEnd: Color(0xFF0099CC),
      characterId: 'nova',
      lastMessage: 'The stars have something for you 🌟',
      welcomeMessage: 'Hey! I\'m Nova, your astro guide. I decode cosmic patterns to help you understand your journey. Ready to explore what the universe has in store?',
      feature: PersonaFeature.horoscope,
      icon: Icons.stars_rounded,
      isPremium: false,
    ),

    // Rose - Relationship Coach (Love Match)
    AIPersona(
      id: 'rose',
      name: 'Rose',
      subtitle: 'Relationship Coach',
      description: 'Your compassionate guide for matters of the heart, relationships, and emotional connections.',
      imagePath: 'assets/images/guides/rose.png',
      themeColor: Color(0xFFFF6B9D),
      gradientStart: Color(0xFFFF6B9D),
      gradientEnd: Color(0xFFE91E63),
      characterId: 'madame_luna',
      lastMessage: 'Let\'s talk about love 💕',
      welcomeMessage: 'Hi there, I\'m Rose. I specialize in matters of the heart - relationships, connections, and understanding love. What\'s on your heart today?',
      feature: PersonaFeature.loveMatch,
      icon: Icons.favorite_rounded,
      isPremium: false,
    ),

    // Astra - Daily Wisdom (Sanctuary)
    AIPersona(
      id: 'astra',
      name: 'Astra',
      subtitle: 'Daily Wisdom',
      description: 'Your everyday companion for motivation, mindfulness, and daily inspiration.',
      imagePath: 'assets/images/guides/astra.png',
      themeColor: Color(0xFFFFD700),
      gradientStart: Color(0xFFFFD700),
      gradientEnd: Color(0xFFFF9500),
      characterId: 'elder_weiss',
      lastMessage: 'Your daily insight awaits ☀️',
      welcomeMessage: 'Good to see you! I\'m Astra, here to bring daily wisdom and positive energy into your life. What kind of guidance would brighten your day?',
      feature: PersonaFeature.dailyWisdom,
      icon: Icons.wb_sunny_rounded,
      isPremium: false,
    ),
  ];

  /// Find a persona by ID
  static AIPersona? findById(String id) {
    try {
      return personas.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find a persona by character ID
  static AIPersona? findByCharacterId(String characterId) {
    try {
      return personas.firstWhere((p) => p.characterId == characterId);
    } catch (_) {
      return null;
    }
  }

  /// Find a persona by feature
  static AIPersona? findByFeature(PersonaFeature feature) {
    try {
      return personas.firstWhere((p) => p.feature == feature);
    } catch (_) {
      return null;
    }
  }

  /// Get gradient for avatar
  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [gradientStart, gradientEnd],
      );
}
