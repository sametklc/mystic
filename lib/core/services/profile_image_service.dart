import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Service for handling profile image uploads to Firebase Storage.
class ProfileImageService {
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  ProfileImageService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _picker = picker ?? ImagePicker();

  /// Pick an image from gallery.
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick an image from camera.
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Upload profile image to Firebase Storage.
  /// Returns the download URL on success, null on failure.
  /// Now supports multi-profile with unique paths per profile.
  Future<String?> uploadProfileImage(String userId, File imageFile, {String? profileId}) async {
    try {
      // Create reference: users/{userId}/profiles/{profileId}/profile.jpg
      // If no profileId provided, use legacy path for backwards compatibility
      final path = profileId != null
          ? 'users/$userId/profiles/$profileId/profile.jpg'
          : 'users/$userId/profile.jpg';
      final ref = _storage.ref().child(path);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'profileId': profileId ?? 'main',
        },
      );

      // Start upload
      final uploadTask = ref.putFile(imageFile, metadata);

      // Wait for completion
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Profile image uploaded successfully for profile $profileId: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  /// Delete profile image from Firebase Storage.
  Future<bool> deleteProfileImage(String userId, {String? profileId}) async {
    try {
      final path = profileId != null
          ? 'users/$userId/profiles/$profileId/profile.jpg'
          : 'users/$userId/profile.jpg';
      final ref = _storage.ref().child(path);
      await ref.delete();
      debugPrint('Profile image deleted successfully for profile $profileId');
      return true;
    } on FirebaseException catch (e) {
      // Object not found is okay - image might not exist
      if (e.code == 'object-not-found') {
        return true;
      }
      debugPrint('Firebase Storage error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error deleting profile image: $e');
      return false;
    }
  }
}

/// Provider for ProfileImageService.
final profileImageServiceProvider = Provider<ProfileImageService>((ref) {
  return ProfileImageService();
});
