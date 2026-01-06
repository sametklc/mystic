import 'package:uuid/uuid.dart';

/// Represents a user profile within the Mystic app.
/// A single account (device ID) can have multiple profiles.
class ProfileModel {
  /// Unique identifier for this profile
  final String id;

  /// The name for this profile
  final String? name;

  /// Profile's gender (female, male, other)
  final String? gender;

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

  /// Profile's sun sign (calculated from birth data)
  final String? sunSign;

  /// Profile's rising sign (calculated from birth data)
  final String? risingSign;

  /// Profile's moon sign (calculated from birth data)
  final String? moonSign;

  /// Profile's relationship status
  final String? relationshipStatus;

  /// Profile's spiritual intentions (list of intention keys)
  final List<String>? intentions;

  /// Profile's esoteric knowledge level (novice, seeker, adept)
  final String? knowledgeLevel;

  /// Profile's preferred reading tone (gentle, brutal)
  final String? preferredTone;

  /// When this profile was created
  final DateTime createdAt;

  /// Whether this is the main/primary profile
  final bool isMainProfile;

  const ProfileModel({
    required this.id,
    this.name,
    this.gender,
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
    required this.createdAt,
    this.isMainProfile = false,
  });

  /// Creates a new empty profile with a generated ID
  factory ProfileModel.create({bool isMain = false}) {
    return ProfileModel(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      isMainProfile: isMain,
    );
  }

  /// Creates a copy with updated fields
  ProfileModel copyWith({
    String? id,
    String? name,
    String? gender,
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
    DateTime? createdAt,
    bool? isMainProfile,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
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
      createdAt: createdAt ?? this.createdAt,
      isMainProfile: isMainProfile ?? this.isMainProfile,
    );
  }

  /// Get profile's initials for avatar fallback
  String get initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  /// Check if profile has a profile image
  bool get hasProfileImage =>
      profileImageUrl != null && profileImageUrl!.isNotEmpty;

  /// Check if profile has entered their name
  bool get hasName => name != null && name!.isNotEmpty;

  /// Check if profile has complete birth data for astrology
  bool get hasBirthData => birthDate != null && birthLatitude != null;

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'profileImageUrl': profileImageUrl,
      'birthDate': birthDate,
      'birthTime': birthTime,
      'birthLatitude': birthLatitude,
      'birthLongitude': birthLongitude,
      'birthTimezone': birthTimezone,
      'birthCity': birthCity,
      'sunSign': sunSign,
      'risingSign': risingSign,
      'moonSign': moonSign,
      'relationshipStatus': relationshipStatus,
      'intentions': intentions,
      'knowledgeLevel': knowledgeLevel,
      'preferredTone': preferredTone,
      'createdAt': createdAt.toIso8601String(),
      'isMainProfile': isMainProfile,
    };
  }

  /// Create from JSON (Firestore)
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      birthDate: json['birthDate'] as String?,
      birthTime: json['birthTime'] as String?,
      birthLatitude: (json['birthLatitude'] as num?)?.toDouble(),
      birthLongitude: (json['birthLongitude'] as num?)?.toDouble(),
      birthTimezone: json['birthTimezone'] as String?,
      birthCity: json['birthCity'] as String?,
      sunSign: json['sunSign'] as String?,
      risingSign: json['risingSign'] as String?,
      moonSign: json['moonSign'] as String?,
      relationshipStatus: json['relationshipStatus'] as String?,
      intentions: (json['intentions'] as List<dynamic>?)?.cast<String>(),
      knowledgeLevel: json['knowledgeLevel'] as String?,
      preferredTone: json['preferredTone'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      isMainProfile: json['isMainProfile'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'ProfileModel(id: $id, name: $name, isMain: $isMainProfile)';
}
