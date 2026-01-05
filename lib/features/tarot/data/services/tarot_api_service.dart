import 'package:dio/dio.dart';
import '../../domain/models/tarot_card_model.dart';
import '../../domain/models/tarot_reading_model.dart';

/// Exception thrown when a Tarot API request fails.
class TarotApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const TarotApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'TarotApiException: $message (status: $statusCode)';
}

/// Spread types available for tarot readings.
enum SpreadType {
  single('single'),
  threeCard('three_card'),
  celticCross('celtic_cross');

  final String value;
  const SpreadType(this.value);
}

/// Service for communicating with the Tarot Backend API.
class TarotApiService {
  static const String _baseUrl = 'https://mystic-api-0ssv.onrender.com';

  late final Dio _dio;

  TarotApiService({Dio? dio}) {
    _dio = dio ?? Dio(_defaultOptions);
  }

  static BaseOptions get _defaultOptions => BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120), // AI generation can take time
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

  /// Updates the base URL (useful for switching environments).
  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }

  /// Sets the authorization token for authenticated requests.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Generates a new tarot reading.
  ///
  /// [userId] - The user's unique identifier.
  /// [question] - The question to ask the tarot.
  /// [spreadType] - Type of tarot spread (default: single card).
  /// [visionaryMode] - Whether to generate AI artwork (default: true).
  /// [cardName] - The name of the selected card.
  /// [isUpright] - Whether the card is upright or reversed.
  /// [characterId] - The Oracle character ID.
  ///
  /// Returns a [TarotReadingModel] with the generated reading.
  /// Throws [TarotApiException] if the request fails.
  Future<TarotReadingModel> generateReading({
    required String userId,
    required String question,
    SpreadType spreadType = SpreadType.single,
    bool visionaryMode = true,
    String? cardName,
    bool isUpright = true,
    String characterId = 'madame_luna',
  }) async {
    try {
      // Step 1: Get the tarot reading interpretation
      final readingResponse = await _dio.post(
        '/tarot/reading',
        data: {
          'question': question,
          'character_id': characterId,
          'spread_type': spreadType.value,
          'cards': cardName != null ? [cardName] : [],
          'card_name': cardName,
          'is_upright': isUpright,
        },
      );

      if (readingResponse.statusCode != 200) {
        throw TarotApiException(
          message: 'Okuma oluşturulamadı: ${readingResponse.statusCode}',
          statusCode: readingResponse.statusCode,
        );
      }

      final readingData = readingResponse.data as Map<String, dynamic>;

      if (readingData['success'] != true) {
        throw TarotApiException(
          message: readingData['error'] as String? ?? 'Okuma başarısız oldu',
        );
      }

      // Step 2: If visionary mode, generate AI image
      String? imageUrl;
      if (visionaryMode) {
        try {
          imageUrl = await _generateVisualization(
            question: question,
            cardName: cardName,
          );
        } catch (e) {
          // Image generation failed, but we still have the reading
          // Continue without image
        }
      }

      // Step 3: Create the reading model
      final reading = readingData['reading'] as String? ?? '';
      final cardsInterpreted = (readingData['cards_interpreted'] as List<dynamic>?) ?? [];

      // Create card model from the selected card
      final cards = <TarotCardModel>[];
      if (cardName != null) {
        cards.add(TarotCardModel(
          name: cardName,
          meaning: reading,
          imageUrl: imageUrl ?? '',
          isUpright: isUpright,
        ));
      }

      return TarotReadingModel(
        id: 'reading_${DateTime.now().millisecondsSinceEpoch}',
        question: question,
        cards: cards,
        interpretation: reading,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is TarotApiException) rethrow;
      throw TarotApiException(
        message: 'Beklenmeyen bir hata oluştu: $e',
        originalError: e,
      );
    }
  }

  /// Generates an AI visualization for the tarot reading.
  Future<String?> _generateVisualization({
    required String question,
    String? cardName,
  }) async {
    try {
      final prompt = cardName != null
          ? 'Mystical tarot card: $cardName. A seeker asks: "$question". Ethereal cosmic imagery, purple and gold tones, mystical atmosphere.'
          : 'Mystical tarot reading visualization. Question: "$question". Ethereal cosmic imagery, purple and gold tones.';

      final response = await _dio.post(
        '/tarot/visualize',
        data: {
          'prompt': prompt,
          'style': 'mystical',
          'character_id': 'madame_luna',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['image_url'] != null) {
          final imageUrl = data['image_url'] as String;
          // Make sure it's a valid URL
          if (imageUrl.startsWith('http')) {
            return imageUrl;
          }
        }
      }
    } catch (e) {
      // Visualization failed, will use fallback
    }

    return null;
  }

  /// Fetches a previously generated reading by ID.
  Future<TarotReadingModel> getReading(String readingId) async {
    try {
      final response = await _dio.get('/readings/$readingId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return TarotReadingModel.fromJson(data);
      } else {
        throw TarotApiException(
          message: 'Reading not found',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetches all readings for a user.
  Future<List<TarotReadingModel>> getUserReadings(String userId) async {
    try {
      final response = await _dio.get(
        '/readings',
        queryParameters: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>;
        return data
            .map((json) => TarotReadingModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw TarotApiException(
          message: 'Failed to fetch readings',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetches the daily tarot card reading for a user.
  ///
  /// This is a "Card of the Day" feature:
  /// - If the user already drew today's card, returns the cached reading
  /// - Otherwise, draws a new random card and generates interpretation
  ///
  /// [deviceId] - The user's device identifier.
  /// [characterId] - The Oracle character (default: 'madame_luna').
  ///
  /// Returns a map with the daily reading data.
  /// Throws [TarotApiException] if the request fails.
  Future<Map<String, dynamic>> getDailyTarot({
    required String deviceId,
    String characterId = 'madame_luna',
  }) async {
    try {
      final response = await _dio.get(
        '/tarot/daily',
        queryParameters: {
          'device_id': deviceId,
          'character_id': characterId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data;
        } else {
          throw TarotApiException(
            message: data['error'] as String? ?? 'Could not get daily card',
          );
        }
      } else {
        throw TarotApiException(
          message: 'Could not get daily card: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is TarotApiException) rethrow;
      throw TarotApiException(
        message: 'Error getting daily card: $e',
        originalError: e,
      );
    }
  }

  /// Sends a message to the Oracle and receives a response.
  ///
  /// [chatId] - The unique chat session ID.
  /// [message] - The user's message.
  /// [characterId] - The Oracle character (e.g., 'madame_luna').
  /// [readingContext] - Optional context from the tarot reading.
  /// [conversationHistory] - Optional list of previous messages for context.
  ///
  /// Returns the Oracle's response text.
  Future<String> sendChatMessage({
    required String chatId,
    required String message,
    required String characterId,
    String? readingContext,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    try {
      final response = await _dio.post(
        '/chat/message',
        data: {
          'chat_id': chatId,
          'message': message,
          'character_id': characterId,
          if (readingContext != null) 'context': readingContext,
          if (conversationHistory != null && conversationHistory.isNotEmpty)
            'conversation_history': conversationHistory,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['response'] as String? ?? data['message'] as String? ?? '';
        } else {
          throw TarotApiException(
            message: data['error'] as String? ?? 'Mesaj gönderilemedi',
          );
        }
      } else {
        throw TarotApiException(
          message: 'Beklenmeyen yanıt: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is TarotApiException) rethrow;
      throw TarotApiException(
        message: 'Mesaj gönderilemedi: $e',
        originalError: e,
      );
    }
  }

  // NOTE: Personal horoscope and Astro-Guide chat methods have been moved to
  // AstrologyApiService in lib/features/sky_hall/data/services/astrology_api_service.dart
  // for better separation of concerns.

  /// Converts DioException to TarotApiException with user-friendly messages.
  TarotApiException _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TarotApiException(
          message: 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.',
          statusCode: null,
          originalError: e,
        );

      case DioExceptionType.connectionError:
        return TarotApiException(
          message: 'İnternet bağlantınızı kontrol edin.',
          statusCode: null,
          originalError: e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        String message;
        if (statusCode == 401) {
          message = 'Oturum süreniz doldu. Lütfen tekrar giriş yapın.';
        } else if (statusCode == 403) {
          message = 'Bu işlem için yetkiniz yok.';
        } else if (statusCode == 404) {
          message = 'İstenen kaynak bulunamadı.';
        } else if (statusCode == 429) {
          message = 'Çok fazla istek gönderildi. Lütfen biraz bekleyin.';
        } else if (statusCode != null && statusCode >= 500) {
          message = 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
        } else if (responseData is Map && responseData['message'] != null) {
          message = responseData['message'].toString();
        } else {
          message = 'Bir hata oluştu: $statusCode';
        }

        return TarotApiException(
          message: message,
          statusCode: statusCode,
          originalError: e,
        );

      case DioExceptionType.cancel:
        return TarotApiException(
          message: 'İstek iptal edildi.',
          originalError: e,
        );

      default:
        return TarotApiException(
          message: 'Beklenmeyen bir hata oluştu.',
          originalError: e,
        );
    }
  }
}
