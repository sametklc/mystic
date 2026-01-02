/// Represents the user's profile in the Mystic app.
/// This is a simple model for now, can be expanded with more spiritual preferences.
class UserModel {
  /// The name the user wishes to be called
  final String? name;

  /// When the user first joined their spiritual journey
  final DateTime? joinedAt;

  /// Whether the user has completed onboarding
  final bool hasCompletedOnboarding;

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

  const UserModel({
    this.name,
    this.joinedAt,
    this.hasCompletedOnboarding = false,
    this.birthDate,
    this.birthTime,
    this.birthLatitude,
    this.birthLongitude,
    this.birthTimezone,
    this.birthCity,
    this.sunSign,
    this.risingSign,
  });

  /// Creates an empty user (initial state)
  const UserModel.initial()
      : name = null,
        joinedAt = null,
        hasCompletedOnboarding = false,
        birthDate = null,
        birthTime = null,
        birthLatitude = null,
        birthLongitude = null,
        birthTimezone = null,
        birthCity = null,
        sunSign = null,
        risingSign = null;

  /// Creates a copy with updated fields
  UserModel copyWith({
    String? name,
    DateTime? joinedAt,
    bool? hasCompletedOnboarding,
    String? birthDate,
    String? birthTime,
    double? birthLatitude,
    double? birthLongitude,
    String? birthTimezone,
    String? birthCity,
    String? sunSign,
    String? risingSign,
  }) {
    return UserModel(
      name: name ?? this.name,
      joinedAt: joinedAt ?? this.joinedAt,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      birthLatitude: birthLatitude ?? this.birthLatitude,
      birthLongitude: birthLongitude ?? this.birthLongitude,
      birthTimezone: birthTimezone ?? this.birthTimezone,
      birthCity: birthCity ?? this.birthCity,
      sunSign: sunSign ?? this.sunSign,
      risingSign: risingSign ?? this.risingSign,
    );
  }

  /// Check if the user has entered their name
  bool get hasName => name != null && name!.isNotEmpty;

  /// Check if user has complete birth data for astrology
  bool get hasBirthData => birthDate != null && birthLatitude != null;

  @override
  String toString() => 'UserModel(name: $name, birthDate: $birthDate, sunSign: $sunSign)';
}
