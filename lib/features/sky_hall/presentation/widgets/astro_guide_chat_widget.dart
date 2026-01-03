import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../home/presentation/providers/character_provider.dart';
import '../../data/services/astrology_api_service.dart';

/// Astro Guide Chat widget for the Sky Hall Guide tab.
///
/// Uses a hybrid approach for reliability:
/// - Local state for immediate UI updates (optimistic)
/// - Firestore stream as backup when available
/// - Works even if backend Firebase is temporarily unavailable
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

  // Local messages for immediate display
  final List<_AstroChatMessage> _localMessages = [];

  bool _isLoading = false;
  bool _initialLoadDone = false;
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

  /// Initialize chat session and try to load from Firestore
  Future<void> _initSession() async {
    final deviceId = ref.read(deviceIdProvider);
    _sessionId = 'session_$deviceId';

    // Try to load existing messages from Firestore
    await _loadFromFirestore();

    setState(() => _initialLoadDone = true);
  }

  /// Try to load messages from Firestore
  Future<void> _loadFromFirestore() async {
    final deviceId = ref.read(deviceIdProvider);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(deviceId)
          .collection('astro_guide')
          .doc('metadata')
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _localMessages.clear();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            _localMessages.add(_AstroChatMessage(
              id: doc.id,
              text: data['content'] as String? ?? '',
              isUser: data['role'] == 'user',
              timestamp: _parseTimestamp(data['timestamp']),
            ));
          }
        });
        debugPrint('[AstroChat] Loaded ${snapshot.docs.length} messages from Firestore');
      }
    } catch (e) {
      debugPrint('[AstroChat] Could not load from Firestore: $e');
      // Continue without Firestore data
    }
  }

  /// Parse timestamp from Firestore
  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Start a new conversation (clear history)
  Future<void> _startNewConversation() async {
    final deviceId = ref.read(deviceIdProvider);

    setState(() {
      _localMessages.clear();
      _isLoading = true;
    });

    try {
      _sessionId = await _apiService.startNewChatSession(userId: deviceId);
    } catch (e) {
      debugPrint('[AstroChat] Failed to start new conversation: $e');
    }

    setState(() => _isLoading = false);
    HapticFeedback.mediumImpact();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;
    if (_sessionId == null) return;

    HapticFeedback.lightImpact();
    _messageController.clear();
    _focusNode.unfocus();

    // Add user message immediately (optimistic UI)
    final userMessage = _AstroChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _localMessages.add(userMessage);
      _isLoading = true;
    });

    // Scroll to show user message
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Get user data for API call
    final user = ref.read(userProvider);
    final deviceId = ref.read(deviceIdProvider);

    // Try to use backend API if user has birth data
    if (user.birthDate != null && user.birthLatitude != null) {
      try {
        final birthDate = user.birthDate!;
        final selectedCharacterId = ref.read(selectedCharacterIdProvider);

        // Call the Astro-Guide chat API
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

        // Get the AI response
        final responseText = result['response'] as String? ??
            'I sense cosmic interference. Please try again.';

        // Add AI response to local messages
        final aiMessage = _AstroChatMessage(
          text: responseText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _localMessages.add(aiMessage);
          _isLoading = false;
        });

        // Scroll to show AI response
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      } catch (e) {
        debugPrint('[AstroChat] API error: $e');

        // Remove the optimistic user message on error
        setState(() {
          _localMessages.removeLast();
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      // No birth data - remove optimistic message and show error
      setState(() {
        _localMessages.removeLast();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please complete your birth data first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);

    if (user.sunSign == null) {
      return _buildNoBirthDataState();
    }

    // Show loading while initial load
    if (!_initialLoadDone) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.mysticTeal),
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
      );
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

              // Messages or Welcome state
              _localMessages.isEmpty
                  ? _buildWelcomeState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppConstants.spacingMedium),
                      itemCount: _localMessages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isLoading && index == _localMessages.length) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_localMessages[index], index);
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

  Widget _buildWelcomeState() {
    final user = ref.read(userProvider);
    final sunSign = user.sunSign ?? 'cosmic traveler';
    final character = ref.read(selectedCharacterProvider);
    final welcomeText = _getCharacterWelcome(character.id, character.name, sunSign);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Character avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.mysticTeal.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.3),
                ],
              ),
              border: Border.all(
                color: AppColors.mysticTeal.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 36,
              color: AppColors.mysticTeal,
            ),
          ),

          const SizedBox(height: AppConstants.spacingMedium),

          Text(
            character.name,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.mysticTeal,
            ),
          ),

          const SizedBox(height: AppConstants.spacingLarge),

          // Welcome message bubble
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.mysticTeal.withOpacity(0.15),
                  AppColors.glassFill,
                ],
              ),
              border: Border.all(
                color: AppColors.mysticTeal.withOpacity(0.3),
              ),
            ),
            child: Text(
              welcomeText,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: AppConstants.spacingLarge),

          Text(
            'Ask me anything about your chart...',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
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
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0);
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
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isLoading
                      ? [
                          AppColors.textTertiary,
                          AppColors.textTertiary,
                        ]
                      : [
                          AppColors.mysticTeal,
                          AppColors.primary,
                        ],
                ),
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.mysticTeal.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
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

/// Message model for astro chat
class _AstroChatMessage {
  final String? id;
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
