import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/daily_insight_model.dart';
import '../../domain/models/natal_chart_model.dart';
import '../../domain/models/synastry_model.dart';

/// Exception for astrology API errors.
class AstrologyApiException implements Exception {
  final String message;
  final int? statusCode;

  AstrologyApiException(this.message, {this.statusCode});

  @override
  String toString() => 'AstrologyApiException: $message';
}

/// Service for astrology API calls.
///
/// Handles all Sky Hall features:
/// - Natal chart calculation
/// - Synastry compatibility
/// - Personal daily horoscopes (with caching)
/// - Astro-Guide chat (Nova) with summarization-based memory
class AstrologyApiService {
  static const String _baseUrl = 'https://mystic-api-0ssv.onrender.com';
  // For local dev: 'http://localhost:8000';

  // Longer timeout for Render.com free tier (server may be sleeping)
  static const Duration _timeout = Duration(seconds: 60);

  final http.Client _client;

  AstrologyApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Calculate natal chart from birth data.
  Future<NatalChart> calculateNatalChart({
    required String date,
    required String time,
    required double latitude,
    required double longitude,
    String timezone = 'UTC',
    String? name,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/astrology/natal-chart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date': date,
          'time': time,
          'latitude': latitude,
          'longitude': longitude,
          'timezone': timezone,
          if (name != null) 'name': name,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NatalChart.fromJson(data);
      } else {
        throw AstrologyApiException(
          'Failed to calculate natal chart (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again in a moment');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: Server may be offline');
    }
  }

  /// Calculate synastry compatibility between two people.
  Future<SynastryReport> calculateSynastry({
    required Map<String, dynamic> user1Data,
    required Map<String, dynamic> user2Data,
    String? characterId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/astrology/synastry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user1': user1Data,
          'user2': user2Data,
          if (characterId != null) 'character_id': characterId,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SynastryReport.fromJson(data);
      } else {
        throw AstrologyApiException(
          'Failed to calculate synastry (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again in a moment');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: Server may be offline');
    }
  }

  /// Get the daily cosmic insight.
  ///
  /// Optionally provide a date in YYYY-MM-DD format, defaults to today.
  Future<DailyInsight> getDailyInsight({String? date}) async {
    try {
      final uri = Uri.parse('$_baseUrl/astrology/daily-insight').replace(
        queryParameters: date != null ? {'date_str': date} : null,
      );

      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DailyInsight.fromJson(data);
      } else {
        throw AstrologyApiException(
          'Failed to get daily insight (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: Server may be offline');
    }
  }

  // =========================================================================
  // Personal Daily Horoscope (with Backend Caching)
  // =========================================================================

  /// Fetches a personalized daily horoscope based on the user's natal chart.
  ///
  /// Uses backend caching - if horoscope was already generated today,
  /// returns cached version (zero OpenAI cost).
  ///
  /// [userId] - User's unique identifier for caching.
  /// [birthDate] - Birth date in YYYY-MM-DD format.
  /// [birthTime] - Birth time in HH:MM format.
  /// [birthLatitude] - Birth location latitude.
  /// [birthLongitude] - Birth location longitude.
  /// [birthTimezone] - Birth location timezone.
  /// [name] - User's name for personalization.
  /// [targetDate] - Date for horoscope (defaults to today).
  ///
  /// Returns a map with:
  /// - forecast: AI-generated personalized text
  /// - cosmic_vibe: Today's energy description
  /// - focus_areas: Life areas to focus on
  /// - active_transits: Current planetary aspects
  /// - is_cached: Whether served from cache
  Future<Map<String, dynamic>> getPersonalHoroscope({
    required String userId,
    required String birthDate,
    required String birthTime,
    required double birthLatitude,
    required double birthLongitude,
    String birthTimezone = 'UTC',
    String? name,
    String? targetDate,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/astrology/personal-horoscope'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'birth_date': birthDate,
          'birth_time': birthTime,
          'birth_latitude': birthLatitude,
          'birth_longitude': birthLongitude,
          'birth_timezone': birthTimezone,
          if (name != null) 'name': name,
          if (targetDate != null) 'target_date': targetDate,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          throw AstrologyApiException(
            data['error'] as String? ?? 'Could not generate horoscope',
          );
        }
      } else {
        throw AstrologyApiException(
          'Horoscope generation failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: $e');
    }
  }

  // =========================================================================
  // Astro-Guide Chat (Nova) with Summarization-Based Memory
  // =========================================================================

  /// Sends a message to the Astro-Guide (Nova) and receives a chart-based response.
  ///
  /// Uses conversation summarization for "infinite memory":
  /// - Backend maintains a running summary of the conversation
  /// - Each response updates the summary asynchronously
  /// - Nova remembers context from many messages ago without token cost
  ///
  /// [userId] - User's unique identifier for session tracking.
  /// [sessionId] - Unique chat session ID.
  /// [message] - The user's question.
  /// [birthDate] - Birth date in YYYY-MM-DD format.
  /// [birthTime] - Birth time in HH:MM format.
  /// [birthLatitude] - Birth location latitude.
  /// [birthLongitude] - Birth location longitude.
  /// [birthTimezone] - Birth location timezone.
  /// [name] - User's name.
  ///
  /// Returns a map with:
  /// - response: Nova's AI-generated answer
  /// - sun_sign, moon_sign, rising_sign: User's Big Three
  /// - session_id: Chat session ID for continuity
  Future<Map<String, dynamic>> sendAstroGuideChat({
    required String userId,
    required String sessionId,
    required String message,
    required String birthDate,
    required String birthTime,
    required double birthLatitude,
    required double birthLongitude,
    String birthTimezone = 'UTC',
    String? name,
    String? characterId,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/sky-hall/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'session_id': sessionId,
          'message': message,
          'birth_date': birthDate,
          'birth_time': birthTime,
          'birth_latitude': birthLatitude,
          'birth_longitude': birthLongitude,
          'birth_timezone': birthTimezone,
          if (name != null) 'name': name,
          if (characterId != null) 'character_id': characterId,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          throw AstrologyApiException(
            data['error'] as String? ?? 'Could not get response',
          );
        }
      } else {
        throw AstrologyApiException(
          'Chat request failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: $e');
    }
  }

  /// Starts a new chat session with Nova.
  ///
  /// Returns a new session_id that should be used for subsequent messages.
  /// This clears the conversation history and summary in Firestore.
  Future<String> startNewChatSession({required String userId}) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/sky-hall/chat/new-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['session_id'] as String? ??
            'session_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('Failed to start new chat session: $e');
    }
    // Generate client-side session ID as fallback
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  // =========================================================================
  // Chat History (Full Persistence)
  // =========================================================================

  /// Fetches the chat history for a user.
  ///
  /// Returns all messages from Firestore for initial load.
  /// For real-time updates, use Firestore streams directly.
  ///
  /// [userId] - User's unique identifier.
  /// [limit] - Maximum number of messages to fetch (default: 100).
  ///
  /// Returns a map with:
  /// - messages: List of {id, role, content, timestamp}
  /// - total_count: Total number of messages
  /// - has_summary: Whether a conversation summary exists
  Future<Map<String, dynamic>> getChatHistory({
    required String userId,
    int limit = 100,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/sky-hall/chat/history/$userId?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          throw AstrologyApiException(
            data['error'] as String? ?? 'Could not fetch history',
          );
        }
      } else {
        throw AstrologyApiException(
          'History fetch failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: $e');
    }
  }

  /// Clears all chat history for a user.
  ///
  /// Deletes all messages and resets the conversation summary.
  Future<void> clearChatHistory({required String userId}) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/sky-hall/chat/history/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw AstrologyApiException(
          'Failed to clear history (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw AstrologyApiException('Server is waking up, please try again');
    } catch (e) {
      if (e is AstrologyApiException) rethrow;
      throw AstrologyApiException('Connection error: $e');
    }
  }
}

// Provider is defined in sky_hall_provider.dart to avoid duplicate exports
