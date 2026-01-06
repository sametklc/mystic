import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_storage_service.dart';
import 'firestore_reading_service.dart';

/// Combined service for persisting readings with images.
/// Handles the complete flow: Firestore save → Storage upload → URL update.
class ReadingPersistenceService {
  final FirestoreReadingService _firestoreService;
  final FirebaseStorageService _storageService;

  ReadingPersistenceService({
    required FirestoreReadingService firestoreService,
    required FirebaseStorageService storageService,
  })  : _firestoreService = firestoreService,
        _storageService = storageService;

  /// Saves a complete reading with image persistence.
  ///
  /// 1. Saves reading to Firestore (without permanent image URL)
  /// 2. Uploads image to Firebase Storage (if temporary URL provided)
  /// 3. Updates Firestore with permanent image URL
  Future<String> saveReadingWithImage({
    required String userId,
    required String question,
    required String cardName,
    required bool isUpright,
    required String interpretation,
    String? temporaryImageUrl,
    String? moonPhase,
    String characterId = 'madame_luna',
  }) async {
    print('[ReadingPersistence] Starting saveReadingWithImage...');
    print('[ReadingPersistence] User ID: $userId');
    print('[ReadingPersistence] Card: $cardName');

    // Step 1: Ensure user exists
    print('[ReadingPersistence] Step 1: Ensuring user exists...');
    await _firestoreService.ensureUserExists(userId);
    print('[ReadingPersistence] Step 1: Done');

    // Step 2: Save reading to Firestore (with temporary image URL for immediate display)
    print('[ReadingPersistence] Step 2: Saving reading to Firestore...');
    final readingId = await _firestoreService.saveReading(
      userId: userId,
      question: question,
      cardName: cardName,
      isUpright: isUpright,
      interpretation: interpretation,
      imageUrl: null, // Will be updated with permanent URL after upload
      temporaryImageUrl: temporaryImageUrl, // Save temporary URL immediately
      moonPhase: moonPhase,
      characterId: characterId,
    );
    print('[ReadingPersistence] Step 2: Done. Reading ID: $readingId');

    // Step 3: If we have a temporary image URL, upload to Storage
    if (temporaryImageUrl != null && temporaryImageUrl.isNotEmpty) {
      try {
        print('[ReadingPersistence] Step 3: Uploading image to Storage...');
        print('[ReadingPersistence] Temp URL: $temporaryImageUrl');
        final permanentUrl = await _storageService.uploadImageFromUrl(
          sourceUrl: temporaryImageUrl,
          userId: userId,
          readingId: readingId,
        );
        print('[ReadingPersistence] Step 3: Done. Permanent URL: $permanentUrl');

        // Step 4: Update Firestore with permanent URL
        if (permanentUrl != null) {
          print('[ReadingPersistence] Step 4: Updating Firestore with permanent URL...');
          await _firestoreService.updateReadingImageUrl(
            userId: userId,
            readingId: readingId,
            imageUrl: permanentUrl,
          );
          print('[ReadingPersistence] Step 4: Done');
        }
      } catch (e) {
        print('[ReadingPersistence] Error uploading image: $e');
        // Reading is still saved, just without the image
      }
    } else {
      print('[ReadingPersistence] No temporary image URL provided, skipping upload');
    }

    print('[ReadingPersistence] Complete! Reading ID: $readingId');
    return readingId;
  }

  /// Deletes a reading and its associated image.
  Future<void> deleteReading({
    required String userId,
    required String readingId,
  }) async {
    // Delete image from Storage
    await _storageService.deleteImage(
      userId: userId,
      readingId: readingId,
    );

    // Delete reading from Firestore
    await _firestoreService.deleteReading(userId, readingId);
  }
}

/// Provider for ReadingPersistenceService.
final readingPersistenceServiceProvider = Provider<ReadingPersistenceService>((ref) {
  final firestoreService = ref.watch(firestoreReadingServiceProvider);
  final storageService = ref.watch(firebaseStorageServiceProvider);

  return ReadingPersistenceService(
    firestoreService: firestoreService,
    storageService: storageService,
  );
});
