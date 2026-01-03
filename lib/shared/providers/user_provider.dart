import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/device_id_service.dart';
import '../../core/services/user_firestore_service.dart';
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

  /// Set the user's name during onboarding.
  void setName(String name) {
    state = state.copyWith(
      name: name.trim(),
      joinedAt: state.joinedAt ?? DateTime.now(),
    );
    _saveToFirestore();
  }

  /// Set the user's gender.
  void setGender(String gender) {
    state = state.copyWith(gender: gender);
    _saveToFirestore();
  }

  /// Set the user's birth data.
  void setBirthData({
    required String date,
    String? time,
    required double latitude,
    required double longitude,
    String? timezone,
    String? city,
  }) {
    state = state.copyWith(
      birthDate: date,
      birthTime: time,
      birthLatitude: latitude,
      birthLongitude: longitude,
      birthTimezone: timezone ?? 'UTC',
      birthCity: city,
    );
    _saveToFirestore();
  }

  /// Set the user's calculated signs.
  void setSigns({String? sunSign, String? risingSign}) {
    state = state.copyWith(
      sunSign: sunSign,
      risingSign: risingSign,
    );
    _saveToFirestore();
  }

  /// Set the user's relationship status.
  void setRelationshipStatus(String status) {
    state = state.copyWith(relationshipStatus: status);
    _saveToFirestore();
  }

  /// Set the user's spiritual intentions.
  void setIntentions(List<String> intentions) {
    state = state.copyWith(intentions: intentions);
    _saveToFirestore();
  }

  /// Set the user's esoteric knowledge level.
  void setKnowledgeLevel(String level) {
    state = state.copyWith(knowledgeLevel: level);
    _saveToFirestore();
  }

  /// Set the user's preferred reading tone.
  void setPreferredTone(String tone) {
    state = state.copyWith(preferredTone: tone);
    _saveToFirestore();
  }

  /// Set the user's profile image URL.
  void setProfileImageUrl(String url) {
    state = state.copyWith(profileImageUrl: url);
    // Note: Not saving to Firestore here as it's already saved separately
  }

  /// Mark onboarding as complete.
  void completeOnboarding() {
    state = state.copyWith(
      hasCompletedOnboarding: true,
      joinedAt: state.joinedAt ?? DateTime.now(),
    );
    _saveToFirestore();
  }

  /// Reload user data from Firestore.
  Future<void> reload() async {
    await _loadFromFirestore();
  }

  /// Reset user (for testing/logout).
  void reset() {
    state = const UserModel.initial();
    _firestoreService.deleteUser(_deviceId);
  }
}

/// Convenience provider to check if user has completed onboarding.
final hasCompletedOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).hasCompletedOnboarding;
});

/// Convenience provider to get user's name.
final userNameProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).name;
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
