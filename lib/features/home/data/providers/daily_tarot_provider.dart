import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/device_id_service.dart';
import '../../../../core/utils/mystic_date_utils.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../tarot/data/services/tarot_api_service.dart';
import '../../../tarot/data/providers/tarot_provider.dart';

/// SharedPreferences key prefix for daily readings (local cache)
const String _dailyReadingKeyPrefix = 'daily_reading_';

/// Model for daily tarot card reading.
class DailyTarot {
  final String date;
  final String cardName;
  final String cardImage;
  final bool isUpright;
  final String interpretation;
  final String summary;
  final String characterId;
  final bool isNew;
  final DateTime? revealedAt;

  const DailyTarot({
    required this.date,
    required this.cardName,
    required this.cardImage,
    required this.isUpright,
    required this.interpretation,
    required this.summary,
    required this.characterId,
    this.isNew = true,
    this.revealedAt,
  });

  factory DailyTarot.fromJson(Map<String, dynamic> json) {
    return DailyTarot(
      date: json['date'] as String? ?? '',
      cardName: json['card_name'] as String? ?? 'The Fool',
      cardImage: json['card_image'] as String? ?? 'assets/cards/major/00_fool.png',
      isUpright: json['is_upright'] as bool? ?? true,
      interpretation: json['interpretation'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      characterId: json['character_id'] as String? ?? 'madame_luna',
      isNew: json['is_new'] as bool? ?? true,
      revealedAt: json['revealed_at'] != null
          ? (json['revealed_at'] is Timestamp
              ? (json['revealed_at'] as Timestamp).toDate()
              : DateTime.tryParse(json['revealed_at'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'card_name': cardName,
      'card_image': cardImage,
      'is_upright': isUpright,
      'interpretation': interpretation,
      'summary': summary,
      'character_id': characterId,
      'is_new': isNew,
      'revealed_at': revealedAt?.toIso8601String(),
    };
  }

  /// For Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'card_name': cardName,
      'card_image': cardImage,
      'is_upright': isUpright,
      'interpretation': interpretation,
      'summary': summary,
      'character_id': characterId,
      'revealed_at': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with isNew set to false (for cached readings)
  DailyTarot copyWithNotNew() {
    return DailyTarot(
      date: date,
      cardName: cardName,
      cardImage: cardImage,
      isUpright: isUpright,
      interpretation: interpretation,
      summary: summary,
      characterId: characterId,
      isNew: false,
      revealedAt: revealedAt,
    );
  }
}

/// State for daily tarot card.
enum DailyTarotStatus { initial, loading, revealed, error }

class DailyTarotState {
  final DailyTarotStatus status;
  final DailyTarot? dailyTarot;
  final String? error;
  /// Whether this is the first reveal of the day (for animation)
  final bool isFirstReveal;

  const DailyTarotState({
    this.status = DailyTarotStatus.initial,
    this.dailyTarot,
    this.error,
    this.isFirstReveal = false,
  });

  bool get isLoading => status == DailyTarotStatus.loading;
  bool get isRevealed => status == DailyTarotStatus.revealed;
  bool get hasError => status == DailyTarotStatus.error;

  DailyTarotState copyWith({
    DailyTarotStatus? status,
    DailyTarot? dailyTarot,
    String? error,
    bool? isFirstReveal,
  }) {
    return DailyTarotState(
      status: status ?? this.status,
      dailyTarot: dailyTarot ?? this.dailyTarot,
      error: error ?? this.error,
      isFirstReveal: isFirstReveal ?? this.isFirstReveal,
    );
  }
}

/// Notifier for managing daily tarot state with Firestore persistence.
///
/// Uses the "Mystic Day" concept where day resets at 7 AM.
/// Each profile has its own daily reading.
class DailyTarotNotifier extends StateNotifier<DailyTarotState> {
  final TarotApiService _apiService;
  final String _deviceId;
  final String? _profileId;
  final FirebaseFirestore _firestore;

  DailyTarotNotifier(this._apiService, this._deviceId, this._profileId)
      : _firestore = FirebaseFirestore.instance,
        super(const DailyTarotState()) {
    // Check Firestore on initialization
    _checkExistingReading();
  }

  /// Get the Firestore document reference for today's reading (profile-specific)
  DocumentReference get _todayDocRef {
    final mysticDate = getMysticDateString();
    final profileId = _profileId ?? 'default';
    return _firestore
        .collection('users')
        .doc(_deviceId)
        .collection('profiles')
        .doc(profileId)
        .collection('daily_tarot')
        .doc(mysticDate);
  }

  /// Get SharedPreferences key for today (local cache backup, profile-specific)
  String get _todayKey {
    final profileId = _profileId ?? 'default';
    return '$_dailyReadingKeyPrefix${profileId}_${getMysticDateString()}';
  }

  /// Check if we have an existing reading for the current Mystic Day
  Future<void> _checkExistingReading() async {
    try {
      // First try Firestore
      final doc = await _todayDocRef.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final dailyTarot = DailyTarot.fromJson(data).copyWithNotNew();

        print('Daily Tarot: Found existing reading in Firestore for ${getMysticDateString()}');

        state = DailyTarotState(
          status: DailyTarotStatus.revealed,
          dailyTarot: dailyTarot,
          isFirstReveal: false, // Already revealed before
        );
        return;
      }

      // Fallback to local SharedPreferences
      final cached = await _getLocalCache();
      if (cached != null) {
        print('Daily Tarot: Found local cache for ${getMysticDateString()}');
        state = DailyTarotState(
          status: DailyTarotStatus.revealed,
          dailyTarot: cached,
          isFirstReveal: false,
        );
        return;
      }

      // No existing reading - stay in initial state
      print('Daily Tarot: No reading found for ${getMysticDateString()}');
    } catch (e) {
      print('Daily Tarot: Error checking existing reading: $e');
      // Try local cache as fallback
      final cached = await _getLocalCache();
      if (cached != null) {
        state = DailyTarotState(
          status: DailyTarotStatus.revealed,
          dailyTarot: cached,
          isFirstReveal: false,
        );
      }
    }
  }

  /// Get reading from local SharedPreferences cache
  Future<DailyTarot?> _getLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_todayKey);

      if (cachedJson != null) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        return DailyTarot.fromJson(data).copyWithNotNew();
      }
    } catch (e) {
      print('Daily Tarot: Error reading local cache: $e');
    }
    return null;
  }

  /// Save reading to local SharedPreferences (backup)
  Future<void> _saveLocalCache(DailyTarot reading) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todayKey, jsonEncode(reading.toJson()));
      await _cleanupOldLocalCache(prefs);
    } catch (e) {
      print('Daily Tarot: Error saving local cache: $e');
    }
  }

  /// Remove local cache entries older than 7 days
  Future<void> _cleanupOldLocalCache(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((k) => k.startsWith(_dailyReadingKeyPrefix)).toList();
    final today = DateTime.now();

    for (final key in keys) {
      try {
        final dateStr = key.replaceFirst(_dailyReadingKeyPrefix, '');
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final readingDate = DateTime(year, month, day);

          if (today.difference(readingDate).inDays > 7) {
            await prefs.remove(key);
          }
        }
      } catch (_) {}
    }
  }

  /// Draw and reveal the daily tarot card.
  ///
  /// Returns true if this is a new reveal (for animation purposes).
  Future<bool> drawDailyCard({String? characterId}) async {
    if (state.isLoading) return false;

    // If already revealed, don't re-fetch
    if (state.isRevealed && state.dailyTarot != null) {
      return false;
    }

    state = const DailyTarotState(status: DailyTarotStatus.loading);

    try {
      // Double-check Firestore (in case another device revealed)
      final doc = await _todayDocRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final dailyTarot = DailyTarot.fromJson(data).copyWithNotNew();

        state = DailyTarotState(
          status: DailyTarotStatus.revealed,
          dailyTarot: dailyTarot,
          isFirstReveal: false,
        );
        return false;
      }

      // Fetch new reading from API
      print('Daily Tarot: Fetching new reading from API');
      final response = await _apiService.getDailyTarot(
        deviceId: _deviceId,
        characterId: characterId ?? 'madame_luna',
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out'),
      );

      final dailyTarot = DailyTarot.fromJson({
        ...response,
        'date': getMysticDateString(),
      });

      // Save to Firestore
      await _todayDocRef.set(dailyTarot.toFirestore());

      // Save to local cache as backup
      await _saveLocalCache(dailyTarot);

      state = DailyTarotState(
        status: DailyTarotStatus.revealed,
        dailyTarot: dailyTarot,
        isFirstReveal: true, // This is the first reveal!
      );

      return true; // New reveal
    } on TarotApiException catch (e) {
      print('Daily Tarot API error: $e');
      return await _handleFallback();
    } catch (e) {
      print('Daily Tarot error: $e');
      return await _handleFallback();
    }
  }

  /// Handle fallback when API fails
  Future<bool> _handleFallback() async {
    final fallback = _generateFallbackReading();

    try {
      await _todayDocRef.set(fallback.toFirestore());
    } catch (_) {}

    await _saveLocalCache(fallback);

    state = DailyTarotState(
      status: DailyTarotStatus.revealed,
      dailyTarot: fallback,
      isFirstReveal: true,
    );

    return true;
  }

  /// Generate a fallback reading when API is unavailable
  DailyTarot _generateFallbackReading() {
    final cards = [
      'The Fool', 'The Magician', 'The High Priestess', 'The Empress',
      'The Emperor', 'The Hierophant', 'The Lovers', 'The Chariot',
      'Strength', 'The Hermit', 'Wheel of Fortune', 'Justice',
      'The Hanged Man', 'Death', 'Temperance', 'The Devil',
      'The Tower', 'The Star', 'The Moon', 'The Sun', 'Judgement', 'The World',
    ];

    final messages = [
      'Today brings new beginnings. Trust your intuition and take that first step.',
      'You have all the tools you need. Channel your energy wisely.',
      'Look within for answers. Your inner wisdom knows the way.',
      'Abundance surrounds you. Nurture your creative projects.',
      'Take charge of your situation. Structure leads to success.',
      'Seek guidance from those you trust. Tradition has wisdom.',
      'A choice awaits. Follow your heart with open eyes.',
      'Victory through determination. Stay focused on your goals.',
      'Inner strength prevails. Courage comes from compassion.',
      'Solitude brings clarity. Take time for reflection.',
      'Change is inevitable. Embrace the cycles of life.',
      'Balance and fairness guide your path. Seek truth.',
      'A new perspective awaits. Let go to gain insight.',
      'Transformation is at hand. Endings birth new beginnings.',
      'Patience and balance. Moderation leads to harmony.',
      'Examine what binds you. Freedom comes through awareness.',
      'Sudden change clears the path. Rebuild stronger.',
      'Hope shines bright. Follow your guiding star.',
      'Trust your dreams. Not everything is as it seems.',
      'Joy and success await. Let your light shine.',
      'A calling awaits. Answer with courage.',
      'Completion and fulfillment. Celebrate your journey.',
    ];

    final mysticDate = getMysticDateString();
    final now = DateTime.now();
    final index = (now.day + now.month) % cards.length;
    final isUpright = now.hour % 3 != 0;

    return DailyTarot(
      date: mysticDate,
      cardName: cards[index],
      cardImage: 'assets/cards/major/${index.toString().padLeft(2, '0')}_${cards[index].toLowerCase().replaceAll(' ', '_')}.png',
      isUpright: isUpright,
      interpretation: messages[index],
      summary: messages[index].split('.')[0],
      characterId: 'madame_luna',
      isNew: true,
      revealedAt: now,
    );
  }

  /// Mark that the reveal animation has been seen
  void markRevealSeen() {
    if (state.isFirstReveal) {
      state = state.copyWith(isFirstReveal: false);
    }
  }

  /// Reset the state (for testing/debugging)
  void reset() {
    state = const DailyTarotState();
  }

  /// Force refresh - clears cache and fetches new reading
  /// WARNING: This should only be used for testing
  Future<void> forceRefresh({String? characterId}) async {
    try {
      await _todayDocRef.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_todayKey);
    } catch (_) {}

    state = const DailyTarotState();
    await drawDailyCard(characterId: characterId);
  }
}

/// Main provider for daily tarot state.
/// Automatically resets when profile changes.
final dailyTarotProvider =
    StateNotifierProvider<DailyTarotNotifier, DailyTarotState>((ref) {
  final apiService = ref.watch(tarotApiServiceProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final profile = ref.watch(currentProfileProvider);

  // This will recreate the notifier when profile changes
  return DailyTarotNotifier(apiService, deviceId, profile?.id);
});
