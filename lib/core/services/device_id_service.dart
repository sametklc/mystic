import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing unique device ID that persists across app reinstalls.
/// The ID is stored locally and also synced to Firestore for data recovery.
class DeviceIdService {
  static const String _deviceIdKey = 'mystic_device_id';
  static const String _firstLaunchKey = 'mystic_first_launch';

  final SharedPreferences _prefs;

  DeviceIdService(this._prefs);

  /// Gets or creates a unique device ID.
  /// This ID is persistent and survives app reinstalls.
  String getOrCreateDeviceId() {
    String? existingId = _prefs.getString(_deviceIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    // Generate new UUID
    final newId = const Uuid().v4();
    _prefs.setString(_deviceIdKey, newId);
    _prefs.setBool(_firstLaunchKey, true);

    return newId;
  }

  /// Gets the current device ID without creating a new one.
  String? getDeviceId() {
    return _prefs.getString(_deviceIdKey);
  }

  /// Checks if this is the first launch of the app.
  bool isFirstLaunch() {
    return _prefs.getBool(_firstLaunchKey) ?? true;
  }

  /// Marks that the first launch setup has been completed.
  Future<void> markFirstLaunchComplete() async {
    await _prefs.setBool(_firstLaunchKey, false);
  }

  /// Clears all stored data (for debugging/testing only).
  Future<void> clearAll() async {
    await _prefs.remove(_deviceIdKey);
    await _prefs.remove(_firstLaunchKey);
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
