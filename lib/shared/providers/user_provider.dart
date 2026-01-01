import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';

/// Provider for managing user state throughout the app.
/// This is the source of truth for user information.
final userProvider = StateNotifierProvider<UserNotifier, UserModel>((ref) {
  return UserNotifier();
});

/// Notifier that manages user state changes
class UserNotifier extends StateNotifier<UserModel> {
  UserNotifier() : super(const UserModel.initial());

  /// Set the user's name during onboarding
  void setName(String name) {
    state = state.copyWith(
      name: name.trim(),
      joinedAt: state.joinedAt ?? DateTime.now(),
    );
  }

  /// Mark onboarding as complete
  void completeOnboarding() {
    state = state.copyWith(
      hasCompletedOnboarding: true,
      joinedAt: state.joinedAt ?? DateTime.now(),
    );
  }

  /// Reset user (for testing/logout)
  void reset() {
    state = const UserModel.initial();
  }
}

/// Convenience provider to check if user has completed onboarding
final hasCompletedOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(userProvider).hasCompletedOnboarding;
});

/// Convenience provider to get user's name
final userNameProvider = Provider<String?>((ref) {
  return ref.watch(userProvider).name;
});
