import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tarot/data/providers/tarot_provider.dart';
import '../../../tarot/data/services/tarot_api_service.dart';
import '../../domain/models/chat_message_model.dart';

/// State class for the Oracle chat.
class ChatState {
  final String chatId;
  final String characterId;
  final List<ChatMessageModel> messages;
  final bool isLoading;
  final String? error;
  final String? readingContext;

  const ChatState({
    required this.chatId,
    required this.characterId,
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.readingContext,
  });

  factory ChatState.initial({
    required String characterId,
    String? readingContext,
  }) {
    return ChatState(
      chatId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      characterId: characterId,
      readingContext: readingContext,
    );
  }

  ChatState copyWith({
    String? chatId,
    String? characterId,
    List<ChatMessageModel>? messages,
    bool? isLoading,
    String? error,
    String? readingContext,
  }) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      characterId: characterId ?? this.characterId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      readingContext: readingContext ?? this.readingContext,
    );
  }

  bool get hasMessages => messages.isNotEmpty;
  bool get hasError => error != null;
}

/// Notifier for managing Oracle chat state.
class ChatNotifier extends StateNotifier<ChatState> {
  final TarotApiService _apiService;

  ChatNotifier(this._apiService, {required String characterId, String? readingContext})
      : super(ChatState.initial(characterId: characterId, readingContext: readingContext));

  /// Sends a message to the Oracle.
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message immediately
    final userMessage = ChatMessageModel.user(text: message.trim());
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      // Call API
      final response = await _apiService.sendChatMessage(
        chatId: state.chatId,
        message: message.trim(),
        characterId: state.characterId,
        readingContext: state.readingContext,
      );

      // Add Oracle response
      final oracleMessage = ChatMessageModel.oracle(
        text: response,
        characterId: state.characterId,
      );

      state = state.copyWith(
        messages: [...state.messages, oracleMessage],
        isLoading: false,
      );
    } on TarotApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Mesaj gönderilemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  /// Adds an initial greeting from the Oracle.
  void addOracleGreeting(String greeting) {
    final greetingMessage = ChatMessageModel.oracle(
      text: greeting,
      characterId: state.characterId,
    );
    state = state.copyWith(
      messages: [greetingMessage, ...state.messages],
    );
  }

  /// Clears the chat history.
  void clearChat() {
    state = ChatState.initial(
      characterId: state.characterId,
      readingContext: state.readingContext,
    );
  }

  /// Clears the error state.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Updates the reading context.
  void setReadingContext(String context) {
    state = state.copyWith(readingContext: context);
  }
}

/// Family provider for Oracle chat - allows multiple chat sessions.
final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, ChatParams>(
  (ref, params) {
    final apiService = ref.watch(tarotApiServiceProvider);
    return ChatNotifier(
      apiService,
      characterId: params.characterId,
      readingContext: params.readingContext,
    );
  },
);

/// Parameters for creating a chat session.
class ChatParams {
  final String characterId;
  final String? readingContext;

  const ChatParams({
    required this.characterId,
    this.readingContext,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParams &&
          other.characterId == characterId &&
          other.readingContext == readingContext;

  @override
  int get hashCode => characterId.hashCode ^ (readingContext?.hashCode ?? 0);
}

/// Provider for checking if chat is loading.
final isChatLoadingProvider = Provider.family<bool, ChatParams>((ref, params) {
  return ref.watch(chatProvider(params)).isLoading;
});

/// Provider for chat messages.
final chatMessagesProvider = Provider.family<List<ChatMessageModel>, ChatParams>((ref, params) {
  return ref.watch(chatProvider(params)).messages;
});

/// Provider for chat error.
final chatErrorProvider = Provider.family<String?, ChatParams>((ref, params) {
  return ref.watch(chatProvider(params)).error;
});
