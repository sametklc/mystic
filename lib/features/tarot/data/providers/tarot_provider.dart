import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/services/reading_persistence_service.dart';
import '../../../profile/data/providers/grimoire_provider.dart';
import '../services/tarot_api_service.dart';
import '../../domain/models/tarot_reading_model.dart';

/// Provider for the TarotApiService singleton.
final tarotApiServiceProvider = Provider<TarotApiService>((ref) {
  return TarotApiService();
});

/// State class for tarot reading generation.
class TarotReadingState {
  final bool isLoading;
  final TarotReadingModel? reading;
  final String? error;
  final double progress; // 0.0 to 1.0 for progress indication

  const TarotReadingState({
    this.isLoading = false,
    this.reading,
    this.error,
    this.progress = 0.0,
  });

  /// Initial state.
  factory TarotReadingState.initial() => const TarotReadingState();

  /// Loading state with optional progress.
  factory TarotReadingState.loading({double progress = 0.0}) =>
      TarotReadingState(isLoading: true, progress: progress);

  /// Success state with reading data.
  factory TarotReadingState.success(TarotReadingModel reading) =>
      TarotReadingState(reading: reading, progress: 1.0);

  /// Error state with message.
  factory TarotReadingState.error(String message) =>
      TarotReadingState(error: message);

  /// Returns true if there's a valid reading.
  bool get hasReading => reading != null;

  /// Returns true if there's an error.
  bool get hasError => error != null;

  TarotReadingState copyWith({
    bool? isLoading,
    TarotReadingModel? reading,
    String? error,
    double? progress,
  }) {
    return TarotReadingState(
      isLoading: isLoading ?? this.isLoading,
      reading: reading ?? this.reading,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// Notifier for managing tarot reading state.
class TarotReadingNotifier extends StateNotifier<TarotReadingState> {
  final TarotApiService _apiService;
  final ReadingPersistenceService _persistenceService;
  final String _deviceId;
  final Ref _ref;

  TarotReadingNotifier(
    this._apiService,
    this._persistenceService,
    this._deviceId,
    this._ref,
  ) : super(TarotReadingState.initial());

  /// Generates a new tarot reading.
  ///
  /// Updates state through: loading → (progress updates) → success/error
  /// Also persists the reading to Firebase after successful generation.
  Future<void> generateReading({
    required String userId,
    required String question,
    SpreadType spreadType = SpreadType.single,
    bool visionaryMode = true,
    String? cardName,
  }) async {
    // Start loading
    state = TarotReadingState.loading(progress: 0.1);

    try {
      // Simulate progress updates for better UX (actual request is single call)
      _simulateProgress();

      final reading = await _apiService.generateReading(
        userId: userId,
        question: question,
        spreadType: spreadType,
        visionaryMode: visionaryMode,
        cardName: cardName,
      );

      state = TarotReadingState.success(reading);

      // Persist reading to Firebase (in background, don't block UI)
      _persistReadingToFirebase(
        question: question,
        reading: reading,
      );
    } on TarotApiException catch (e) {
      state = TarotReadingState.error(e.message);
    } catch (e) {
      state = TarotReadingState.error('Beklenmeyen bir hata oluştu.');
    }
  }

  /// Persists the reading to Firebase Storage and Firestore.
  Future<void> _persistReadingToFirebase({
    required String question,
    required TarotReadingModel reading,
  }) async {
    try {
      final primaryCard = reading.primaryCard;
      if (primaryCard == null) {
        print('No primary card found, skipping persistence');
        return;
      }

      print('Saving reading to Firebase...');
      print('  - Device ID: $_deviceId');
      print('  - Card: ${primaryCard.name}');
      print('  - Image URL: ${reading.imageUrl}');

      await _persistenceService.saveReadingWithImage(
        userId: _deviceId,
        question: question,
        cardName: primaryCard.name,
        isUpright: primaryCard.isUpright,
        interpretation: reading.interpretation,
        temporaryImageUrl: reading.imageUrl,
        characterId: 'madame_luna',
      );
      print('Reading persisted to Firebase successfully!');

      // Refresh Grimoire to show the new reading
      _ref.read(grimoireProvider.notifier).refresh();
      print('Grimoire refreshed');
    } catch (e) {
      // Don't fail the reading if persistence fails
      print('Failed to persist reading to Firebase: $e');
    }
  }

  /// Simulates progress updates during API call.
  void _simulateProgress() async {
    final progressSteps = [0.2, 0.4, 0.6, 0.8];

    for (final step in progressSteps) {
      await Future.delayed(const Duration(milliseconds: 1500));
      // Only update if still loading
      if (state.isLoading) {
        state = state.copyWith(progress: step);
      } else {
        break; // Stop if loading finished
      }
    }
  }

  /// Clears the current reading state.
  void clearReading() {
    state = TarotReadingState.initial();
  }

  /// Clears any error state.
  void clearError() {
    if (state.hasError) {
      state = TarotReadingState.initial();
    }
  }
}

/// Main provider for tarot reading state and actions.
final tarotReadingProvider =
    StateNotifierProvider<TarotReadingNotifier, TarotReadingState>((ref) {
  final apiService = ref.watch(tarotApiServiceProvider);
  final persistenceService = ref.watch(readingPersistenceServiceProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return TarotReadingNotifier(apiService, persistenceService, deviceId, ref);
});

/// Provider for checking if a reading is in progress.
final isGeneratingReadingProvider = Provider<bool>((ref) {
  return ref.watch(tarotReadingProvider).isLoading;
});

/// Provider for the current reading progress (0.0 to 1.0).
final readingProgressProvider = Provider<double>((ref) {
  return ref.watch(tarotReadingProvider).progress;
});

/// Provider for the current reading result.
final currentReadingProvider = Provider<TarotReadingModel?>((ref) {
  return ref.watch(tarotReadingProvider).reading;
});

/// Provider for any reading error message.
final readingErrorProvider = Provider<String?>((ref) {
  return ref.watch(tarotReadingProvider).error;
});

// ============================================================================
// User Reading History Provider
// ============================================================================

/// State class for user's reading history.
class ReadingHistoryState {
  final bool isLoading;
  final List<TarotReadingModel> readings;
  final String? error;

  const ReadingHistoryState({
    this.isLoading = false,
    this.readings = const [],
    this.error,
  });

  factory ReadingHistoryState.initial() => const ReadingHistoryState();

  factory ReadingHistoryState.loading() =>
      const ReadingHistoryState(isLoading: true);

  factory ReadingHistoryState.success(List<TarotReadingModel> readings) =>
      ReadingHistoryState(readings: readings);

  factory ReadingHistoryState.error(String message) =>
      ReadingHistoryState(error: message);

  bool get hasReadings => readings.isNotEmpty;
  bool get hasError => error != null;
}

/// Notifier for managing reading history.
class ReadingHistoryNotifier extends StateNotifier<ReadingHistoryState> {
  final TarotApiService _apiService;

  ReadingHistoryNotifier(this._apiService) : super(ReadingHistoryState.initial());

  /// Fetches all readings for a user.
  Future<void> fetchUserReadings(String userId) async {
    state = ReadingHistoryState.loading();

    try {
      final readings = await _apiService.getUserReadings(userId);
      state = ReadingHistoryState.success(readings);
    } on TarotApiException catch (e) {
      state = ReadingHistoryState.error(e.message);
    } catch (e) {
      state = ReadingHistoryState.error('Geçmiş okumaları yüklenemedi.');
    }
  }

  /// Adds a new reading to the history (locally).
  void addReading(TarotReadingModel reading) {
    state = ReadingHistoryState.success([reading, ...state.readings]);
  }

  /// Clears the history.
  void clearHistory() {
    state = ReadingHistoryState.initial();
  }
}

/// Provider for user's reading history.
final readingHistoryProvider =
    StateNotifierProvider<ReadingHistoryNotifier, ReadingHistoryState>((ref) {
  final apiService = ref.watch(tarotApiServiceProvider);
  return ReadingHistoryNotifier(apiService);
});
