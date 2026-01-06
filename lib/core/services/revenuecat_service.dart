import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'gem_service.dart';

/// RevenueCat API Keys
class RevenueCatConfig {
  static const String appleApiKey = 'appl_YkouQKMRUSnpHvnTOGvbCvdBbNd';
  static const String googleApiKey = 'goog_wZUFFGRXucrToLleuilmHSTMWys';

  // Entitlement ID - this should match what you set up in RevenueCat Dashboard
  static const String premiumEntitlementId = 'premium';

  // Subscription Product IDs
  static const String weeklyProductId = 'mystic_weekly';
  static const String weeklyProProductId = 'mystic_weekly_pro';
  static const String yearlyProductId = 'mystic_yearly';

  // Consumable Product IDs (Diamond Packs)
  static const String diamonds100ProductId = 'diamonds_100';
  static const String diamonds500ProductId = 'diamonds_500';
  static const String diamonds1000ProductId = 'diamonds_1000';

  // Offering ID for diamond packs (set this in RevenueCat Dashboard)
  static const String diamondOfferingId = 'diamonds';
}

/// Service for handling in-app purchases via RevenueCat
class RevenueCatService {
  static RevenueCatService? _instance;
  bool _isInitialized = false;

  // Stream controller for customer info updates
  final _customerInfoController = StreamController<CustomerInfo>.broadcast();

  RevenueCatService._();

  static RevenueCatService get instance {
    _instance ??= RevenueCatService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;

  /// Stream of customer info updates
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  /// Initialize RevenueCat SDK
  /// Call this once at app startup (in main.dart)
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) return;

    try {
      // Enable debug logs in development
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Configure with platform-specific API key
      PurchasesConfiguration configuration;
      if (Platform.isIOS) {
        configuration = PurchasesConfiguration(RevenueCatConfig.appleApiKey);
      } else if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(RevenueCatConfig.googleApiKey);
      } else {
        debugPrint('[RevenueCat] Unsupported platform');
        return;
      }

      // Set app user ID if provided (for cross-device sync)
      if (userId != null && userId.isNotEmpty) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);

      // Set up listener for customer info updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _customerInfoController.add(customerInfo);
      });

      _isInitialized = true;
      debugPrint('[RevenueCat] Initialized successfully');
    } catch (e) {
      debugPrint('[RevenueCat] Initialization error: $e');
    }
  }

  /// Get available subscription packages/offerings
  Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      debugPrint('[RevenueCat] Error fetching offerings: $e');
      return [];
    }
  }

  /// Get diamond pack offerings (consumables)
  Future<List<Package>> getDiamondOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();

      debugPrint('[RevenueCat] Available offerings: ${offerings.all.keys.toList()}');

      // Try to get the 'diamonds' offering first
      final diamondOffering = offerings.getOffering(RevenueCatConfig.diamondOfferingId);
      if (diamondOffering != null && diamondOffering.availablePackages.isNotEmpty) {
        debugPrint('[RevenueCat] Found diamonds offering with ${diamondOffering.availablePackages.length} packages');
        return diamondOffering.availablePackages;
      }

      // Fallback: filter from current offering for diamond products
      if (offerings.current != null) {
        final diamondPackages = offerings.current!.availablePackages.where((pkg) {
          final productId = pkg.storeProduct.identifier.toLowerCase();
          return productId.contains('diamond');
        }).toList();

        if (diamondPackages.isNotEmpty) {
          debugPrint('[RevenueCat] Found ${diamondPackages.length} diamond packages from current offering');
          return diamondPackages;
        }
      }

      // Fallback 2: Check all offerings for diamond products
      for (final entry in offerings.all.entries) {
        final diamondPackages = entry.value.availablePackages.where((pkg) {
          final productId = pkg.storeProduct.identifier.toLowerCase();
          return productId.contains('diamond');
        }).toList();

        if (diamondPackages.isNotEmpty) {
          debugPrint('[RevenueCat] Found ${diamondPackages.length} diamond packages from "${entry.key}" offering');
          return diamondPackages;
        }
      }

      debugPrint('[RevenueCat] No diamond packages found in any offering');
      return [];
    } catch (e) {
      debugPrint('[RevenueCat] Error fetching diamond offerings: $e');
      return [];
    }
  }

  /// Purchase a consumable diamond pack
  /// Returns the number of diamonds to add on success
  Future<ConsumablePurchaseResult> purchaseConsumable(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final productId = package.storeProduct.identifier;

      // Get the diamond amount for this product
      final diamondsAwarded = GemConfig.getDiamondAmountForProduct(productId) ?? 0;

      debugPrint('[RevenueCat] Consumable purchase successful! Product: $productId, Diamonds: $diamondsAwarded');

      return ConsumablePurchaseResult(
        success: true,
        diamondsAwarded: diamondsAwarded,
        productId: productId,
        customerInfo: customerInfo,
      );
    } on PurchasesErrorCode catch (e) {
      debugPrint('[RevenueCat] Consumable purchase error code: $e');
      return ConsumablePurchaseResult(
        success: false,
        errorCode: e,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      debugPrint('[RevenueCat] Consumable purchase error: $e');
      return ConsumablePurchaseResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Purchase a package
  Future<PurchaseResult> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final isPremium = customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.premiumEntitlementId);

      // Calculate gem reward based on product ID
      final productId = package.storeProduct.identifier;
      final gemsRewarded = GemConfig.getRewardForProduct(productId) ?? 0;

      debugPrint('[RevenueCat] Purchase successful! Product: $productId, Gems: $gemsRewarded');

      return PurchaseResult(
        success: true,
        isPremium: isPremium,
        customerInfo: customerInfo,
        gemsRewarded: gemsRewarded,
        productId: productId,
      );
    } on PurchasesErrorCode catch (e) {
      debugPrint('[RevenueCat] Purchase error code: $e');
      return PurchaseResult(
        success: false,
        errorCode: e,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      debugPrint('[RevenueCat] Purchase error: $e');
      return PurchaseResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Restore purchases
  Future<RestoreResult> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremium = customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.premiumEntitlementId);

      return RestoreResult(
        success: true,
        isPremium: isPremium,
        customerInfo: customerInfo,
      );
    } catch (e) {
      debugPrint('[RevenueCat] Restore error: $e');
      return RestoreResult(
        success: false,
        errorMessage: 'Failed to restore purchases',
      );
    }
  }

  /// Check if user has premium entitlement
  Future<bool> checkPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active
          .containsKey(RevenueCatConfig.premiumEntitlementId);
    } catch (e) {
      debugPrint('[RevenueCat] Error checking premium status: $e');
      return false;
    }
  }

  /// Get customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('[RevenueCat] Error getting customer info: $e');
      return null;
    }
  }

  /// Set user ID for cross-device sync
  Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
      debugPrint('[RevenueCat] User ID set: $userId');
    } catch (e) {
      debugPrint('[RevenueCat] Error setting user ID: $e');
    }
  }

  /// Log out user
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      debugPrint('[RevenueCat] User logged out');
    } catch (e) {
      debugPrint('[RevenueCat] Error logging out: $e');
    }
  }

  String _getErrorMessage(PurchasesErrorCode errorCode) {
    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        return 'Purchase was cancelled';
      case PurchasesErrorCode.storeProblemError:
        return 'There was a problem with the store';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchase not allowed on this device';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'Invalid purchase';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Product not available for purchase';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Product already purchased';
      case PurchasesErrorCode.networkError:
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred during purchase';
    }
  }
}

/// Result of a purchase attempt
class PurchaseResult {
  final bool success;
  final bool isPremium;
  final CustomerInfo? customerInfo;
  final PurchasesErrorCode? errorCode;
  final String? errorMessage;
  final int gemsRewarded;
  final String? productId;

  PurchaseResult({
    required this.success,
    this.isPremium = false,
    this.customerInfo,
    this.errorCode,
    this.errorMessage,
    this.gemsRewarded = 0,
    this.productId,
  });
}

/// Result of a restore attempt
class RestoreResult {
  final bool success;
  final bool isPremium;
  final CustomerInfo? customerInfo;
  final String? errorMessage;

  RestoreResult({
    required this.success,
    this.isPremium = false,
    this.customerInfo,
    this.errorMessage,
  });
}

/// Result of a consumable purchase attempt
class ConsumablePurchaseResult {
  final bool success;
  final int diamondsAwarded;
  final String? productId;
  final CustomerInfo? customerInfo;
  final PurchasesErrorCode? errorCode;
  final String? errorMessage;

  ConsumablePurchaseResult({
    required this.success,
    this.diamondsAwarded = 0,
    this.productId,
    this.customerInfo,
    this.errorCode,
    this.errorMessage,
  });
}

// ============================================================================
// RIVERPOD PROVIDERS
// ============================================================================

/// Provider for RevenueCat service instance
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService.instance;
});

/// Provider for available subscription packages
final packagesProvider = FutureProvider<List<Package>>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  return service.getOfferings();
});

/// Provider for diamond pack offerings (consumables)
final diamondPackagesProvider = FutureProvider<List<Package>>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  return service.getDiamondOfferings();
});

/// Provider for premium status (reactive)
final revenueCatPremiumProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(revenueCatServiceProvider);

  // Initial check
  yield await service.checkPremiumStatus();

  // Listen for updates
  await for (final customerInfo in service.customerInfoStream) {
    yield customerInfo.entitlements.active
        .containsKey(RevenueCatConfig.premiumEntitlementId);
  }
});

/// Provider for purchase state
final purchaseStateProvider =
    StateNotifierProvider<PurchaseStateNotifier, PurchaseState>((ref) {
  return PurchaseStateNotifier(ref.watch(revenueCatServiceProvider));
});

class PurchaseState {
  final bool isLoading;
  final String? error;
  final bool purchaseSuccess;
  final int gemsRewarded;

  const PurchaseState({
    this.isLoading = false,
    this.error,
    this.purchaseSuccess = false,
    this.gemsRewarded = 0,
  });

  PurchaseState copyWith({
    bool? isLoading,
    String? error,
    bool? purchaseSuccess,
    int? gemsRewarded,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      purchaseSuccess: purchaseSuccess ?? this.purchaseSuccess,
      gemsRewarded: gemsRewarded ?? this.gemsRewarded,
    );
  }
}

class PurchaseStateNotifier extends StateNotifier<PurchaseState> {
  final RevenueCatService _service;

  PurchaseStateNotifier(this._service) : super(const PurchaseState());

  /// Purchase a package and return the result with gems rewarded
  Future<PurchaseResult> purchase(Package package) async {
    state = state.copyWith(isLoading: true, error: null, gemsRewarded: 0);

    final result = await _service.purchasePackage(package);

    if (result.success) {
      state = state.copyWith(
        isLoading: false,
        purchaseSuccess: true,
        gemsRewarded: result.gemsRewarded,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.errorMessage,
        gemsRewarded: 0,
      );
    }

    return result;
  }

  Future<bool> restore() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _service.restorePurchases();

    if (result.success && result.isPremium) {
      state = state.copyWith(
        isLoading: false,
        purchaseSuccess: true,
      );
      return true;
    } else if (result.success && !result.isPremium) {
      state = state.copyWith(
        isLoading: false,
        error: 'No previous purchases found',
      );
      return false;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.errorMessage,
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void reset() {
    state = const PurchaseState();
  }
}
