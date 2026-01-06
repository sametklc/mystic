import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../paywall/paywall.dart';
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

/// Premium teaser message bubble - distinct purple/gold gradient style.
/// Shown when a free user asks a complex question that requires premium.
class PremiumTeaserMessage extends StatelessWidget {
  /// The teaser text from the character.
  /// Default: 'I can see the alignment regarding your question, but I need a deeper connection to reveal the details...'
  final String? teaserText;

  /// Character name for personalization.
  final String? characterName;

  /// Theme color for the character (used for accents).
  final Color themeColor;

  /// Callback when premium is unlocked (optional).
  final VoidCallback? onPremiumUnlocked;

  const PremiumTeaserMessage({
    super.key,
    this.teaserText,
    this.characterName,
    this.themeColor = AppColors.secondary,
    this.onPremiumUnlocked,
  });

  static const _defaultTeaserText =
      'I can see the alignment regarding your question, but I need a deeper connection to reveal the details...';

  // Premium gradient colors
  static const _purpleDark = Color(0xFF1A0A2E);
  static const _purpleMid = Color(0xFF2D1B4E);
  static const _goldAccent = Color(0xFFFFD700);
  static const _goldDark = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        margin: const EdgeInsets.only(left: 16, right: 24, top: 12, bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24).copyWith(
              topLeft: const Radius.circular(4),
            ),
            // Dark purple/gold gradient background
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _purpleDark,
                _purpleMid,
                Color(0xFF1F1035),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: _goldAccent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              // Gold glow
              BoxShadow(
                color: _goldAccent.withValues(alpha: 0.15),
                blurRadius: 25,
                spreadRadius: 0,
              ),
              // Purple ambient glow
              BoxShadow(
                color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              // Dark shadow for depth
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Decorative header with mystical icon
              Row(
                children: [
                  // Glowing mystical eye icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_goldAccent, _goldDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _goldAccent.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.visibility,
                      size: 18,
                      color: _purpleDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // "Vision Glimpsed" label
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_goldAccent, _goldDark, _goldAccent],
                    ).createShader(bounds),
                    child: Text(
                      'VISION GLIMPSED',
                      style: GoogleFonts.cinzel(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Decorative star
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: _goldAccent.withValues(alpha: 0.6),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Teaser message text
              Text(
                teaserText ?? _defaultTeaserText,
                style: GoogleFonts.cinzel(
                  fontSize: 14,
                  height: 1.7,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 20),

              // Divider with mystical pattern
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _goldAccent.withValues(alpha: 0.5),
                            _goldAccent.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.diamond_outlined,
                      size: 14,
                      color: _goldAccent.withValues(alpha: 0.7),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _goldAccent.withValues(alpha: 0.3),
                            _goldAccent.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Premium unlock button
              GestureDetector(
                onTap: () => _navigateToPaywall(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [_goldAccent, _goldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _goldAccent.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        size: 18,
                        color: _purpleDark,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Unlock Full Answer & Go Premium',
                        style: GoogleFonts.cinzel(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _purpleDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(
                    duration: 2500.ms,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),

              const SizedBox(height: 8),

              // Subtle hint text
              Center(
                child: Text(
                  'Premium unlocks unlimited readings & full insights',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideX(begin: -0.1, end: 0, duration: 400.ms)
        .then()
        .shimmer(
          duration: 3000.ms,
          color: _goldAccent.withValues(alpha: 0.1),
          delay: 500.ms,
        );
  }

  void _navigateToPaywall(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallView(
          onClose: () {
            Navigator.of(context).pop();
            onPremiumUnlocked?.call();
          },
        ),
      ),
    );
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
