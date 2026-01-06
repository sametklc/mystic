/// Gem economy configuration and service for the Mystic app.
///
/// Gems are the in-app currency earned through subscriptions
/// and spent on premium AI features.
class GemConfig {
  GemConfig._();

  // ============================================================
  // EARNING - Subscription Rewards
  // ============================================================

  /// Gems awarded for Weekly subscription purchase
  static const int weeklySubscriptionReward = 100;

  /// Gems awarded for Weekly Pro subscription purchase
  static const int weeklyProSubscriptionReward = 200;

  /// Gems awarded for Yearly subscription purchase
  static const int yearlySubscriptionReward = 500;

  // ============================================================
  // CONSUMABLE - Diamond Packs (In-App Purchases)
  // ============================================================

  /// Small diamond pack - 100 diamonds for $4.99
  static const String diamondPack100Id = 'diamonds_100';
  static const int diamondPack100Amount = 100;
  static const double diamondPack100Price = 4.99;

  /// Medium diamond pack - 500 diamonds for $19.99
  static const String diamondPack500Id = 'diamonds_500';
  static const int diamondPack500Amount = 500;
  static const double diamondPack500Price = 19.99;

  /// Large diamond pack - 1000 diamonds for $34.99
  static const String diamondPack1000Id = 'diamonds_1000';
  static const int diamondPack1000Amount = 1000;
  static const double diamondPack1000Price = 34.99;

  /// Get diamond amount for a consumable product ID
  /// NOTE: Check 1000 before 100, because '1000' contains '100' as substring
  static int? getDiamondAmountForProduct(String productId) {
    final lowerId = productId.toLowerCase();
    // Check 1000 FIRST (before 100) because 'diamonds_1000' contains 'diamonds_100'
    if (lowerId.contains('diamonds_1000') || lowerId.contains('diamond_1000')) {
      return diamondPack1000Amount;
    } else if (lowerId.contains('diamonds_500') || lowerId.contains('diamond_500')) {
      return diamondPack500Amount;
    } else if (lowerId.contains('diamonds_100') || lowerId.contains('diamond_100')) {
      return diamondPack100Amount;
    }
    return null;
  }

  /// Check if a product ID is a consumable diamond pack
  static bool isConsumableProduct(String productId) {
    return getDiamondAmountForProduct(productId) != null;
  }

  // ============================================================
  // SPENDING - Feature Costs
  // ============================================================

  /// Cost for AI Vision tarot card generation (additional)
  static const int aiVisionTarotCost = 10;

  /// Cost for tarot reading (premium users only)
  static const int tarotReadingCost = 10;

  /// Cost for Love Match compatibility report (premium users only)
  static const int loveMatchCost = 20;

  /// Cost for creating a new profile with birth chart
  static const int newProfileChartCost = 20;

  // ============================================================
  // HELPERS
  // ============================================================

  /// Get reward amount for a subscription product ID
  static int? getRewardForProduct(String productId) {
    // Match RevenueCat product IDs
    final lowerProductId = productId.toLowerCase();

    if (lowerProductId.contains('yearly') || lowerProductId.contains('annual')) {
      return yearlySubscriptionReward;
    } else if (lowerProductId.contains('weekly_pro') || lowerProductId.contains('weeklypro')) {
      return weeklyProSubscriptionReward;
    } else if (lowerProductId.contains('weekly')) {
      return weeklySubscriptionReward;
    }

    return null;
  }

  /// Check if an action is affordable
  static bool canAfford(int currentBalance, int cost) {
    return currentBalance >= cost;
  }
}

/// Result of a gem transaction
class GemTransactionResult {
  final bool success;
  final int newBalance;
  final String? errorMessage;

  const GemTransactionResult({
    required this.success,
    required this.newBalance,
    this.errorMessage,
  });

  factory GemTransactionResult.success(int balance) {
    return GemTransactionResult(success: true, newBalance: balance);
  }

  factory GemTransactionResult.insufficientFunds(int balance, int required) {
    return GemTransactionResult(
      success: false,
      newBalance: balance,
      errorMessage: 'Not enough gems. You need $required gems but have $balance.',
    );
  }
}
