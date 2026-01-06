import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing unique device ID that persists across app reinstalls.
///
/// Strategy for persistence across reinstalls:
/// - iOS: iCloud Keychain with synchronizable flag (survives uninstall)
/// - Android: ANDROID_ID (unique per app+device, survives uninstall)
/// - Fallback: Firebase Firestore lookup, then generate new ID
///
/// IMPORTANT: We use a FIXED service name (not bundle ID) so that
/// keychain items persist even if the app bundle ID changes.
class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static const String _firstLaunchKey = 'mystic_first_launch';
  static const String _backupIdKey = 'mystic_backup_id';

  // Fixed service name - NEVER change this or users will lose their data!
  static const String _keychainService = 'com.skapps.mystic.keychain';

  final SharedPreferences _prefs;
  late final FlutterSecureStorage _secureStorage;
  late final FlutterSecureStorage _iCloudStorage;

  // Cached device ID for synchronous access
  String? _cachedDeviceId;
  bool _isInitialized = false;

  DeviceIdService(this._prefs) {
    // Local Keychain - for fast access
    _secureStorage = FlutterSecureStorage(
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        accountName: _keychainService,
      ),
    );

    // iCloud synced Keychain - survives app uninstall on iOS!
    _iCloudStorage = FlutterSecureStorage(
      aOptions: const AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        synchronizable: true, // Syncs to iCloud Keychain
        accountName: '${_keychainService}.icloud',
      ),
    );
  }

  /// Initialize the service and load/migrate device ID.
  /// Must be called before using getOrCreateDeviceId().
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[DeviceId] Starting initialization...');

      // ANDROID: Use ANDROID_ID which survives app reinstalls
      if (Platform.isAndroid) {
        await _initializeAndroid();
        return;
      }

      // iOS: Use iCloud Keychain strategy
      if (Platform.isIOS) {
        await _initializeIOS();
        return;
      }

      // Other platforms: fallback to UUID
      await _initializeFallback();

    } catch (e) {
      debugPrint('[DeviceId] Critical error: $e');
      // Ultimate fallback
      _cachedDeviceId = _prefs.getString(_deviceIdKey) ?? const Uuid().v4();
      await _prefs.setString(_deviceIdKey, _cachedDeviceId!);
      _isInitialized = true;
    }
  }

  /// Android-specific initialization using ANDROID_ID
  /// Strategy:
  /// 1. Check SharedPreferences for existing user
  /// 2. Get ANDROID_ID (persists across reinstalls)
  /// 3. Query users collection where android_id field matches
  /// 4. If found, recover that user
  /// 5. If not found, create new user with android_id field
  Future<void> _initializeAndroid() async {
    debugPrint('[DeviceId] Android initialization...');

    // Get ANDROID_ID first (we'll need it for lookup or saving)
    String? androidId;
    try {
      const androidIdPlugin = AndroidId();
      androidId = await androidIdPlugin.getId();
      if (androidId != null && androidId.isNotEmpty) {
        debugPrint('[DeviceId] Got ANDROID_ID: ${androidId.substring(0, 8)}...');
      }
    } catch (e) {
      debugPrint('[DeviceId] Failed to get ANDROID_ID: $e');
    }

    // 1. Check if we have existing device ID in local storage
    final existingId = _prefs.getString(_deviceIdKey) ??
                       _prefs.getString('mystic_device_id');

    if (existingId != null && existingId.isNotEmpty) {
      // Verify user exists in Firebase
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(existingId)
            .get();
        if (doc.exists) {
          _cachedDeviceId = existingId;
          await _prefs.setString(_deviceIdKey, existingId);
          debugPrint('[DeviceId] ✓ Found existing user: ${existingId.substring(0, 8)}...');
          _isInitialized = true;

          // Save android_id to user document for future recovery
          if (androidId != null && androidId.isNotEmpty) {
            _saveAndroidIdToUser(existingId, androidId);
          }
          return;
        }
      } catch (e) {
        debugPrint('[DeviceId] Firebase check failed: $e');
      }
    }

    // 2. Try to recover using ANDROID_ID (query users collection)
    if (androidId != null && androidId.isNotEmpty) {
      try {
        debugPrint('[DeviceId] Searching for user with android_id...');
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('android_id', isEqualTo: androidId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userId = querySnapshot.docs.first.id;
          _cachedDeviceId = userId;
          await _prefs.setString(_deviceIdKey, userId);
          await _prefs.setString(_backupIdKey, userId);
          debugPrint('[DeviceId] ✓ Recovered user via ANDROID_ID: ${userId.substring(0, 8)}...');
          _isInitialized = true;
          return;
        }
        debugPrint('[DeviceId] No user found with this android_id');
      } catch (e) {
        debugPrint('[DeviceId] Firebase query failed: $e');
      }

      // 3. New user - generate UUID
      final newId = const Uuid().v4();
      _cachedDeviceId = newId;
      await _prefs.setString(_deviceIdKey, newId);
      await _prefs.setString(_backupIdKey, newId);
      await _prefs.setBool(_firstLaunchKey, true);

      debugPrint('[DeviceId] ✓ New Android user: ${newId.substring(0, 8)}...');
      _isInitialized = true;
      return;
    }

    // 4. Fallback to UUID if ANDROID_ID fails
    await _initializeFallback();
  }

  /// Save android_id field to user document for future recovery
  Future<void> _saveAndroidIdToUser(String userId, String androidId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'android_id': androidId,
      }, SetOptions(merge: true));
      debugPrint('[DeviceId] ✓ Saved android_id to user document');
    } catch (e) {
      debugPrint('[DeviceId] Failed to save android_id: $e');
    }
  }

  /// iOS-specific initialization using iCloud Keychain
  Future<void> _initializeIOS() async {
    debugPrint('[DeviceId] iOS initialization...');

    // 1. Try iCloud Keychain first (survives uninstall)
    try {
      debugPrint('[DeviceId] Checking iCloud Keychain...');
      final iCloudId = await _iCloudStorage.read(key: _deviceIdKey);
      debugPrint('[DeviceId] iCloud read result: ${iCloudId != null ? "found" : "null"}');
      if (iCloudId != null && iCloudId.isNotEmpty) {
        _cachedDeviceId = iCloudId;
        await _secureStorage.write(key: _deviceIdKey, value: iCloudId);
        await _prefs.setString(_deviceIdKey, iCloudId);
        debugPrint('[DeviceId] ✓ Recovered from iCloud: ${_cachedDeviceId?.substring(0, 8)}...');
        _isInitialized = true;
        return;
      }
    } catch (e) {
      debugPrint('[DeviceId] iCloud read error: $e');
    }

    // 2. Try local Keychain
    try {
      debugPrint('[DeviceId] Checking local Keychain...');
      final localId = await _secureStorage.read(key: _deviceIdKey);
      if (localId != null && localId.isNotEmpty) {
        _cachedDeviceId = localId;
        try {
          await _iCloudStorage.write(key: _deviceIdKey, value: localId);
          debugPrint('[DeviceId] Synced to iCloud');
        } catch (e) {
          debugPrint('[DeviceId] iCloud sync failed: $e');
        }
        debugPrint('[DeviceId] ✓ Found in local Keychain: ${_cachedDeviceId?.substring(0, 8)}...');
        _isInitialized = true;
        return;
      }
    } catch (e) {
      debugPrint('[DeviceId] Local Keychain error: $e');
    }

    // 3. Try SharedPreferences (legacy migration)
    final prefsId = _prefs.getString(_deviceIdKey) ?? _prefs.getString('mystic_device_id');
    if (prefsId != null && prefsId.isNotEmpty) {
      _cachedDeviceId = prefsId;
      await _saveToAllStorages(prefsId);
      debugPrint('[DeviceId] ✓ Migrated from prefs: ${_cachedDeviceId?.substring(0, 8)}...');
      _isInitialized = true;
      return;
    }

    // 4. Generate new ID
    final newId = const Uuid().v4();
    _cachedDeviceId = newId;
    await _saveToAllStorages(newId);
    debugPrint('[DeviceId] ✓ Generated new ID: ${_cachedDeviceId?.substring(0, 8)}...');
    _isInitialized = true;
  }

  /// Fallback initialization for other platforms
  Future<void> _initializeFallback() async {
    debugPrint('[DeviceId] Fallback initialization...');

    // Try SharedPreferences
    final prefsId = _prefs.getString(_deviceIdKey) ?? _prefs.getString('mystic_device_id');
    if (prefsId != null && prefsId.isNotEmpty) {
      _cachedDeviceId = prefsId;
      debugPrint('[DeviceId] ✓ Found in prefs: ${_cachedDeviceId?.substring(0, 8)}...');
      _isInitialized = true;
      return;
    }

    // Generate new ID
    final newId = const Uuid().v4();
    _cachedDeviceId = newId;
    await _prefs.setString(_deviceIdKey, newId);
    await _prefs.setString(_backupIdKey, newId);
    await _prefs.setBool(_firstLaunchKey, true);
    debugPrint('[DeviceId] ✓ Generated new ID: ${_cachedDeviceId?.substring(0, 8)}...');
    _isInitialized = true;
  }

  /// Save device ID to all available storage mechanisms
  Future<void> _saveToAllStorages(String deviceId) async {
    debugPrint('[DeviceId] Saving to all storages...');

    // SharedPreferences (fastest access + legacy compatibility)
    await _prefs.setString(_deviceIdKey, deviceId);
    await _prefs.setString('mystic_device_id', deviceId); // Legacy key
    await _prefs.setString(_backupIdKey, deviceId);
    await _prefs.setBool(_firstLaunchKey, true);
    debugPrint('[DeviceId] ✓ Saved to SharedPreferences');

    // Local Keychain
    try {
      await _secureStorage.write(key: _deviceIdKey, value: deviceId);
      debugPrint('[DeviceId] ✓ Saved to local Keychain');
    } catch (e) {
      debugPrint('[DeviceId] ✗ Local Keychain write failed: $e');
    }

    // iCloud Keychain (iOS only) - survives uninstall!
    if (Platform.isIOS) {
      try {
        await _iCloudStorage.write(key: _deviceIdKey, value: deviceId);
        debugPrint('[DeviceId] ✓ Saved to iCloud Keychain');
      } catch (e) {
        debugPrint('[DeviceId] ✗ iCloud Keychain write failed: $e');
      }
    }
  }

  /// Gets or creates a unique device ID.
  /// Call initialize() first, or this will initialize synchronously with fallback.
  String getOrCreateDeviceId() {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Fallback for synchronous access before async init
    String? existingId = _prefs.getString(_deviceIdKey);
    existingId ??= _prefs.getString('mystic_device_id'); // Legacy key

    if (existingId != null && existingId.isNotEmpty) {
      _cachedDeviceId = existingId;
      return existingId;
    }

    // Generate new UUID as last resort
    final newId = const Uuid().v4();
    _prefs.setString(_deviceIdKey, newId);
    _prefs.setString('mystic_device_id', newId); // Legacy key
    _prefs.setString(_backupIdKey, newId);
    _prefs.setBool(_firstLaunchKey, true);
    _cachedDeviceId = newId;

    // Save to Keychain(s) async
    _saveToAllStorages(newId);

    return newId;
  }

  /// Gets the current device ID without creating a new one.
  String? getDeviceId() {
    return _cachedDeviceId ?? _prefs.getString(_deviceIdKey);
  }

  /// Checks if this is the first launch of the app.
  bool isFirstLaunch() {
    return _prefs.getBool(_firstLaunchKey) ?? true;
  }

  /// Marks that the first launch setup has been completed.
  Future<void> markFirstLaunchComplete() async {
    await _prefs.setBool(_firstLaunchKey, false);
  }

  /// Check if the service is initialized.
  bool get isInitialized => _isInitialized;

  /// Clears all stored data (for debugging/testing only).
  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _deviceIdKey);
      if (Platform.isIOS) {
        await _iCloudStorage.delete(key: _deviceIdKey);
      }
    } catch (e) {
      debugPrint('[DeviceId] Error clearing Keychain: $e');
    }
    await _prefs.remove(_deviceIdKey);
    await _prefs.remove(_backupIdKey);
    await _prefs.remove(_firstLaunchKey);
    _cachedDeviceId = null;
    _isInitialized = false;
  }
}

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main.dart');
});

/// Provider for DeviceIdService.
final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeviceIdService(prefs);
});

/// Provider for the current device ID.
final deviceIdProvider = Provider<String>((ref) {
  final service = ref.watch(deviceIdServiceProvider);
  return service.getOrCreateDeviceId();
});

/// FutureProvider for async device ID initialization.
/// Use this to ensure device ID is loaded from Keychain before app starts.
final deviceIdInitProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(deviceIdServiceProvider);
  await service.initialize();
  return service.getOrCreateDeviceId();
});
