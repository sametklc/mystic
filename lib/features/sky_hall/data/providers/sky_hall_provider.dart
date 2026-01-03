import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/daily_insight_model.dart';
import '../../domain/models/natal_chart_model.dart';
import '../../domain/models/synastry_model.dart';
import '../services/astrology_api_service.dart';

/// Provider for the AstrologyApiService singleton.
final astrologyApiServiceProvider = Provider<AstrologyApiService>((ref) {
  return AstrologyApiService();
});

/// State for natal chart calculation.
class NatalChartState {
  final bool isLoading;
  final NatalChart? chart;
  final String? error;

  const NatalChartState({
    this.isLoading = false,
    this.chart,
    this.error,
  });

  factory NatalChartState.initial() => const NatalChartState();
  factory NatalChartState.loading() => const NatalChartState(isLoading: true);
  factory NatalChartState.success(NatalChart chart) =>
      NatalChartState(chart: chart);
  factory NatalChartState.error(String message) =>
      NatalChartState(error: message);

  bool get hasChart => chart != null;
  bool get hasError => error != null;
}

/// Notifier for managing natal chart state.
class NatalChartNotifier extends StateNotifier<NatalChartState> {
  final AstrologyApiService _apiService;

  NatalChartNotifier(this._apiService) : super(NatalChartState.initial());

  /// Calculate natal chart from birth data.
  Future<void> calculateChart({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    String timezone = 'UTC',
    String? name,
  }) async {
    state = NatalChartState.loading();

    try {
      final chart = await _apiService.calculateNatalChart(
        date: date,
        time: time,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
        name: name,
      );
      state = NatalChartState.success(chart);
    } on AstrologyApiException catch (e) {
      state = NatalChartState.error(e.message);
    } catch (e) {
      state = NatalChartState.error('An unexpected error occurred.');
    }
  }

  /// Clear the current chart.
  void clearChart() {
    state = NatalChartState.initial();
  }
}

/// Provider for natal chart state.
final natalChartProvider =
    StateNotifierProvider<NatalChartNotifier, NatalChartState>((ref) {
  final apiService = ref.watch(astrologyApiServiceProvider);
  return NatalChartNotifier(apiService);
});

// ============================================================================
// Synastry Provider
// ============================================================================

/// State for synastry calculation.
class SynastryState {
  final bool isLoading;
  final SynastryReport? report;
  final String? error;

  const SynastryState({
    this.isLoading = false,
    this.report,
    this.error,
  });

  factory SynastryState.initial() => const SynastryState();
  factory SynastryState.loading() => const SynastryState(isLoading: true);
  factory SynastryState.success(SynastryReport report) =>
      SynastryState(report: report);
  factory SynastryState.error(String message) => SynastryState(error: message);

  bool get hasReport => report != null;
  bool get hasError => error != null;
}

/// Notifier for managing synastry state.
class SynastryNotifier extends StateNotifier<SynastryState> {
  final AstrologyApiService _apiService;

  SynastryNotifier(this._apiService) : super(SynastryState.initial());

  /// Calculate synastry between two people.
  Future<void> calculateSynastry({
    required Map<String, dynamic> user1Data,
    required Map<String, dynamic> user2Data,
    String? characterId,
  }) async {
    state = SynastryState.loading();

    try {
      final report = await _apiService.calculateSynastry(
        user1Data: user1Data,
        user2Data: user2Data,
        characterId: characterId,
      );
      state = SynastryState.success(report);
    } on AstrologyApiException catch (e) {
      state = SynastryState.error(e.message);
    } catch (e) {
      state = SynastryState.error('An unexpected error occurred.');
    }
  }

  /// Clear the current report.
  void clearReport() {
    state = SynastryState.initial();
  }
}

/// Provider for synastry state.
final synastryProvider =
    StateNotifierProvider<SynastryNotifier, SynastryState>((ref) {
  final apiService = ref.watch(astrologyApiServiceProvider);
  return SynastryNotifier(apiService);
});

// ============================================================================
// Selected Tab Provider
// ============================================================================

/// The current tab in Sky Hall.
enum SkyHallTab { myChart, loveMatch }

/// Provider for the current Sky Hall tab.
final skyHallTabProvider = StateProvider<SkyHallTab>((ref) => SkyHallTab.myChart);

// ============================================================================
// Daily Insight Provider (with caching)
// ============================================================================

/// Cache key for daily insight.
const String _dailyInsightCacheKey = 'daily_insight_cache';
const String _dailyInsightDateKey = 'daily_insight_date';

/// State for daily cosmic insight.
class DailyInsightState {
  final bool isLoading;
  final DailyInsight? insight;
  final String? error;

  const DailyInsightState({
    this.isLoading = false,
    this.insight,
    this.error,
  });

  factory DailyInsightState.initial() => const DailyInsightState();
  factory DailyInsightState.loading() => const DailyInsightState(isLoading: true);
  factory DailyInsightState.success(DailyInsight insight) =>
      DailyInsightState(insight: insight);
  factory DailyInsightState.error(String message) =>
      DailyInsightState(error: message);

  bool get hasInsight => insight != null;
  bool get hasError => error != null;
}

/// Notifier for managing daily insight state with local caching.
class DailyInsightNotifier extends StateNotifier<DailyInsightState> {
  final AstrologyApiService _apiService;

  DailyInsightNotifier(this._apiService) : super(DailyInsightState.initial());

  /// Get today's date as a string.
  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Fetch daily insight, using cache if available for today.
  Future<void> fetchDailyInsight({bool forceRefresh = false}) async {
    // Avoid multiple simultaneous fetches
    if (state.isLoading) return;

    state = DailyInsightState.loading();

    try {
      // Try to get cached data first (unless force refresh)
      if (!forceRefresh) {
        final cachedInsight = await _getCachedInsight();
        if (cachedInsight != null) {
          state = DailyInsightState.success(cachedInsight);
          return;
        }
      }

      // Fetch from API
      final insight = await _apiService.getDailyInsight();

      // Cache the result
      await _cacheInsight(insight);

      state = DailyInsightState.success(insight);
    } on AstrologyApiException catch (e) {
      state = DailyInsightState.error(e.message);
    } catch (e) {
      state = DailyInsightState.error('Failed to fetch cosmic insight.');
    }
  }

  /// Get cached insight if it's for today.
  Future<DailyInsight?> _getCachedInsight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_dailyInsightDateKey);

      // Check if cache is from today
      if (cachedDate != _todayString) {
        return null;
      }

      final cachedJson = prefs.getString(_dailyInsightCacheKey);
      if (cachedJson == null) return null;

      final data = jsonDecode(cachedJson) as Map<String, dynamic>;
      return DailyInsight.fromJson(data);
    } catch (e) {
      // If cache read fails, return null to fetch fresh
      return null;
    }
  }

  /// Cache the insight with today's date.
  Future<void> _cacheInsight(DailyInsight insight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dailyInsightDateKey, _todayString);
      await prefs.setString(_dailyInsightCacheKey, jsonEncode(insight.toJson()));
    } catch (e) {
      // Cache write failure is non-critical
      debugPrint('Failed to cache daily insight: $e');
    }
  }

  /// Clear the insight state.
  void clearInsight() {
    state = DailyInsightState.initial();
  }
}

/// Helper function for debug printing.
void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

/// Provider for daily insight state.
final dailyInsightProvider =
    StateNotifierProvider<DailyInsightNotifier, DailyInsightState>((ref) {
  final apiService = ref.watch(astrologyApiServiceProvider);
  return DailyInsightNotifier(apiService);
});
