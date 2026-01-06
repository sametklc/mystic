import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/device_id_service.dart';
import '../../core/services/revenuecat_service.dart';
import '../../core/services/user_firestore_service.dart';
import '../models/profile_model.dart';
import '../models/user_model.dart';

/// Provider for managing user state throughout the app.
/// This is the source of truth for user information.
/// Data is persisted to Firebase Firestore using device ID.
final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  final deviceId = ref.watch(deviceIdProvider);
  final firestoreService = ref.watch(userFirestoreServiceProvider);
  return UserNotifier(deviceId, firestoreService);
});

/// Notifier that manages user state changes with Firestore persistence.
class UserNotifier extends StateNotifier<UserModel> {
  final String _deviceId;
  final UserFirestoreService _firestoreService;
  bool _isInitialized = false;

  /// Profile ID being created during onboarding (null = main profile)
  String? _pendingProfileId;

  UserNotifier(this._deviceId, this._firestoreService)
      : super(const UserModel.initial()) {
    // Load user data from Firestore on init
    _loadFromFirestore();
  }

  /// Load user data from Firestore.
  Future<void> _loadFromFirestore() async {
    try {
      final user = await _firestoreService.loadUser(_deviceId);
      if (user != null) {
        state = user;
      }
      _isInitialized = true;
    } catch (e) {
      print('Error loading user from Firestore: $e');
      _isInitialized = true;
    }
  }

  /// Save current state to Firestore.
  Future<void> _saveToFirestore() async {
    try {
      await _firestoreService.saveUser(_deviceId, state);
    } catch (e) {
      print('Error saving user to Firestore: $e');
    }
  }

  /// Check if user data has been loaded from Firestore.
  bool get isInitialized => _isInitialized;

  /// Get the current profile ID being edited
  String? get currentEditingProfileId =>
      _pendingProfileId ?? state.currentProfileId;

  // ============================================================
  // PROFILE MANAGEMENT
  // ============================================================

  /// Start creating a new profile (for onboarding)
  void startNewProfile() {
    final newProfile = ProfileModel.create(isMain: state.profiles.isEmpty);
    _pendingProfileId = newProfile.id;
    state = state.addProfile(newProfile);
  }

  /// Switch to a different profile
  void switchProfile(String profileId) {
    state = state.switchProfile(profileId);
    _saveToFirestore();
  }

  /// Delete a profile (cannot delete main profile)
  void deleteProfile(String profileId) {
    final profile = state.profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => throw Exception('Profile not found'),
    );

    if (profile.isMainProfile) {
      throw Exception('Cannot delete main profile');
    }

    state = state.removeProfile(profileId);
    _saveToFirestore();
  }

  /// Get all profiles
  List<ProfileModel> get profiles => state.profiles;

  /// Get current profile
  ProfileModel? get currentProfile => state.currentProfile;

  // ============================================================
  // PROFILE DATA SETTERS (updates current/pending profile)
  // ============================================================

  /// Set the profile's name during onboarding.
  void setName(String name) {
    final profileId = currentEditingProfileId;
    if (profileId == null) {
      // Legacy: create main profile if none exists
      startNewProfile();
      setName(name);
      return;
    }

    state = state.updateProfile(profileId, (p) => p.copyWith(
      name: name.trim(),
    ));

    // Update joinedAt at account level if first profile
    if (state.joinedAt == null) {
      state = state.copyWith(joinedAt: DateTime.now());
    }

    _saveToFirestore();
  }

  /// Set the profile's gender.
  void setGender(String gender) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(profileId, (p) => p.copyWith(gender: gender));
    _saveToFirestore();
  }

  /// Set the profile's birth data.
  void setBirthData({
    required String date,
    String? time,
    required double latitude,
    required double longitude,
    String? timezone,
    String? city,
  }) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(profileId, (p) => p.copyWith(
      birthDate: date,
      birthTime: time,
      birthLatitude: latitude,
      birthLongitude: longitude,
      birthTimezone: timezone ?? 'UTC',
      birthCity: city,
    ));
    _saveToFirestore();
  }

  /// Set the profile's calculated signs.
  void setSigns({String? sunSign, String? risingSign, String? moonSign}) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(profileId, (p) => p.copyWith(
      sunSign: sunSign,
      risingSign: risingSign,
      moonSign: moonSign,
    ));
    _saveToFirestore();
  }

  /// Set the profile's relationship status.
  void setRelationshipStatus(String status) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(
        profileId, (p) => p.copyWith(relationshipStatus: status));
    _saveToFirestore();
  }

  /// Set the profile's spiritual intentions.
  void setIntentions(List<String> intentions) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(
        profileId, (p) => p.copyWith(intentions: intentions));
    _saveToFirestore();
  }

  /// Set the profile's esoteric knowledge level.
  void setKnowledgeLevel(String level) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(
        profileId, (p) => p.copyWith(knowledgeLevel: level));
    _saveToFirestore();
  }

  /// Set the profile's preferred reading tone.
  void setPreferredTone(String tone) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(
        profileId, (p) => p.copyWith(preferredTone: tone));
    _saveToFirestore();
  }

  /// Set the profile's profile image URL.
  void setProfileImageUrl(String url) {
    final profileId = currentEditingProfileId;
    if (profileId == null) return;

    state = state.updateProfile(
        profileId, (p) => p.copyWith(profileImageUrl: url));
    _saveToFirestore();
  }

  /// Mark onboarding as complete.
  void completeOnboarding() {
    // Clear pending profile ID
    _pendingProfileId = null;

    state = state.copyWith(
      hasCompletedOnboarding: true,
      joinedAt: state.joinedAt ?? DateTime.now(),
    );
    _saveToFirestore();
  }

  /// Complete adding a new profile (not the first onboarding)
  void completeAddProfile() {
    if (_pendingProfileId != null) {
      // Switch to the new profile
      state = state.switchProfile(_pendingProfileId!);
      _pendingProfileId = null;
      _saveToFirestore();
    }
  }

  /// Cancel adding a new profile
  void cancelAddProfile() {
    if (_pendingProfileId != null) {
      state = state.removeProfile(_pendingProfileId!);
      _pendingProfileId = null;
    }
  }

  /// Reload user data from Firestore.
  Future<void> reload() async {
    await _loadFromFirestore();
  }

  /// Set premium status (account-level).
  void setPremium(bool isPremium, {DateTime? expiresAt}) {
    state = state.copyWith(
      isPremium: isPremium,
      premiumExpiresAt: expiresAt,
    );
    _saveToFirestore();
  }

  // ============================================================
  // GEM MANAGEMENT
  // ============================================================

  /// Current gem balance
  int get gems => state.gems;

  /// Add gems to the user's balance (e.g., from subscription purchase)
  void addGems(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(gems: state.gems + amount);
    _saveToFirestore();
    print('[Gems] Added $amount gems. New balance: ${state.gems}');
  }

  /// Spend gems (returns true if successful, false if insufficient balance)
  bool spendGems(int amount) {
    if (amount <= 0) return true;
    if (state.gems < amount) {
      print('[Gems] Insufficient balance. Required: $amount, Available: ${state.gems}');
      return false;
    }
    state = state.copyWith(gems: state.gems - amount);
    _saveToFirestore();
    print('[Gems] Spent $amount gems. New balance: ${state.gems}');
    return true;
  }

  /// Check if user has enough gems for an action
  bool hasEnoughGems(int amount) {
    return state.gems >= amount;
  }

  /// Set gem balance directly (for admin/testing purposes)
  void setGems(int amount) {
    state = state.copyWith(gems: amount);
    _saveToFirestore();
  }

  /// Reset user (for testing/logout).
  void reset() {
    state = const UserModel.initial();
    _pendingProfileId = null;
    _firestoreService.deleteUser(_deviceId);
  }
}

/// Convenience provider to check if user has completed onboarding.
final hasCompletedOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).hasCompletedOnboarding;
});

/// Convenience provider to check if user has premium subscription.
/// Uses RevenueCat as the source of truth, falls back to local UserModel.
final isPremiumProvider = Provider<bool>((ref) {
  // Try RevenueCat first (source of truth)
  final revenueCatPremium = ref.watch(revenueCatPremiumProvider);

  return revenueCatPremium.when(
    data: (isPremium) {
      // Sync to UserModel if different
      final user = ref.read(userProvider);
      if (user.isPremium != isPremium) {
        // Use Future.microtask to avoid modifying state during build
        Future.microtask(() {
          ref.read(userProvider.notifier).setPremium(isPremium);
        });
      }
      return isPremium;
    },
    loading: () {
      // While loading, use cached value from UserModel
      final user = ref.watch(userProvider);
      if (!user.isPremium) return false;
      if (user.premiumExpiresAt == null) return user.isPremium;
      return user.premiumExpiresAt!.isAfter(DateTime.now());
    },
    error: (_, __) {
      // On error, use cached value from UserModel
      final user = ref.watch(userProvider);
      if (!user.isPremium) return false;
      if (user.premiumExpiresAt == null) return user.isPremium;
      return user.premiumExpiresAt!.isAfter(DateTime.now());
    },
  );
});

/// Convenience provider to get user's name (from current profile).
final userNameProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).name;
});

/// Provider to get current profile.
final currentProfileProvider = Provider<ProfileModel?>((ref) {
  return ref.watch(userProvider).currentProfile;
});

/// Provider to get all profiles.
final allProfilesProvider = Provider<List<ProfileModel>>((ref) {
  return ref.watch(userProvider).profiles;
});

/// Provider to check if user data is fully loaded.
final userLoadedProvider = FutureProvider<bool>((ref) async {
  final deviceId = ref.watch(deviceIdProvider);
  final firestoreService = ref.watch(userFirestoreServiceProvider);

  // Try to load user data
  final user = await firestoreService.loadUser(deviceId);

  if (user != null) {
    // Update the user provider state
    ref.read(userProvider.notifier).reload();
    return true;
  }

  return false;
});

/// Provider to track if we're in "add profile" mode during onboarding.
/// When true, completing onboarding will add a new profile instead of
/// completing the first-time onboarding.
final addProfileModeProvider = StateProvider<bool>((ref) => false);

/// Provider to get the profile currently being edited (pending or current).
/// Use this in onboarding screens to get the correct profile data.
final editingProfileProvider = Provider<ProfileModel?>((ref) {
  final notifier = ref.watch(userProvider.notifier);
  final user = ref.watch(userProvider);
  final editingId = notifier.currentEditingProfileId;

  if (editingId == null) return user.currentProfile;

  try {
    return user.profiles.firstWhere((p) => p.id == editingId);
  } catch (_) {
    return user.currentProfile;
  }
});

/// Provider to get the editing profile's name.
final editingProfileNameProvider = Provider<String?>((ref) {
  return ref.watch(editingProfileProvider)?.name;
});

/// Provider to get user's gem balance.
final gemsProvider = Provider<int>((ref) {
  return ref.watch(userProvider).gems;
});
