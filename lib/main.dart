import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/device_id_service.dart';
import 'core/services/revenuecat_service.dart';
import 'firebase_options.dart';

/// Provider for pre-initialized DeviceIdService.
/// This is set in main() after async initialization.
final initializedDeviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize SharedPreferencessamo
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize DeviceIdService with Keychain/Keystore persistencesamo
  // This ensures device ID persists across app reinstalls
  final deviceIdService = DeviceIdService(sharedPreferences);
  await deviceIdService.initialize();
  final deviceId = deviceIdService.getDeviceId();
  debugPrint('[Main] Device ID initialized: ${deviceId?.substring(0, 8)}...');

  // Initialize RevenueCat with device ID for cross-device sync
  await RevenueCatService.instance.initialize(userId: deviceId);
  debugPrint('[Main] RevenueCat initialized');

  // Set preferred orientations (portrait only for mystical experience)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for immersive dark experience
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF050511),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // Run the app wrapped in Riverpod's ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        // Provide SharedPreferences instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        // Provide pre-initialized DeviceIdService (with Keychain already loaded)
        deviceIdServiceProvider.overrideWithValue(deviceIdService),
      ],
      child: const MysticApp(),
    ),
  );
}
