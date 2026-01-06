import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/user_provider.dart';
import '../models/ai_persona.dart';
import 'ios_chat_screen.dart';

/// iOS Character Home - Messaging app style interface.
///
/// Designed to look like WhatsApp/Character.AI for App Store compliance.
/// No bottom tab bar - just a clean list of AI companions.
///
/// Personas:
/// - Mystic (Spiritual Guide) → Tarot
/// - Nova (Astro Guide) → Horoscope
/// - Rose (Relationship Coach) → Love Match
/// - Astra (Daily Wisdom) → Sanctuary
class IOSChatHome extends ConsumerStatefulWidget {
  const IOSChatHome({super.key});

  @override
  ConsumerState<IOSChatHome> createState() => _IOSChatHomeState();
}

class _IOSChatHomeState extends ConsumerState<IOSChatHome> {
  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(currentProfileProvider)?.name ?? 'Friend';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              floating: true,
              pinned: true,
              expandedHeight: 100,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'My Guides',
                            style: AppTypography.headlineLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hello, $userName',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Profile/Settings button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // TODO: Open settings/profile
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface,
                            border: Border.all(
                              color: AppColors.glassBorder,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Companions List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final persona = AIPersona.personas[index];
                    return _CompanionTile(
                      persona: persona,
                      onTap: () => _openChat(persona),
                    );
                  },
                  childCount: AIPersona.personas.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(AIPersona persona) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => IOSChatScreen(
          persona: persona,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

/// Individual companion tile - WhatsApp/iMessage style.
class _CompanionTile extends StatelessWidget {
  final AIPersona persona;
  final VoidCallback onTap;

  const _CompanionTile({
    required this.persona,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar with gradient
                _buildAvatar(),

                const SizedBox(width: 14),

                // Name, subtitle, and last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            persona.name,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Online indicator
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4CD964), // iOS green
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Subtitle (role)
                      Text(
                        persona.subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: persona.themeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Last message preview
                      Text(
                        persona.lastMessage,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: persona.gradient,
        boxShadow: [
          BoxShadow(
            color: persona.themeColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          persona.icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
