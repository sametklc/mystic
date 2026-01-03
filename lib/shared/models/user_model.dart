/// Represents the user's profile in the Mystic app.
/// This is a simple model for now, can be expanded with more spiritual preferences.
class UserModel {
  /// The name the user wishes to be called
  final String? name;

  /// User's gender (female, male, other)
  final String? gender;

  /// When the user first joined their spiritual journey
  final DateTime? joinedAt;

  /// Whether the user has completed onboarding
  final bool hasCompletedOnboarding;

  /// Profile image URL (Firebase Storage)
  final String? profileImageUrl;

  /// Birth date in YYYY-MM-DD format
  final String? birthDate;

  /// Birth time in HH:MM format (24h)
  final String? birthTime;

  /// Birth location latitude
  final double? birthLatitude;

  /// Birth location longitude
  final double? birthLongitude;

  /// Birth location timezone
  final String? birthTimezone;

  /// Birth location city name
  final String? birthCity;

  /// User's sun sign (calculated from birth data)
  final String? sunSign;

  /// User's rising sign (calculated from birth data)
  final String? risingSign;

  /// User's moon sign (calculated from birth data)
  final String? moonSign;

  /// User's relationship status
  final String? relationshipStatus;

  /// User's spiritual intentions (list of intention keys)
  final List<String>? intentions;

  /// User's esoteric knowledge level (novice, seeker, adept)
  final String? knowledgeLevel;

  /// User's preferred reading tone (gentle, brutal)
  final String? preferredTone;

  const UserModel({
    this.name,
    this.gender,
    this.joinedAt,
    this.hasCompletedOnboarding = false,
    this.profileImageUrl,
    this.birthDate,
    this.birthTime,
    this.birthLatitude,
    this.birthLongitude,
    this.birthTimezone,
    this.birthCity,
    this.sunSign,
    this.risingSign,
    this.moonSign,
    this.relationshipStatus,
    this.intentions,
    this.knowledgeLevel,
    this.preferredTone,
  });

  /// Creates an empty user (initial state)
  const UserModel.initial()
      : name = null,
        gender = null,
        joinedAt = null,
        hasCompletedOnboarding = false,
        profileImageUrl = null,
        birthDate = null,
        birthTime = null,
        birthLatitude = null,
        birthLongitude = null,
        birthTimezone = null,
        birthCity = null,
        sunSign = null,
        risingSign = null,
        moonSign = null,
        relationshipStatus = null,
        intentions = null,
        knowledgeLevel = null,
        preferredTone = null;

  /// Creates a copy with updated fields
  UserModel copyWith({
    String? name,
    String? gender,
    DateTime? joinedAt,
    bool? hasCompletedOnboarding,
    String? profileImageUrl,
    String? birthDate,
    String? birthTime,
    double? birthLatitude,
    double? birthLongitude,
    String? birthTimezone,
    String? birthCity,
    String? sunSign,
    String? risingSign,
    String? moonSign,
    String? relationshipStatus,
    List<String>? intentions,
    String? knowledgeLevel,
    String? preferredTone,
  }) {
    return UserModel(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      joinedAt: joinedAt ?? this.joinedAt,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      birthLatitude: birthLatitude ?? this.birthLatitude,
      birthLongitude: birthLongitude ?? this.birthLongitude,
      birthTimezone: birthTimezone ?? this.birthTimezone,
      birthCity: birthCity ?? this.birthCity,
      sunSign: sunSign ?? this.sunSign,
      risingSign: risingSign ?? this.risingSign,
      moonSign: moonSign ?? this.moonSign,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      intentions: intentions ?? this.intentions,
      knowledgeLevel: knowledgeLevel ?? this.knowledgeLevel,
      preferredTone: preferredTone ?? this.preferredTone,
    );
  }

  /// Get user's initials for avatar fallback
  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  /// Check if user has a profile image
  bool get hasProfileImage => profileImageUrl != null && profileImageUrl!.isNotEmpty;

  /// Check if the user has entered their name
  bool get hasName => name != null && name!.isNotEmpty;

  /// Check if user has complete birth data for astrology
  bool get hasBirthData => birthDate != null && birthLatitude != null;

  @override
  String toString() => 'UserModel(name: $name, birthDate: $birthDate, sunSign: $sunSign)';
}
