import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/models/chat_message_model.dart';

/// User message bubble - glass style, aligned right.
class UserMessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const UserMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 48, right: 16, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: const Radius.circular(4),
          ),
          color: AppColors.glassFill,
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0, duration: 300.ms);
  }
}

/// Oracle message bubble - floating mystical style, aligned left.
class OracleMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final Color themeColor;
  final bool isInitialMessage;

  const OracleMessageBubble({
    super.key,
    required this.message,
    this.themeColor = AppColors.secondary,
    this.isInitialMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.only(left: 16, right: 32, top: 12, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mystical floating text container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24).copyWith(
                  topLeft: const Radius.circular(4),
                ),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    themeColor.withValues(alpha: 0.08),
                    themeColor.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Corner rune decoration
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: themeColor.withValues(alpha: 0.4),
                    ),
                  ),
                  // Message text
                  Text(
                    message.text,
                    style: isInitialMessage
                        ? GoogleFonts.cinzel(
                            fontSize: 15,
                            height: 1.8,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          )
                        : AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.7,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.1, end: 0, duration: 400.ms);
  }
}

/// Character info for the chat header.
class CharacterInfo {
  final String id;
  final String name;
  final String title;
  final Color themeColor;
  final String greeting;

  const CharacterInfo({
    required this.id,
    required this.name,
    required this.title,
    required this.themeColor,
    required this.greeting,
  });

  static const CharacterInfo madameLuna = CharacterInfo(
    id: 'madame_luna',
    name: 'Madame Luna',
    title: 'The Moon Child',
    themeColor: AppColors.secondary,
    greeting: 'The stars have revealed much to you today, dear seeker. What questions stir within your heart?',
  );

  static const CharacterInfo elderWeiss = CharacterInfo(
    id: 'elder_weiss',
    name: 'Elder Weiss',
    title: 'The Ancient Sage',
    themeColor: AppColors.primary,
    greeting: 'The ancient wisdom has spoken. What clarity do you seek from these revelations?',
  );

  static const CharacterInfo nova = CharacterInfo(
    id: 'nova',
    name: 'Nova',
    title: 'The Stargazer',
    themeColor: AppColors.mysticTeal,
    greeting: 'Cosmic data streams have been analyzed. Query: What aspects require further computation?',
  );

  static const CharacterInfo shadow = CharacterInfo(
    id: 'shadow',
    name: 'Shadow',
    title: 'The Truth Seeker',
    themeColor: AppColors.error,
    greeting: 'The cards spoke their truth. Ask what you really want to know.',
  );

  static CharacterInfo fromId(String id) {
    switch (id) {
      case 'elder_weiss':
        return elderWeiss;
      case 'nova':
        return nova;
      case 'shadow':
        return shadow;
      case 'madame_luna':
      default:
        return madameLuna;
    }
  }
}
