import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Service for uploading and managing images in Firebase Storage.
class FirebaseStorageService {
  final FirebaseStorage _storage;

  FirebaseStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads an image from a URL to Firebase Storage.
  /// Returns the permanent Firebase Storage URL.
  ///
  /// [sourceUrl] - The temporary URL (e.g., from Replicate)
  /// [userId] - The user's unique ID
  /// [readingId] - The reading's unique ID
  Future<String?> uploadImageFromUrl({
    required String sourceUrl,
    required String userId,
    required String readingId,
  }) async {
    try {
      // Download the image from the source URL
      final response = await http.get(Uri.parse(sourceUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      final imageBytes = response.bodyBytes;
      final contentType = response.headers['content-type'] ?? 'image/webp';
      final extension = _getExtensionFromContentType(contentType);

      // Create the storage path
      final storagePath = 'users/$userId/readings/$readingId/card_image$extension';
      final ref = _storage.ref().child(storagePath);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'userId': userId,
          'readingId': readingId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      await ref.putData(imageBytes, metadata);

      // Get the download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      return null;
    }
  }

  /// Uploads raw image bytes to Firebase Storage.
  Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String userId,
    required String readingId,
    String contentType = 'image/webp',
  }) async {
    try {
      final extension = _getExtensionFromContentType(contentType);
      final storagePath = 'users/$userId/readings/$readingId/card_image$extension';
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'userId': userId,
          'readingId': readingId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image bytes: $e');
      return null;
    }
  }

  /// Deletes an image from Firebase Storage.
  Future<bool> deleteImage({
    required String userId,
    required String readingId,
  }) async {
    try {
      final storagePath = 'users/$userId/readings/$readingId';
      final ref = _storage.ref().child(storagePath);

      // List and delete all files in the reading folder
      final listResult = await ref.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }

      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Gets the file extension from content type.
  String _getExtensionFromContentType(String contentType) {
    switch (contentType) {
      case 'image/webp':
        return '.webp';
      case 'image/png':
        return '.png';
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/gif':
        return '.gif';
      default:
        return '.webp';
    }
  }
}

/// Provider for FirebaseStorageService.
final firebaseStorageServiceProvider = Provider<FirebaseStorageService>((ref) {
  return FirebaseStorageService();
});
