import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model representing a location suggestion from the geocoding API.
class LocationSuggestion {
  final String name;
  final String country;
  final String? admin1; // State/Province
  final double latitude;
  final double longitude;
  final String? timezone;

  const LocationSuggestion({
    required this.name,
    required this.country,
    this.admin1,
    required this.latitude,
    required this.longitude,
    this.timezone,
  });

  /// Formatted display name (e.g., "Istanbul, Turkey" or "Paris, Île-de-France, France")
  String get displayName {
    if (admin1 != null && admin1!.isNotEmpty && admin1 != name) {
      return '$name, $admin1, $country';
    }
    return '$name, $country';
  }

  /// Short display name (e.g., "Istanbul, Turkey")
  String get shortName => '$name, $country';

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      admin1: json['admin1'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      timezone: json['timezone'],
    );
  }

  @override
  String toString() => displayName;
}

/// Service for fetching location suggestions using OpenMeteo Geocoding API.
///
/// This is a free API that doesn't require API keys.
/// Endpoint: https://geocoding-api.open-meteo.com/v1/search
class LocationService {
  static const String _baseUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const int _defaultCount = 8;
  static const Duration _timeout = Duration(seconds: 10);

  /// Debounce timer for search requests
  Timer? _debounceTimer;

  /// Cached results to avoid redundant API calls
  final Map<String, List<LocationSuggestion>> _cache = {};

  /// Fetch location suggestions for a search query.
  ///
  /// Returns a list of [LocationSuggestion] matching the query.
  /// Results are cached to improve performance.
  Future<List<LocationSuggestion>> searchLocations(
    String query, {
    int count = _defaultCount,
    String? language,
  }) async {
    // Validate query
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return [];
    }

    // Check cache
    final cacheKey = '${trimmedQuery.toLowerCase()}_$count';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Build URL with query parameters
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'name': trimmedQuery,
        'count': count.toString(),
        'format': 'json',
        if (language != null) 'language': language,
      });

      // Make HTTP request
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch locations: ${response.statusCode}');
      }

      // Parse response
      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;

      if (results == null || results.isEmpty) {
        return [];
      }

      // Convert to LocationSuggestion objects
      final suggestions = results
          .map((json) => LocationSuggestion.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache results
      _cache[cacheKey] = suggestions;

      return suggestions;
    } catch (e) {
      print('LocationService error: $e');
      return [];
    }
  }

  /// Search with debounce - useful for real-time search as user types.
  ///
  /// [query] - The search query
  /// [onResults] - Callback with the results
  /// [debounceMs] - Debounce delay in milliseconds (default: 500ms)
  void searchWithDebounce(
    String query, {
    required void Function(List<LocationSuggestion>) onResults,
    int debounceMs = 500,
  }) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Don't search for very short queries
    if (query.trim().length < 2) {
      onResults([]);
      return;
    }

    // Set up new debounced search
    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () async {
      final results = await searchLocations(query);
      onResults(results);
    });
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }

  /// Cancel any pending debounced search
  void cancelPendingSearch() {
    _debounceTimer?.cancel();
  }

  /// Dispose of resources
  void dispose() {
    _debounceTimer?.cancel();
    _cache.clear();
  }
}

/// Singleton instance of LocationService
final locationService = LocationService();
