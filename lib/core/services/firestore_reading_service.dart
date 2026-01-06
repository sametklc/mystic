import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/domain/models/grimoire_entry_model.dart';

/// Service for persisting and retrieving tarot readings from Firestore.
class FirestoreReadingService {
  final FirebaseFirestore _firestore;

  FirestoreReadingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Gets the readings collection reference for a user.
  CollectionReference<Map<String, dynamic>> _readingsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('readings');
  }

  /// Saves a new reading to Firestore.
  Future<String> saveReading({
    required String userId,
    required String question,
    required String cardName,
    required bool isUpright,
    required String interpretation,
    String? imageUrl,
    String? temporaryImageUrl,
    String? moonPhase,
    String characterId = 'madame_luna',
  }) async {
    try {
      final docRef = _readingsCollection(userId).doc();

      // Use permanent URL if available, otherwise use temporary URL
      final effectiveImageUrl = imageUrl ?? temporaryImageUrl;

      final data = {
        'id': docRef.id,
        'question': question,
        'card_name': cardName,
        'is_upright': isUpright,
        'interpretation': interpretation,
        'image_url': effectiveImageUrl,
        'temporary_image_url': temporaryImageUrl,
        'moon_phase': moonPhase ?? _getCurrentMoonPhase(),
        'character_id': characterId,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      print('Error saving reading to Firestore: $e');
      rethrow;
    }
  }

  /// Updates a reading's image URL after upload to Firebase Storage.
  Future<void> updateReadingImageUrl({
    required String userId,
    required String readingId,
    required String imageUrl,
  }) async {
    try {
      await _readingsCollection(userId).doc(readingId).update({
        'image_url': imageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating reading image URL: $e');
      rethrow;
    }
  }

  /// Gets all readings for a user, ordered by date (newest first).
  Future<List<GrimoireEntryModel>> getReadings(String userId) async {
    try {
      final snapshot = await _readingsCollection(userId)
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GrimoireEntryModel(
          id: doc.id,
          date: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          question: data['question'] as String? ?? '',
          cardName: data['card_name'] as String? ?? '',
          isUpright: data['is_upright'] as bool? ?? true,
          interpretation: data['interpretation'] as String? ?? '',
          imageUrl: data['image_url'] as String?,
          moonPhase: data['moon_phase'] as String?,
          characterId: data['character_id'] as String? ?? 'madame_luna',
        );
      }).toList();
    } catch (e) {
      print('Error getting readings from Firestore: $e');
      return [];
    }
  }

  /// Gets a single reading by ID.
  Future<GrimoireEntryModel?> getReading(String userId, String readingId) async {
    try {
      final doc = await _readingsCollection(userId).doc(readingId).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return GrimoireEntryModel(
        id: doc.id,
        date: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        question: data['question'] as String? ?? '',
        cardName: data['card_name'] as String? ?? '',
        isUpright: data['is_upright'] as bool? ?? true,
        interpretation: data['interpretation'] as String? ?? '',
        imageUrl: data['image_url'] as String?,
        moonPhase: data['moon_phase'] as String?,
        characterId: data['character_id'] as String? ?? 'madame_luna',
      );
    } catch (e) {
      print('Error getting reading from Firestore: $e');
      return null;
    }
  }

  /// Deletes a reading from Firestore.
  Future<void> deleteReading(String userId, String readingId) async {
    try {
      await _readingsCollection(userId).doc(readingId).delete();
    } catch (e) {
      print('Error deleting reading from Firestore: $e');
      rethrow;
    }
  }

  /// Streams readings for real-time updates.
  Stream<List<GrimoireEntryModel>> streamReadings(String userId) {
    return _readingsCollection(userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GrimoireEntryModel(
          id: doc.id,
          date: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          question: data['question'] as String? ?? '',
          cardName: data['card_name'] as String? ?? '',
          isUpright: data['is_upright'] as bool? ?? true,
          interpretation: data['interpretation'] as String? ?? '',
          imageUrl: data['image_url'] as String?,
          moonPhase: data['moon_phase'] as String?,
          characterId: data['character_id'] as String? ?? 'madame_luna',
        );
      }).toList();
    });
  }

  /// Ensures user document exists in Firestore.
  Future<void> ensureUserExists(String userId) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        await userDoc.set({
          'created_at': FieldValue.serverTimestamp(),
          'device_id': userId,
        });
      }
    } catch (e) {
      print('Error ensuring user exists: $e');
    }
  }

  /// Gets current moon phase (simplified).
  String _getCurrentMoonPhase() {
    final now = DateTime.now();
    final dayOfMonth = now.day;

    // Simple approximation based on lunar cycle (~29.5 days)
    if (dayOfMonth <= 3) return 'New Moon';
    if (dayOfMonth <= 7) return 'Waxing Crescent';
    if (dayOfMonth <= 11) return 'First Quarter';
    if (dayOfMonth <= 14) return 'Waxing Gibbous';
    if (dayOfMonth <= 17) return 'Full Moon';
    if (dayOfMonth <= 21) return 'Waning Gibbous';
    if (dayOfMonth <= 25) return 'Third Quarter';
    return 'Waning Crescent';
  }
}

/// Provider for FirestoreReadingService.
final firestoreReadingServiceProvider = Provider<FirestoreReadingService>((ref) {
  return FirestoreReadingService();
});
