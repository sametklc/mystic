import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../tarot/data/tarot_deck_assets.dart';
import '../../data/providers/daily_tarot_provider.dart';
import '../providers/character_provider.dart';
import 'tarot_reveal_overlay.dart';

/// Premium Daily Tarot Card widget with cinematic design.
///
/// **State A (Not Drawn):** Card back with pulsing glow, "Tap to reveal"
/// **State B (Revealed):** Card face with gradient overlay and name
///
/// First tap of the day triggers the cinematic spin-to-reveal overlay.
/// Subsequent taps show the detail sheet directly.
class DailyTarotCard extends ConsumerStatefulWidget {
  final bool isCompact;

  const DailyTarotCard({
    super.key,
    this.isCompact = false,
  });

  @override
  ConsumerState<DailyTarotCard> createState() => _DailyTarotCardState();
}

class _DailyTarotCardState extends ConsumerState<DailyTarotCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onCardTap() async {
    final state = ref.read(dailyTarotProvider);

    if (state.isLoading) return;

    HapticFeedback.mediumImpact();

    if (state.isRevealed && state.dailyTarot != null) {
      // Already revealed - show detail sheet directly
      _showDailyTarotSheet(context, state.dailyTarot!);
    } else {
      // First reveal of the day - trigger the cinematic experience
      // Use the selected guide character
      final selectedCharacterId = ref.read(selectedCharacterIdProvider);
      final isNewReveal = await ref.read(dailyTarotProvider.notifier).drawDailyCard(
        characterId: selectedCharacterId,
      );

      final newState = ref.read(dailyTarotProvider);
      if (newState.isRevealed && newState.dailyTarot != null && mounted) {
        if (isNewReveal) {
          // Show cinematic reveal overlay
          await TarotRevealOverlay.show(context, newState.dailyTarot!);
          ref.read(dailyTarotProvider.notifier).markRevealSeen();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyTarotProvider);

    return GestureDetector(
      onTap: _onCardTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                // 3D shadow effect
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
                if (!state.isRevealed)
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(
                      0.15 + _pulseController.value * 0.15,
                    ),
                    blurRadius: 15 + _pulseController.value * 10,
                    spreadRadius: _pulseController.value * 5,
                  )
                else
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: state.isRevealed && state.dailyTarot != null
                  ? _buildCardFront(state.dailyTarot!)
                  : _buildCardBack(state),
            ),
          );
        },
      ),
    );
  }

  /// State A: Card back with pulsing glow (or loading state)
  Widget _buildCardBack(DailyTarotState state) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed card back image
        Image.asset(
          TarotDeckAssets.getCardBack(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2D1B4E),
                    const Color(0xFF1A0A2E),
                    Colors.black,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.style_rounded,
                  color: AppColors.secondary.withOpacity(0.5),
                  size: 48,
                ),
              ),
            );
          },
        ),

        // Animated pulse overlay
        if (!state.isLoading)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      AppColors.secondary.withOpacity(0.0),
                      AppColors.secondary.withOpacity(
                        0.05 + _pulseController.value * 0.1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // Bottom gradient for text
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // Loading overlay
        if (state.isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(AppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drawing...',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.secondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom text content
        if (!state.isLoading)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tarot',
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 12,
                      color: AppColors.secondary.withOpacity(0.8),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.2, 1.2),
                          duration: 800.ms,
                        ),
                    const SizedBox(width: 4),
                    Text(
                      state.hasError ? 'Tap to retry' : 'Tap to reveal',
                      style: AppTypography.bodySmall.copyWith(
                        color: state.hasError
                            ? AppColors.secondary
                            : Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Animated glow border
        if (!state.isLoading)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(
                        0.2 + _pulseController.value * 0.3,
                      ),
                      width: 1 + _pulseController.value,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// State B: Revealed card with full image and gradient overlay
  Widget _buildCardFront(DailyTarot dailyTarot) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed card image
        Transform(
          transform: dailyTarot.isUpright
              ? Matrix4.identity()
              : (Matrix4.identity()..rotateZ(math.pi)),
          alignment: Alignment.center,
          child: Image.asset(
            TarotDeckAssets.getCardByName(dailyTarot.cardName),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.secondary.withOpacity(0.3),
                      const Color(0xFF1A0A2E),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.style_rounded,
                    color: AppColors.secondary,
                    size: 48,
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom gradient overlay for text
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // Card name and details
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dailyTarot.cardName,
                style: AppTypography.titleSmall.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Orientation badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: dailyTarot.isUpright
                          ? AppColors.secondary.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: dailyTarot.isUpright
                            ? AppColors.secondary.withOpacity(0.4)
                            : AppColors.primary.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      dailyTarot.isUpright ? '^ Upright' : 'v Reversed',
                      style: AppTypography.labelSmall.copyWith(
                        color: dailyTarot.isUpright
                            ? AppColors.secondary
                            : AppColors.primary,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap for details',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Border
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.4),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDailyTarotSheet(BuildContext context, DailyTarot dailyTarot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DailyTarotBottomSheet(dailyTarot: dailyTarot),
    );
  }
}

/// Bottom sheet showing full daily tarot details.
class _DailyTarotBottomSheet extends StatelessWidget {
  final DailyTarot dailyTarot;

  const _DailyTarotBottomSheet({required this.dailyTarot});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Card Image (Large)
                  Container(
                    width: 160,
                    height: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform(
                      transform: dailyTarot.isUpright
                          ? Matrix4.identity()
                          : (Matrix4.identity()..rotateZ(math.pi)),
                      alignment: Alignment.center,
                      child: Image.asset(
                        TarotDeckAssets.getCardByName(dailyTarot.cardName),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.secondary.withOpacity(0.2),
                            child: const Icon(
                              Icons.style_rounded,
                              color: AppColors.secondary,
                              size: 60,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

                  const SizedBox(height: 20),

                  // Card Name
                  Text(
                    dailyTarot.cardName,
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Orientation badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dailyTarot.isUpright
                          ? AppColors.secondary.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dailyTarot.isUpright
                            ? AppColors.secondary.withOpacity(0.3)
                            : AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      dailyTarot.isUpright ? 'Upright' : 'Reversed',
                      style: AppTypography.labelSmall.copyWith(
                        color: dailyTarot.isUpright
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Full Interpretation
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: AppColors.secondary.withOpacity(0.7),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dailyTarot.interpretation.isNotEmpty
                              ? dailyTarot.interpretation
                              : 'Today\'s guidance awaits you. Embrace the energy of ${dailyTarot.cardName}.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // Close button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.textTertiary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
