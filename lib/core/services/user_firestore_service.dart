import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/user_model.dart';

/// Service for persisting user data to Firebase Firestore.
/// Uses device ID as the unique identifier for each user.
/// Supports multi-profile data format.
class UserFirestoreService {
  final FirebaseFirestore _firestore;
  final String _collection = 'users';

  UserFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Save user data to Firestore.
  /// Uses UserModel.toJson() for proper serialization with multi-profile support.
  Future<void> saveUser(String deviceId, UserModel user) async {
    try {
      final data = user.toJson();
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_collection).doc(deviceId).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error saving user to Firestore: $e');
      rethrow;
    }
  }

  /// Update specific fields in user document.
  Future<void> updateUserFields(String deviceId, Map<String, dynamic> fields) async {
    try {
      fields['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_collection).doc(deviceId).update(fields);
    } catch (e) {
      print('Error updating user fields: $e');
      rethrow;
    }
  }

  /// Load user data from Firestore.
  /// Returns null if user doesn't exist.
  /// Uses UserModel.fromJson() which handles migration from old format.
  Future<UserModel?> loadUser(String deviceId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(deviceId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      return UserModel.fromJson(data);
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
