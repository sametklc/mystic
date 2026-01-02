import 'dart:async';
import 'dart:convert';
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
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/astrology/synastry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user1': user1Data,
          'user2': user2Data,
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
}
