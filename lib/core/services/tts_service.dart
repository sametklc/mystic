import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Exception for TTS API errors.
class TTSException implements Exception {
  final String message;
  final int? statusCode;

  TTSException(this.message, {this.statusCode});

  @override
  String toString() => 'TTSException: $message';
}

/// Service for text-to-speech API calls.
class TTSService {
  static const String _baseUrl = 'https://mystic-api-0ssv.onrender.com';
  // For local dev: 'http://localhost:8000';

  final http.Client _client;

  TTSService({http.Client? client}) : _client = client ?? http.Client();

  /// Check if TTS service is available.
  Future<bool> isAvailable() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/tts/health'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['configured'] == true;
      }
      return false;
    } catch (e) {
      print('TTS health check failed: $e');
      return false;
    }
  }

  /// Synthesize speech and return a local file path.
  /// This downloads the audio and saves it locally for playback.
  Future<String?> synthesizeSpeech({
    required String text,
    String characterId = 'madame_luna',
    bool useCache = true,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/tts/speak'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'character_id': characterId,
          'use_cache': useCache,
          'stream': false, // Get full file for mobile playback
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Save audio to temporary file
        final tempDir = await getTemporaryDirectory();
        final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        return file.path;
      } else {
        throw TTSException(
          'Failed to synthesize speech',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is TTSException) rethrow;
      throw TTSException('TTS error: $e');
    }
  }

  /// Get the streaming URL for audio playback.
  /// This returns a URL that can be used with just_audio for streaming.
  String getStreamingUrl({
    required String text,
    String characterId = 'madame_luna',
  }) {
    final encodedText = Uri.encodeComponent(text);
    return '$_baseUrl/tts/speak?text=$encodedText&character_id=$characterId&stream=true';
  }

  /// Get available character voices.
  Future<List<Map<String, dynamic>>> getAvailableVoices() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/tts/voices'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['voices'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching voices: $e');
      return [];
    }
  }
}

/// Provider for TTS service singleton.
final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});

/// Provider for TTS availability check.
final ttsAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  return service.isAvailable();
});
