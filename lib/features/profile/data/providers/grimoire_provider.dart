import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../core/services/firestore_reading_service.dart';
import '../../../../core/services/reading_persistence_service.dart';
import '../../domain/models/grimoire_entry_model.dart';

/// State class for the Grimoire.
class GrimoireState {
  final List<GrimoireEntryModel> entries;
  final bool isLoading;
  final String? error;

  const GrimoireState({
    this.entries = const [],
    this.isLoading = false,
    this.error,
  });

  factory GrimoireState.initial() => const GrimoireState();

  factory GrimoireState.loading() => const GrimoireState(isLoading: true);

  GrimoireState copyWith({
    List<GrimoireEntryModel>? entries,
    bool? isLoading,
    String? error,
  }) {
    return GrimoireState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasEntries => entries.isNotEmpty;
  bool get hasError => error != null;

  /// Get only entries with images for the gallery.
  List<GalleryArtModel> get galleryItems {
    return entries
        .where((e) => e.hasImage)
        .map((e) => GalleryArtModel.fromGrimoireEntry(e))
        .toList();
  }
}

/// Notifier for managing Grimoire state.
class GrimoireNotifier extends StateNotifier<GrimoireState> {
  final FirestoreReadingService _firestoreService;
  final ReadingPersistenceService _persistenceService;
  final String _deviceId;

  GrimoireNotifier({
    required FirestoreReadingService firestoreService,
    required ReadingPersistenceService persistenceService,
    required String deviceId,
  })  : _firestoreService = firestoreService,
        _persistenceService = persistenceService,
        _deviceId = deviceId,
        super(GrimoireState.initial()) {
    // Load data from Firestore on init
    _loadFromFirestore();
  }

  /// Loads entries from Firestore.
  Future<void> _loadFromFirestore() async {
    state = GrimoireState.loading();

    try {
      final entries = await _firestoreService.getReadings(_deviceId);
      state = GrimoireState(entries: entries);
    } catch (e) {
      print('Error loading grimoire from Firestore: $e');
      state = GrimoireState(error: 'Failed to load readings');
    }
  }

  /// Refresh the grimoire data from Firestore.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);

    try {
      final entries = await _firestoreService.getReadings(_deviceId);
      state = GrimoireState(entries: entries);
    } catch (e) {
      print('Error refreshing grimoire: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to refresh');
    }
  }

  /// Add a new entry to the grimoire (locally, already saved to Firestore).
  void addEntry(GrimoireEntryModel entry) {
    state = state.copyWith(
      entries: [entry, ...state.entries],
    );
  }

  /// Delete an entry from the grimoire.
  Future<void> deleteEntry(String id) async {
    try {
      await _persistenceService.deleteReading(
        userId: _deviceId,
        readingId: id,
      );
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != id).toList(),
      );
    } catch (e) {
      print('Error deleting entry: $e');
    }
  }
}

/// Main provider for Grimoire.
final grimoireProvider = StateNotifierProvider<GrimoireNotifier, GrimoireState>(
  (ref) {
    final firestoreService = ref.watch(firestoreReadingServiceProvider);
    final persistenceService = ref.watch(readingPersistenceServiceProvider);
    final deviceId = ref.watch(deviceIdProvider);
    return GrimoireNotifier(
      firestoreService: firestoreService,
      persistenceService: persistenceService,
      deviceId: deviceId,
    );
  },
);

/// Provider for gallery items only.
final galleryItemsProvider = Provider<List<GalleryArtModel>>((ref) {
  return ref.watch(grimoireProvider).galleryItems;
});

/// Provider for journal entries.
final journalEntriesProvider = Provider<List<GrimoireEntryModel>>((ref) {
  return ref.watch(grimoireProvider).entries;
});
