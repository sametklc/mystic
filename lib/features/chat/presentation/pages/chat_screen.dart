import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../data/providers/chat_provider.dart';
import '../widgets/chat_bubbles.dart';
import '../widgets/oracle_typing_indicator.dart';

/// Oracle Chat Screen - intimate magical conversation.
class ChatScreen extends ConsumerStatefulWidget {
  final String characterId;
  final String? initialInterpretation;
  final String? cardName;

  const ChatScreen({
    super.key,
    required this.characterId,
    this.initialInterpretation,
    this.cardName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _glowController;
  late CharacterInfo _character;
  late ChatParams _chatParams;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    _character = CharacterInfo.fromId(widget.characterId);

    _chatParams = ChatParams(
      characterId: widget.characterId,
      readingContext: widget.initialInterpretation,
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Add initial messages after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  void _initializeChat() {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final notifier = ref.read(chatProvider(_chatParams).notifier);

    // Add the tarot interpretation as first Oracle message
    if (widget.initialInterpretation != null &&
        widget.initialInterpretation!.isNotEmpty) {
      notifier.addOracleGreeting(widget.initialInterpretation!);
    }

    // Add character's follow-up greeting
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        notifier.addOracleGreeting(_character.greeting);
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    ref.read(chatProvider(_chatParams).notifier).sendMessage(message);

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(_chatParams));

    // Auto-scroll when new messages arrive
    ref.listen<ChatState>(chatProvider(_chatParams), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return MysticBackgroundScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Messages
            Expanded(
              child: _buildMessageList(chatState),
            ),

            // Input
            _buildInputArea(chatState.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _character.themeColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),

          const SizedBox(width: 8),

          // Character Avatar
          _buildCharacterAvatar(),

          const SizedBox(width: 12),

          // Character Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _character.name,
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _character.title,
                  style: AppTypography.labelSmall.copyWith(
                    color: _character.themeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Card name badge
          if (widget.cardName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: Text(
                widget.cardName!,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildCharacterAvatar() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = _glowController.value;

        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _character.themeColor.withValues(alpha: 0.6 + glowIntensity * 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _character.themeColor.withValues(alpha: 0.2 + glowIntensity * 0.2),
                blurRadius: 12 + glowIntensity * 8,
                spreadRadius: 2,
              ),
            ],
            gradient: RadialGradient(
              colors: [
                _character.themeColor.withValues(alpha: 0.3),
                AppColors.backgroundSecondary,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome,
              color: _character.themeColor,
              size: 22,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList(ChatState state) {
    if (state.messages.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: _character.themeColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'The Oracle awaits...',
              style: GoogleFonts.cinzel(
                fontSize: 16,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: state.messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Show typing indicator at the end when loading
        if (state.isLoading && index == state.messages.length) {
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                OracleTypingIndicator(color: _character.themeColor),
                TypingParticles(color: _character.themeColor),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms);
        }

        final message = state.messages[index];
        final isFirstOracleMessage = index == 0 && !message.isUser;

        if (message.isUser) {
          return UserMessageBubble(message: message);
        } else {
          return OracleMessageBubble(
            message: message,
            themeColor: _character.themeColor,
            isInitialMessage: isFirstOracleMessage,
          );
        }
      },
    );
  }

  Widget _buildInputArea(bool isLoading) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = _glowController.value;

        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: _character.themeColor.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.background.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Row(
            children: [
              // Input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? _character.themeColor.withValues(alpha: 0.5 + glowIntensity * 0.3)
                          : AppColors.glassBorder,
                      width: 1,
                    ),
                    color: AppColors.glassFill,
                    boxShadow: _focusNode.hasFocus
                        ? [
                            BoxShadow(
                              color: _character.themeColor.withValues(alpha: 0.1 + glowIntensity * 0.1),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ask the Oracle...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !isLoading,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Send button (Rune symbol)
              _buildSendButton(isLoading, glowIntensity),
            ],
          ),
        );
      },
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSendButton(bool isLoading, double glowIntensity) {
    return GestureDetector(
      onTap: isLoading ? null : _sendMessage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isLoading
                ? AppColors.textTertiary.withValues(alpha: 0.3)
                : _character.themeColor.withValues(alpha: 0.6 + glowIntensity * 0.4),
            width: 2,
          ),
          gradient: isLoading
              ? null
              : RadialGradient(
                  colors: [
                    _character.themeColor.withValues(alpha: 0.2 + glowIntensity * 0.15),
                    Colors.transparent,
                  ],
                ),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: _character.themeColor.withValues(alpha: 0.2 + glowIntensity * 0.2),
                    blurRadius: 12 + glowIntensity * 8,
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _character.themeColor.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Icon(
                  Icons.north,
                  color: _character.themeColor,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
