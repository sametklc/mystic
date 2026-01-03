import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../home/presentation/providers/character_provider.dart';
import '../../data/services/astrology_api_service.dart';

/// Astro Guide Chat widget for the Sky Hall Guide tab.
/// Allows users to chat with an AI that interprets their natal chart.
///
/// Uses Firestore persistence with "infinite memory" via backend summarization:
/// - Full message history stored in Firestore
/// - Nova remembers context via rolling summaries (token-efficient)
/// - Real-time sync via Firestore streams
/// - Persists across app restarts
///
/// Firestore Schema:
///   users/{user_id}/astro_guide/metadata - Summary and chart context
///   users/{user_id}/astro_guide/metadata/messages - Message history
class AstroGuideChatWidget extends ConsumerStatefulWidget {
  const AstroGuideChatWidget({super.key});

  @override
  ConsumerState<AstroGuideChatWidget> createState() =>
      _AstroGuideChatWidgetState();
}

class _AstroGuideChatWidgetState extends ConsumerState<AstroGuideChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<_AstroChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingHistory = true;
  String? _sessionId;

  final AstrologyApiService _apiService = AstrologyApiService();

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize chat session and load history
  Future<void> _initSession() async {
    final deviceId = ref.read(deviceIdProvider);
    _sessionId = 'session_$deviceId';

    // Load existing chat history from backend
    await _loadChatHistory();

    // Add welcome message only if no history exists
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }

    setState(() => _isLoadingHistory = false);

    // Scroll to bottom after history loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// Load chat history from Firestore via API
  Future<void> _loadChatHistory() async {
    final deviceId = ref.read(deviceIdProvider);

    try {
      final history = await _apiService.getChatHistory(userId: deviceId);
      final messages = history['messages'] as List<dynamic>? ?? [];

      if (messages.isNotEmpty) {
        setState(() {
          _messages.clear();
          for (final msg in messages) {
            _messages.add(_AstroChatMessage(
              id: msg['id'] as String?,
              text: msg['content'] as String? ?? '',
              isUser: msg['role'] == 'user',
              timestamp: _parseTimestamp(msg['timestamp']),
            ));
          }
        });
        debugPrint('[AstroChat] Loaded ${messages.length} messages from history');
      }
    } catch (e) {
      debugPrint('[AstroChat] Failed to load history: $e');
      // Continue without history - will show welcome message
    }
  }

  /// Parse timestamp from various formats
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  void _addWelcomeMessage() {
    final user = ref.read(userProvider);
    final sunSign = user.sunSign ?? 'cosmic traveler';
    final character = ref.read(selectedCharacterProvider);

    // Generate welcome message based on selected character
    final welcomeText = _getCharacterWelcome(character.id, character.name, sunSign);

    _messages.add(_AstroChatMessage(
      text: welcomeText,
      isUser: false,
      timestamp: DateTime.now(),
    ));

    if (mounted) setState(() {});
  }

  /// Get character-specific welcome message
  String _getCharacterWelcome(String characterId, String characterName, String sunSign) {
    switch (characterId) {
      case 'madame_luna':
        return 'Hello, dear $sunSign. I am $characterName, and I feel your cosmic energy flowing. '
            'Let me guide you through matters of the heart and soul. '
            'What weighs on your spirit today?';
      case 'elder_weiss':
        return 'Greetings, young $sunSign. I am $characterName, keeper of ancient wisdom. '
            'I have witnessed countless stars rise and fall. '
            'What guidance do you seek on your life path?';
      case 'nova':
        return 'Scanning cosmic signature... $sunSign detected. I am $characterName, your celestial analyst. '
            'I have processed your birth chart data and identified key patterns. '
            'What aspect of your cosmic blueprint shall we explore?';
      case 'shadow':
        return 'So, a $sunSign seeks the truth. I am $characterName, and I do not sugarcoat. '
            'I will show you what the stars reveal, whether you like it or not. '
            'Ask your question, if you dare.';
      default:
        return 'Greetings, $sunSign. I am $characterName, your celestial guide. '
            'I have studied your birth chart and can help you understand '
            'its cosmic patterns. What would you like to know?';
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Start a new conversation (clear history and get new session)
  Future<void> _startNewConversation() async {
    final deviceId = ref.read(deviceIdProvider);

    setState(() {
      _messages.clear();
      _isLoading = true;
    });

    // Clear history and get new session from backend
    // This clears all Firestore messages and resets the summary
    _sessionId = await _apiService.startNewChatSession(userId: deviceId);

    // Add welcome message
    _addWelcomeMessage();

    setState(() => _isLoading = false);

    HapticFeedback.mediumImpact();
  }

  /// Refresh chat history from server
  Future<void> _refreshHistory() async {
    setState(() => _isLoadingHistory = true);
    await _loadChatHistory();
    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }
    setState(() => _isLoadingHistory = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;
    if (_sessionId == null) return;

    HapticFeedback.lightImpact();
    _messageController.clear();
    _focusNode.unfocus();

    // Add user message
    setState(() {
      _messages.add(_AstroChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Get user data for API call
    final user = ref.read(userProvider);
    final deviceId = ref.read(deviceIdProvider);

    String response;

    // Try to use backend API if user has birth data
    if (user.birthDate != null && user.birthLatitude != null) {
      try {
        // Birth date is already in YYYY-MM-DD format
        final birthDate = user.birthDate!;

        // Get selected guide character
        final selectedCharacterId = ref.read(selectedCharacterIdProvider);

        // Call the Astro-Guide chat API with session-based memory
        // No need to send conversation history - backend maintains summary
        final result = await _apiService.sendAstroGuideChat(
          userId: deviceId,
          sessionId: _sessionId!,
          message: message,
          birthDate: birthDate,
          birthTime: user.birthTime ?? '12:00',
          birthLatitude: user.birthLatitude!,
          birthLongitude: user.birthLongitude ?? 0.0,
          birthTimezone: user.birthTimezone ?? 'UTC',
          name: user.name,
          characterId: selectedCharacterId,
        );

        response = result['response'] as String? ??
            _generateFallbackResponse(message, user.sunSign, user.risingSign);

        // Update session_id if returned (for continuity)
        if (result['session_id'] != null) {
          _sessionId = result['session_id'] as String;
        }
      } catch (e) {
        debugPrint('Astro chat API error: $e');
        response = _generateFallbackResponse(message, user.sunSign, user.risingSign);
      }
    } else {
      // No birth data - use fallback responses
      response = _generateFallbackResponse(message, user.sunSign, user.risingSign);
    }

    setState(() {
      _messages.add(_AstroChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _generateFallbackResponse(String question, String? sunSign, String? risingSign) {
    final sun = sunSign ?? 'your sign';
    final rising = risingSign ?? 'your rising';

    // Simple keyword-based responses
    final lowerQuestion = question.toLowerCase();

    if (lowerQuestion.contains('sun') || lowerQuestion.contains('identity')) {
      return 'Your Sun in $sun reveals your core essence and life purpose. '
          'This placement illuminates how you express your authentic self and where '
          'you find vitality. The Sun\'s aspects in your chart show how easily '
          'this expression flows in your life.';
    }

    if (lowerQuestion.contains('rising') || lowerQuestion.contains('ascendant')) {
      return 'With $rising rising, you project an aura of its qualities to the world. '
          'This is your cosmic mask - the first impression you make. '
          'Understanding your Ascendant helps you navigate social situations '
          'and recognize how others perceive you.';
    }

    if (lowerQuestion.contains('love') || lowerQuestion.contains('relationship')) {
      return 'For matters of the heart, I look to Venus in your chart. '
          'As a $sun, you approach love with characteristic traits of your sign. '
          'Your 7th house of partnerships and its ruler reveal deeper patterns '
          'in how you form lasting bonds.';
    }

    if (lowerQuestion.contains('career') || lowerQuestion.contains('work')) {
      return 'Your 10th house and its planetary ruler speak to your career path. '
          'As a $sun, you bring unique qualities to your professional life. '
          'Saturn\'s placement shows where you face challenges that ultimately '
          'forge your greatest achievements.';
    }

    if (lowerQuestion.contains('moon') || lowerQuestion.contains('emotion')) {
      return 'Your Moon placement reveals your emotional landscape and innermost needs. '
          'This is how you nurture yourself and others, and what makes you feel secure. '
          'The Moon\'s aspects show how your emotions flow with other areas of life.';
    }

    // Default response
    return 'Looking at your chart as a $sun with $rising rising, '
        'I see fascinating cosmic patterns at play. Your planetary placements '
        'form a unique celestial blueprint. Would you like me to explore '
        'a specific area - perhaps your love nature, career potential, '
        'or spiritual path?';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    if (user.sunSign == null) {
      return _buildNoBirthDataState();
    }

    return Column(
      children: [
        // Chat Messages
        Expanded(
          child: Stack(
            children: [
              // Star background decoration
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarBackgroundPainter(),
                ),
              ),

              // Loading history state
              if (_isLoadingHistory)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.mysticTeal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading cosmic memory...',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Messages list
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppConstants.spacingMedium),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoading && index == _messages.length) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index], index);
                  },
                ),
            ],
          ),
        ),

        // Input Area
        _buildInputArea(),
      ],
    );
  }

  Widget _buildMessageBubble(_AstroChatMessage message, int index) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppConstants.spacingSmall,
        left: message.isUser ? 48 : 0,
        right: message.isUser ? 0 : 48,
      ),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMedium,
                vertical: AppConstants.spacingSmall + 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: message.isUser
                      ? [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.secondary.withOpacity(0.2),
                        ]
                      : [
                          AppColors.mysticTeal.withOpacity(0.2),
                          AppColors.glassFill,
                        ],
                ),
                border: Border.all(
                  color: message.isUser
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.mysticTeal.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!message.isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final character = ref.watch(selectedCharacterProvider);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppColors.mysticTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                character.name,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.mysticTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  Text(
                    message.text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 48, bottom: AppConstants.spacingSmall),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMedium,
            vertical: AppConstants.spacingSmall,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.mysticTeal.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0),
              const SizedBox(width: 4),
              _buildDot(1),
              const SizedBox(width: 4),
              _buildDot(2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mysticTeal,
      ),
    )
        .animate(
          onComplete: (controller) => controller.repeat(),
        )
        .fadeIn(delay: Duration(milliseconds: index * 150))
        .then()
        .fadeOut(delay: const Duration(milliseconds: 300));
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spacingMedium,
        AppConstants.spacingSmall,
        AppConstants.spacingMedium,
        MediaQuery.of(context).padding.bottom + AppConstants.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text Input Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask ${ref.watch(selectedCharacterProvider).name} about your chart...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Send Button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.mysticTeal,
                    AppColors.primary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mysticTeal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBirthDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Text(
              'Chart Data Required',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSmall),
            Text(
              'Complete your birth details so I can read your celestial map.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Message model for astro chat with Firestore persistence
class _AstroChatMessage {
  final String? id; // Firestore document ID
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _AstroChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Custom painter for subtle star background
class _StarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mysticTeal.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Draw subtle star pattern
    for (int i = 0; i < 30; i++) {
      final x = (i * 47) % size.width;
      final y = (i * 73) % size.height;
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
