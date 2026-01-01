/// Represents the user's profile in the Mystic app.
/// This is a simple model for now, can be expanded with more spiritual preferences.
class UserModel {
  /// The name the user wishes to be called
  final String? name;

  /// When the user first joined their spiritual journey
  final DateTime? joinedAt;

  /// Whether the user has completed onboarding
  final bool hasCompletedOnboarding;

  const UserModel({
    this.name,
    this.joinedAt,
    this.hasCompletedOnboarding = false,
  });

  /// Creates an empty user (initial state)
  const UserModel.initial()
      : name = null,
        joinedAt = null,
        hasCompletedOnboarding = false;

  /// Creates a copy with updated fields
  UserModel copyWith({
    String? name,
    DateTime? joinedAt,
    bool? hasCompletedOnboarding,
  }) {
    return UserModel(
      name: name ?? this.name,
      joinedAt: joinedAt ?? this.joinedAt,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }

  /// Check if the user has entered their name
  bool get hasName => name != null && name!.isNotEmpty;

  @override
  String toString() => 'UserModel(name: $name, joinedAt: $joinedAt, hasCompletedOnboarding: $hasCompletedOnboarding)';
}
