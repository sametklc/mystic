import 'profile_model.dart';

/// Represents the user account in the Mystic app.
/// An account can have multiple profiles.
class UserModel {
  /// When the user first joined
  final DateTime? joinedAt;

  /// Whether the user has completed onboarding (at least one profile exists)
  final bool hasCompletedOnboarding;

  /// Whether the user has premium subscription (account-level)
  final bool isPremium;

  /// Premium subscription expiry date
  final DateTime? premiumExpiresAt;

  /// User's gem balance (account-level currency)
  /// Earned through subscriptions, spent on AI features
  final int gems;

  /// List of profiles under this account
  final List<ProfileModel> profiles;

  /// Currently active profile ID
  final String? currentProfileId;

  const UserModel({
    this.joinedAt,
    this.hasCompletedOnboarding = false,
    this.isPremium = false,
    this.premiumExpiresAt,
    this.gems = 0,
    this.profiles = const [],
    this.currentProfileId,
  });

  /// Creates an empty user (initial state)
  const UserModel.initial()
      : joinedAt = null,
        hasCompletedOnboarding = false,
        isPremium = false,
        premiumExpiresAt = null,
        gems = 0,
        profiles = const [],
        currentProfileId = null;

  /// Get the currently active profile
  ProfileModel? get currentProfile {
    if (currentProfileId == null || profiles.isEmpty) return null;
    try {
      return profiles.firstWhere((p) => p.id == currentProfileId);
    } catch (_) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
  }

  /// Get the main profile (first one created)
  ProfileModel? get mainProfile {
    try {
      return profiles.firstWhere((p) => p.isMainProfile);
    } catch (_) {
      return profiles.isNotEmpty ? profiles.first : null;
    }
  }

  // ============================================================
  // CONVENIENCE GETTERS (delegate to current profile)
  // ============================================================

  /// The name from current profile
  String? get name => currentProfile?.name;

  /// User's gender from current profile
  String? get gender => currentProfile?.gender;

  /// Profile image URL from current profile
  String? get profileImageUrl => currentProfile?.profileImageUrl;

  /// Birth date from current profile
  String? get birthDate => currentProfile?.birthDate;

  /// Birth time from current profile
  String? get birthTime => currentProfile?.birthTime;

  /// Birth latitude from current profile
  double? get birthLatitude => currentProfile?.birthLatitude;

  /// Birth longitude from current profile
  double? get birthLongitude => currentProfile?.birthLongitude;

  /// Birth timezone from current profile
  String? get birthTimezone => currentProfile?.birthTimezone;

  /// Birth city from current profile
  String? get birthCity => currentProfile?.birthCity;

  /// Sun sign from current profile
  String? get sunSign => currentProfile?.sunSign;

  /// Rising sign from current profile
  String? get risingSign => currentProfile?.risingSign;

  /// Moon sign from current profile
  String? get moonSign => currentProfile?.moonSign;

  /// Relationship status from current profile
  String? get relationshipStatus => currentProfile?.relationshipStatus;

  /// Intentions from current profile
  List<String>? get intentions => currentProfile?.intentions;

  /// Knowledge level from current profile
  String? get knowledgeLevel => currentProfile?.knowledgeLevel;

  /// Preferred tone from current profile
  String? get preferredTone => currentProfile?.preferredTone;

  /// Get user's initials for avatar fallback
  String get initials => currentProfile?.initials ?? '?';

  /// Check if user has a profile image
  bool get hasProfileImage => currentProfile?.hasProfileImage ?? false;

  /// Check if the user has entered their name
  bool get hasName => currentProfile?.hasName ?? false;

  /// Check if user has complete birth data for astrology
  bool get hasBirthData => currentProfile?.hasBirthData ?? false;

  /// Creates a copy with updated fields
  UserModel copyWith({
    DateTime? joinedAt,
    bool? hasCompletedOnboarding,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    int? gems,
    List<ProfileModel>? profiles,
    String? currentProfileId,
  }) {
    return UserModel(
      joinedAt: joinedAt ?? this.joinedAt,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      gems: gems ?? this.gems,
      profiles: profiles ?? this.profiles,
      currentProfileId: currentProfileId ?? this.currentProfileId,
    );
  }

  /// Add a new profile
  UserModel addProfile(ProfileModel profile) {
    final newProfiles = [...profiles, profile];
    return copyWith(
      profiles: newProfiles,
      currentProfileId: currentProfileId ?? profile.id,
    );
  }

  /// Update a profile by ID
  UserModel updateProfile(String profileId, ProfileModel Function(ProfileModel) update) {
    final newProfiles = profiles.map((p) {
      if (p.id == profileId) {
        return update(p);
      }
      return p;
    }).toList();
    return copyWith(profiles: newProfiles);
  }

  /// Remove a profile by ID
  UserModel removeProfile(String profileId) {
    final newProfiles = profiles.where((p) => p.id != profileId).toList();
    String? newCurrentId = currentProfileId;
    if (currentProfileId == profileId) {
      newCurrentId = newProfiles.isNotEmpty ? newProfiles.first.id : null;
    }
    return copyWith(profiles: newProfiles, currentProfileId: newCurrentId);
  }

  /// Switch to a different profile
  UserModel switchProfile(String profileId) {
    return copyWith(currentProfileId: profileId);
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'joinedAt': joinedAt?.toIso8601String(),
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'isPremium': isPremium,
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
      'gems': gems,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'currentProfileId': currentProfileId,
    };
  }

  /// Create from JSON (Firestore)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle migration from old format (no profiles)
    List<ProfileModel> profiles = [];

    if (json['profiles'] != null) {
      profiles = (json['profiles'] as List<dynamic>)
          .map((p) => ProfileModel.fromJson(p as Map<String, dynamic>))
          .toList();
    } else if (json['name'] != null || json['birthDate'] != null) {
      // Migrate old single-profile data to new format
      final mainProfile = ProfileModel(
        id: json['mainProfileId'] as String? ?? 'main',
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
        createdAt: json['joinedAt'] != null
            ? DateTime.parse(json['joinedAt'] as String)
            : DateTime.now(),
        isMainProfile: true,
      );
      profiles = [mainProfile];
    }

    return UserModel(
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'] as String)
          : null,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      isPremium: json['isPremium'] as bool? ?? false,
      premiumExpiresAt: json['premiumExpiresAt'] != null
          ? DateTime.parse(json['premiumExpiresAt'] as String)
          : null,
      gems: json['gems'] as int? ?? 0,
      profiles: profiles,
      currentProfileId: json['currentProfileId'] as String? ??
          (profiles.isNotEmpty ? profiles.first.id : null),
    );
  }

  @override
  String toString() =>
      'UserModel(profiles: ${profiles.length}, currentProfile: ${currentProfile?.name})';
}
