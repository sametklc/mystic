import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/services/device_id_service.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../sky_hall/data/providers/sky_hall_provider.dart';
import '../../../sky_hall/domain/models/synastry_model.dart';
import '../../../tarot/data/services/tarot_api_service.dart';
import '../../../tarot/data/providers/tarot_provider.dart';
import '../../../tarot/data/tarot_deck_assets.dart';
import '../models/ai_persona.dart';

/// iOS Chat Screen - Persona-specific chat interface.
///
/// For Mystic (Tarot): Includes "Draw Cards" action that calls
/// the existing Tarot Service and displays results as chat bubbles.
class IOSChatScreen extends ConsumerStatefulWidget {
  final AIPersona persona;

  const IOSChatScreen({
    super.key,
    required this.persona,
  });

  @override
  ConsumerState<IOSChatScreen> createState() => _IOSChatScreenState();
}

class _IOSChatScreenState extends ConsumerState<IOSChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isDrawingCards = false;
  bool _isFetchingHoroscope = false;

  // Rose (Love Match) - partner data collection state
  bool _awaitingPartnerName = false;
  bool _awaitingPartnerBirthDate = false;
  String? _partnerName;
  String? _partnerBirthDate;

  // Major Arcana cards for random selection
  static const List<String> _majorArcana = [
    'The Fool', 'The Magician', 'The High Priestess', 'The Empress',
    'The Emperor', 'The Hierophant', 'The Lovers', 'The Chariot',
    'Strength', 'The Hermit', 'Wheel of Fortune', 'Justice',
    'The Hanged Man', 'Death', 'Temperance', 'The Devil',
    'The Tower', 'The Star', 'The Moon', 'The Sun',
    'Judgement', 'The World',
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    // Add persona-specific welcome message
    switch (widget.persona.feature) {
      case PersonaFeature.tarot:
        // Mystic - Tarot specific welcome
        _messages.add(ChatMessage.text(
          text: "I sense you are seeking guidance. Focus on your question, then let the cards reveal their wisdom.",
          isUser: false,
        ));

        // Add action message with Draw Cards button
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage.action(
                text: "When you're ready, tap below to draw your cards.",
                isUser: false,
                actions: [
                  ChatAction(
                    label: "Draw Cards ✨",
                    onTap: _onDrawCards,
                  ),
                ],
              ));
            });
            _scrollToBottom();
          }
        });
        break;

      case PersonaFeature.horoscope:
        // Nova - Astrology specific welcome
        _messages.add(ChatMessage.text(
          text: "Hey there! I'm Nova, your cosmic guide. I read the stars to help you navigate life's journey. The celestial bodies are always speaking - let me translate for you.",
          isUser: false,
        ));

        // Add action message with Daily Forecast button
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage.action(
                text: "Ready to see what the cosmos have in store for you today?",
                isUser: false,
                actions: [
                  ChatAction(
                    label: "Daily Forecast 🌟",
                    onTap: _onDailyForecast,
                  ),
                ],
              ));
            });
            _scrollToBottom();
          }
        });
        break;

      case PersonaFeature.loveMatch:
        // Rose - Love Match specific welcome
        _messages.add(ChatMessage.text(
          text: "Hi there! I'm Rose, your relationship guide. I specialize in the cosmic chemistry between souls. Love is written in the stars - let me help you read it.",
          isUser: false,
        ));

        // Ask for partner's name
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _awaitingPartnerName = true;
              _messages.add(ChatMessage.action(
                text: "Who is the special person you'd like to explore your connection with? Share their name with me.",
                isUser: false,
                actions: [
                  ChatAction(
                    label: "Check My Compatibility 💕",
                    onTap: _onStartLoveMatch,
                  ),
                ],
              ));
            });
            _scrollToBottom();
          }
        });
        break;

      case PersonaFeature.dailyWisdom:
        // Astra - Daily Wisdom specific welcome
        _messages.add(ChatMessage.text(
          text: widget.persona.welcomeMessage,
          isUser: false,
        ));

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage.action(
                text: "What kind of guidance would brighten your day?",
                isUser: false,
                actions: [
                  ChatAction(
                    label: "Daily Inspiration ☀️",
                    onTap: () => _focusNode.requestFocus(),
                  ),
                ],
              ));
            });
            _scrollToBottom();
          }
        });
        break;

      case PersonaFeature.general:
        // Default welcome
        _messages.add(ChatMessage.text(
          text: widget.persona.welcomeMessage,
          isUser: false,
        ));
        break;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle "Draw Cards" action for Mystic/Tarot
  Future<void> _onDrawCards() async {
    if (_isDrawingCards) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isDrawingCards = true;
      // Add user action message
      _messages.add(ChatMessage.text(
        text: "Draw my cards",
        isUser: true,
      ));
      // Show typing indicator
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Get device ID for API call
      final deviceId = ref.read(deviceIdProvider);

      // Draw random cards (3-card spread)
      final random = Random();
      final drawnCards = <DrawnCard>[];

      // Select 3 random unique cards
      final shuffled = List<String>.from(_majorArcana)..shuffle(random);
      for (int i = 0; i < 3; i++) {
        final cardName = shuffled[i];
        final isUpright = random.nextDouble() > 0.3; // 70% upright
        drawnCards.add(DrawnCard(
          name: cardName,
          isUpright: isUpright,
          position: _getPositionName(i),
        ));
      }

      // Call the Tarot API service for interpretation
      final tarotService = ref.read(tarotApiServiceProvider);
      final reading = await tarotService.generateReading(
        userId: deviceId,
        question: "General guidance reading",
        spreadType: SpreadType.threeCard,
        visionaryMode: false, // Don't generate AI images for speed
        cardName: drawnCards.first.name,
        isUpright: drawnCards.first.isUpright,
        characterId: widget.persona.characterId,
      );

      setState(() {
        _isTyping = false;

        // Add the card reading as a special message
        _messages.add(ChatMessage.cardReading(
          cards: drawnCards,
          interpretation: reading.interpretation,
          isUser: false,
        ));

        // Add follow-up message with action
        _messages.add(ChatMessage.action(
          text: "The cards have spoken. Would you like another reading, or do you have questions about this one?",
          isUser: false,
          actions: [
            ChatAction(
              label: "Draw Again 🔮",
              onTap: _onDrawCards,
            ),
            ChatAction(
              label: "Ask a Question",
              onTap: () {
                _focusNode.requestFocus();
              },
            ),
          ],
        ));

        _isDrawingCards = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
        _isDrawingCards = false;
        _messages.add(ChatMessage.text(
          text: "The cosmic energies are turbulent right now. Let's try again in a moment.",
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  String _getPositionName(int index) {
    switch (index) {
      case 0:
        return "Past";
      case 1:
        return "Present";
      case 2:
        return "Future";
      default:
        return "Card ${index + 1}";
    }
  }

  /// Handle "Daily Forecast" action for Nova/Horoscope
  Future<void> _onDailyForecast() async {
    if (_isFetchingHoroscope) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isFetchingHoroscope = true;
      _messages.add(ChatMessage.text(
        text: "Show me my daily forecast",
        isUser: true,
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final profile = ref.read(currentProfileProvider);
      final deviceId = ref.read(deviceIdProvider);
      final astrologyService = ref.read(astrologyApiServiceProvider);

      // Check if user has birth data
      if (profile?.birthDate == null || profile?.birthLatitude == null) {
        setState(() {
          _isTyping = false;
          _isFetchingHoroscope = false;
          _messages.add(ChatMessage.text(
            text: "I need your birth details to read your personal cosmic forecast. Without knowing when and where you were born, I can only offer general insights. Would you like me to give you a general reading, or would you prefer to update your profile first?",
            isUser: false,
          ));
        });
        _scrollToBottom();
        return;
      }

      // Fetch personal horoscope
      final horoscope = await astrologyService.getPersonalHoroscope(
        userId: deviceId,
        birthDate: profile!.birthDate!,
        birthTime: profile.birthTime ?? '12:00',
        birthLatitude: profile.birthLatitude!,
        birthLongitude: profile.birthLongitude!,
        birthTimezone: profile.birthTimezone ?? 'UTC',
        name: profile.name,
      );

      setState(() {
        _isTyping = false;

        // Add horoscope message
        _messages.add(ChatMessage.horoscope(
          forecast: horoscope['forecast'] ?? 'The stars are speaking...',
          cosmicVibe: horoscope['cosmic_vibe'],
          focusAreas: (horoscope['focus_areas'] as List<dynamic>?)?.cast<String>(),
          isUser: false,
        ));

        // Add follow-up action
        _messages.add(ChatMessage.action(
          text: "That's your cosmic snapshot for today! Want to dive deeper into any aspect, or have questions about the planetary influences?",
          isUser: false,
          actions: [
            ChatAction(
              label: "Refresh Forecast 🔄",
              onTap: _onDailyForecast,
            ),
            ChatAction(
              label: "Ask Nova",
              onTap: () => _focusNode.requestFocus(),
            ),
          ],
        ));

        _isFetchingHoroscope = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
        _isFetchingHoroscope = false;
        _messages.add(ChatMessage.text(
          text: "The cosmic signals are a bit fuzzy right now. Let me try again in a moment. In the meantime, tell me what's on your mind - I can still offer guidance.",
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  /// Start love match flow for Rose
  void _onStartLoveMatch() {
    HapticFeedback.lightImpact();
    setState(() {
      _awaitingPartnerName = true;
    });
    _focusNode.requestFocus();
  }

  /// Handle partner name input for Rose
  void _handlePartnerNameInput(String name) {
    setState(() {
      _partnerName = name.trim();
      _awaitingPartnerName = false;
      _awaitingPartnerBirthDate = true;

      _messages.add(ChatMessage.text(
        text: "$_partnerName... that's a lovely name. To read the cosmic connection between you two, I need to know their birth date. When was $_partnerName born? (Format: YYYY-MM-DD, like 1995-06-15)",
        isUser: false,
      ));
    });
    _scrollToBottom();
  }

  /// Handle partner birth date input for Rose
  Future<void> _handlePartnerBirthDateInput(String dateInput) async {
    // Parse the date
    final dateRegex = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})');
    final match = dateRegex.firstMatch(dateInput);

    if (match == null) {
      setState(() {
        _messages.add(ChatMessage.text(
          text: "I couldn't quite catch that date format. Please share $_partnerName's birth date like this: 1995-06-15 (year-month-day).",
          isUser: false,
        ));
      });
      _scrollToBottom();
      return;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    _partnerBirthDate = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    setState(() {
      _awaitingPartnerBirthDate = false;
      _isTyping = true;
      _messages.add(ChatMessage.text(
        text: "Perfect! Let me consult the stars about your connection with $_partnerName...",
        isUser: false,
      ));
    });
    _scrollToBottom();

    // Calculate synastry
    await _calculateLoveMatch();
  }

  /// Calculate love compatibility for Rose
  Future<void> _calculateLoveMatch() async {
    try {
      final profile = ref.read(currentProfileProvider);
      final astrologyService = ref.read(astrologyApiServiceProvider);

      // Check if user has birth data
      if (profile?.birthDate == null || profile?.birthLatitude == null) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage.text(
            text: "I need your birth details to calculate cosmic compatibility. The stars can only speak when I know both of your celestial signatures. Would you like to update your profile with your birth information?",
            isUser: false,
          ));
        });
        _scrollToBottom();
        return;
      }

      // Prepare user data
      final user1Data = {
        'name': profile!.name ?? 'You',
        'date': profile.birthDate!,
        'time': profile.birthTime ?? '12:00',
        'latitude': profile.birthLatitude!,
        'longitude': profile.birthLongitude!,
        'timezone': profile.birthTimezone ?? 'UTC',
      };

      // Partner data (using default location since we only have birth date)
      final user2Data = {
        'name': _partnerName ?? 'Partner',
        'date': _partnerBirthDate!,
        'time': '12:00',
        'latitude': 40.7128, // Default to NYC
        'longitude': -74.0060,
        'timezone': 'America/New_York',
      };

      final report = await astrologyService.calculateSynastry(
        user1Data: user1Data,
        user2Data: user2Data,
        characterId: widget.persona.characterId,
      );

      setState(() {
        _isTyping = false;

        // Add compatibility result as conversational message
        _messages.add(ChatMessage.compatibility(
          report: report,
          partnerName: _partnerName ?? 'Partner',
          isUser: false,
        ));

        // Add follow-up
        _messages.add(ChatMessage.action(
          text: "That's the cosmic story of your connection. Remember, the stars show potential, but love is what you make of it. Want to explore another connection?",
          isUser: false,
          actions: [
            ChatAction(
              label: "New Match 💫",
              onTap: _onResetLoveMatch,
            ),
            ChatAction(
              label: "Ask Rose",
              onTap: () => _focusNode.requestFocus(),
            ),
          ],
        ));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage.text(
          text: "The cosmic connection was a bit disrupted. Let me try again. Sometimes the universe needs a moment to align. Share $_partnerName's birth date again?",
          isUser: false,
        ));
        _awaitingPartnerBirthDate = true;
      });
      _scrollToBottom();
    }
  }

  /// Reset love match flow for new calculation
  void _onResetLoveMatch() {
    HapticFeedback.lightImpact();
    setState(() {
      _partnerName = null;
      _partnerBirthDate = null;
      _awaitingPartnerName = true;
      _awaitingPartnerBirthDate = false;
      _messages.add(ChatMessage.text(
        text: "Who else would you like to explore a cosmic connection with? Share their name with me.",
        isUser: false,
      ));
    });
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(ChatMessage.text(
        text: text,
        isUser: true,
      ));
      _messageController.clear();
    });

    _scrollToBottom();

    // Handle Rose's conversational flow for love match
    if (widget.persona.feature == PersonaFeature.loveMatch) {
      if (_awaitingPartnerName) {
        _handlePartnerNameInput(text);
        return;
      }
      if (_awaitingPartnerBirthDate) {
        _handlePartnerBirthDateInput(text);
        return;
      }
    }

    setState(() {
      _isTyping = true;
    });

    // Call chat API for response
    _generateChatResponse(text);
  }

  Future<void> _generateChatResponse(String userMessage) async {
    try {
      final tarotService = ref.read(tarotApiServiceProvider);
      final deviceId = ref.read(deviceIdProvider);

      // Build conversation history
      final history = _messages
          .where((m) => m.type == ChatMessageType.text)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text ?? '',
              })
          .toList();

      final response = await tarotService.sendChatMessage(
        chatId: deviceId,
        message: userMessage,
        characterId: widget.persona.characterId,
        conversationHistory: history.take(10).toList(),
      );

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage.text(
            text: response,
            isUser: false,
          ));

          // If Mystic, occasionally offer to draw cards
          if (widget.persona.feature == PersonaFeature.tarot &&
              _messages.length % 4 == 0) {
            _messages.add(ChatMessage.action(
              text: "Would you like me to draw cards for deeper insight?",
              isUser: false,
              actions: [
                ChatAction(
                  label: "Draw Cards ✨",
                  onTap: _onDrawCards,
                ),
              ],
            ));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage.text(
            text: _getFallbackResponse(),
            isUser: false,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  String _getFallbackResponse() {
    switch (widget.persona.feature) {
      case PersonaFeature.tarot:
        return "The energies are shifting... Tell me more about what's on your mind, and perhaps the cards will guide us.";
      case PersonaFeature.horoscope:
        return "The stars are aligning in interesting ways. What aspect of your journey would you like to explore?";
      case PersonaFeature.loveMatch:
        return "Matters of the heart require patience. Share more with me, and we'll find clarity together.";
      case PersonaFeature.dailyWisdom:
        return "Every moment holds wisdom. What's weighing on your spirit today?";
      case PersonaFeature.general:
        return "I'm here to guide you. Please, continue sharing your thoughts.";
    }
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: GestureDetector(
              onTap: () => _focusNode.unfocus(),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
            ),
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.persona.gradient,
            ),
            child: Center(
              child: Icon(
                widget.persona.icon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.persona.name,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4CD964),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    switch (message.type) {
      case ChatMessageType.text:
        return _buildTextBubble(message);
      case ChatMessageType.action:
        return _buildActionBubble(message);
      case ChatMessageType.cardReading:
        return _buildCardReadingBubble(message);
      case ChatMessageType.horoscope:
        return _buildHoroscopeBubble(message);
      case ChatMessageType.compatibility:
        return _buildCompatibilityBubble(message);
    }
  }

  Widget _buildTextBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? widget.persona.themeColor : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser ? null : Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                message.text ?? '',
                style: AppTypography.bodyMedium.copyWith(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text part
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    message.text ?? '',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (message.actions ?? []).map((action) {
                    return GestureDetector(
                      onTap: action.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: widget.persona.gradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: widget.persona.themeColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          action.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardReadingBubble(ChatMessage message) {
    final cards = message.cards ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: widget.persona.themeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card thumbnails
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.persona.themeColor.withValues(alpha: 0.15),
                          widget.persona.themeColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: cards.map((card) => _buildCardThumbnail(card)).toList(),
                    ),
                  ),
                  // Interpretation text
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      message.interpretation ?? 'The cards reveal their wisdom...',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardThumbnail(DrawnCard card) {
    final assetPath = TarotDeckAssets.getMajorArcanaByName(card.name);

    return Column(
      children: [
        // Position label
        Text(
          card.position,
          style: AppTypography.labelSmall.copyWith(
            color: widget.persona.themeColor,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        // Card image
        Transform.rotate(
          angle: card.isUpright ? 0 : pi, // Flip if reversed
          child: Container(
            width: 60,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: widget.persona.themeColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surface,
                    child: Center(
                      child: Icon(
                        Icons.auto_awesome,
                        color: widget.persona.themeColor,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Card name
        SizedBox(
          width: 70,
          child: Text(
            card.name,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Orientation
        Text(
          card.isUpright ? 'Upright' : 'Reversed',
          style: AppTypography.labelSmall.copyWith(
            color: card.isUpright
                ? const Color(0xFF4CD964)
                : const Color(0xFFFF6B6B),
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build horoscope forecast bubble for Nova
  Widget _buildHoroscopeBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: widget.persona.themeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with cosmic vibe
                  if (message.cosmicVibe != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.persona.themeColor.withValues(alpha: 0.2),
                            widget.persona.themeColor.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: widget.persona.themeColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message.cosmicVibe!,
                              style: AppTypography.labelMedium.copyWith(
                                color: widget.persona.themeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Forecast text
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      message.forecast ?? 'The stars are speaking...',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  // Focus areas
                  if (message.focusAreas != null && message.focusAreas!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Focus Areas:',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: message.focusAreas!.map((area) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.persona.themeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.persona.themeColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  area,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: widget.persona.themeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build compatibility result bubble for Rose
  Widget _buildCompatibilityBubble(ChatMessage message) {
    final report = message.compatibilityReport;
    if (report == null) return const SizedBox.shrink();

    final partnerName = message.partnerName ?? 'Your partner';
    final score = report.compatibilityScore;
    final level = report.compatibilityLevel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: widget.persona.themeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with score
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.persona.themeColor.withValues(alpha: 0.2),
                          widget.persona.themeColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite,
                              color: widget.persona.themeColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              level,
                              style: AppTypography.titleMedium.copyWith(
                                color: widget.persona.themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Score display (conversational, not a gauge)
                        Text(
                          'Your cosmic compatibility with $partnerName is $score%',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // AI Summary (conversational analysis)
                  if (report.aiSummary != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        report.aiSummary!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    )
                  else if (report.detailedAnalysis != null) ...[
                    // Chemistry Analysis
                    if (report.detailedAnalysis!.chemistryAnalysis.isNotEmpty)
                      _buildCompatibilitySection(
                        icon: Icons.local_fire_department,
                        title: 'Chemistry',
                        content: report.detailedAnalysis!.chemistryAnalysis,
                      ),
                    // Emotional Connection
                    if (report.detailedAnalysis!.emotionalConnection.isNotEmpty)
                      _buildCompatibilitySection(
                        icon: Icons.favorite_border,
                        title: 'Emotional Bond',
                        content: report.detailedAnalysis!.emotionalConnection,
                      ),
                    // Challenges
                    if (report.detailedAnalysis!.challenges.isNotEmpty)
                      _buildCompatibilitySection(
                        icon: Icons.warning_amber_rounded,
                        title: 'Growth Areas',
                        content: report.detailedAnalysis!.challenges,
                      ),
                  ] else
                    // Fallback summary
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _generateCompatibilitySummary(report, partnerName),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: widget.persona.themeColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  color: widget.persona.themeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _generateCompatibilitySummary(SynastryReport report, String partnerName) {
    final score = report.compatibilityScore;
    final emotional = report.emotionalCompatibility;
    final intellectual = report.intellectualCompatibility;

    if (score >= 80) {
      return "I've analyzed the celestial patterns between you and $partnerName, and the stars reveal a profound connection. Your souls resonate on a deep level - this is a rare and beautiful alignment. The emotional bond ($emotional%) and intellectual harmony ($intellectual%) create a powerful foundation.";
    } else if (score >= 60) {
      return "The cosmic energies between you and $partnerName show a strong and promising connection. There's genuine potential here - your emotional resonance ($emotional%) and mental compatibility ($intellectual%) suggest you understand each other on multiple levels.";
    } else if (score >= 40) {
      return "Your connection with $partnerName is one of growth and learning. While there may be challenges to navigate, these are opportunities for both of you to evolve. Your emotional bond ($emotional%) and intellectual connection ($intellectual%) offer a foundation to build upon.";
    } else {
      return "The stars show that your connection with $partnerName requires conscious effort and understanding. Different cosmic rhythms don't mean impossibility - they mean you'll need to communicate more and appreciate your unique perspectives. Your emotional score ($emotional%) and intellectual alignment ($intellectual%) suggest areas to focus on.";
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TypingDot(delay: 0, color: widget.persona.themeColor),
                const SizedBox(width: 4),
                _TypingDot(delay: 150, color: widget.persona.themeColor),
                const SizedBox(width: 4),
                _TypingDot(delay: 300, color: widget.persona.themeColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.persona.gradient,
      ),
      child: Center(
        child: Icon(
          widget.persona.icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Message ${widget.persona.name}...',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.persona.gradient,
                boxShadow: [
                  BoxShadow(
                    color: widget.persona.themeColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Chat Message Models
// =============================================================================

enum ChatMessageType { text, action, cardReading, horoscope, compatibility }

class ChatMessage {
  final ChatMessageType type;
  final String? text;
  final bool isUser;
  final DateTime timestamp;
  final List<ChatAction>? actions;
  final List<DrawnCard>? cards;
  final String? interpretation;
  // Horoscope fields
  final String? forecast;
  final String? cosmicVibe;
  final List<String>? focusAreas;
  // Compatibility fields
  final SynastryReport? compatibilityReport;
  final String? partnerName;

  ChatMessage({
    required this.type,
    this.text,
    required this.isUser,
    DateTime? timestamp,
    this.actions,
    this.cards,
    this.interpretation,
    this.forecast,
    this.cosmicVibe,
    this.focusAreas,
    this.compatibilityReport,
    this.partnerName,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.text({
    required String text,
    required bool isUser,
  }) {
    return ChatMessage(
      type: ChatMessageType.text,
      text: text,
      isUser: isUser,
    );
  }

  factory ChatMessage.action({
    required String text,
    required bool isUser,
    required List<ChatAction> actions,
  }) {
    return ChatMessage(
      type: ChatMessageType.action,
      text: text,
      isUser: isUser,
      actions: actions,
    );
  }

  factory ChatMessage.cardReading({
    required List<DrawnCard> cards,
    required String interpretation,
    required bool isUser,
  }) {
    return ChatMessage(
      type: ChatMessageType.cardReading,
      isUser: isUser,
      cards: cards,
      interpretation: interpretation,
    );
  }

  factory ChatMessage.horoscope({
    required String forecast,
    String? cosmicVibe,
    List<String>? focusAreas,
    required bool isUser,
  }) {
    return ChatMessage(
      type: ChatMessageType.horoscope,
      isUser: isUser,
      forecast: forecast,
      cosmicVibe: cosmicVibe,
      focusAreas: focusAreas,
    );
  }

  factory ChatMessage.compatibility({
    required SynastryReport report,
    required String partnerName,
    required bool isUser,
  }) {
    return ChatMessage(
      type: ChatMessageType.compatibility,
      isUser: isUser,
      compatibilityReport: report,
      partnerName: partnerName,
    );
  }
}

class ChatAction {
  final String label;
  final VoidCallback onTap;

  ChatAction({
    required this.label,
    required this.onTap,
  });
}

class DrawnCard {
  final String name;
  final bool isUpright;
  final String position;

  DrawnCard({
    required this.name,
    required this.isUpright,
    required this.position,
  });
}

// =============================================================================
// Typing Indicator Animation
// =============================================================================

class _TypingDot extends StatefulWidget {
  final int delay;
  final Color color;

  const _TypingDot({
    required this.delay,
    required this.color,
  });

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.5 + 0.5 * _animation.value),
            ),
          ),
        );
      },
    );
  }
}
