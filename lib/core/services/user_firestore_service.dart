import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/user_model.dart';
import 'device_id_service.dart';

/// Service for persisting user data to Firebase Firestore.
/// Uses device ID as the unique identifier for each user.
class UserFirestoreService {
  final FirebaseFirestore _firestore;
  final String _collection = 'users';

  UserFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Save user data to Firestore.
  Future<void> saveUser(String deviceId, UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(deviceId).set({
        'name': user.name,
        'birthDate': user.birthDate,
        'birthTime': user.birthTime,
        'birthLatitude': user.birthLatitude,
        'birthLongitude': user.birthLongitude,
        'birthTimezone': user.birthTimezone,
        'birthCity': user.birthCity,
        'sunSign': user.sunSign,
        'risingSign': user.risingSign,
        'hasCompletedOnboarding': user.hasCompletedOnboarding,
        'joinedAt': user.joinedAt?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  /// Load user data from Firestore.
  /// Returns null if user doesn't exist.
  Future<UserModel?> loadUser(String deviceId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(deviceId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;

      return UserModel(
        name: data['name'] as String?,
        birthDate: data['birthDate'] as String?,
        birthTime: data['birthTime'] as String?,
        birthLatitude: (data['birthLatitude'] as num?)?.toDouble(),
        birthLongitude: (data['birthLongitude'] as num?)?.toDouble(),
        birthTimezone: data['birthTimezone'] as String?,
        birthCity: data['birthCity'] as String?,
        sunSign: data['sunSign'] as String?,
        risingSign: data['risingSign'] as String?,
        hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
        joinedAt: data['joinedAt'] != null
            ? DateTime.tryParse(data['joinedAt'] as String)
            : null,
      );
    } catch (e) {
      print('Error loading user from Firestore: $e');
      return null;
    }
  }

  /// Check if user exists in Firestore.
  Future<bool> userExists(String deviceId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(deviceId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  /// Delete user data from Firestore.
  Future<void> deleteUser(String deviceId) async {
    try {
      await _firestore.collection(_collection).doc(deviceId).delete();
    } catch (e) {
      print('Error deleting user from Firestore: $e');
      rethrow;
    }
  }
}

/// Provider for UserFirestoreService.
final userFirestoreServiceProvider = Provider<UserFirestoreService>((ref) {
  return UserFirestoreService();
});
