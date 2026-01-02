import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../data/character_data.dart';
import '../../domain/models/character_model.dart';
import '../providers/character_provider.dart';

/// An immersive 3D carousel for selecting tarot reader characters.
/// Features parallax effects, glassmorphism cards, and smooth animations.
class CharacterCarousel extends ConsumerStatefulWidget {
  const CharacterCarousel({super.key});

  @override
  ConsumerState<CharacterCarousel> createState() => _CharacterCarouselState();
}

class _CharacterCarouselState extends ConsumerState<CharacterCarousel> {
  late PageController _pageController;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.75,
      initialPage: ref.read(selectedCharacterIndexProvider),
    );
    _currentPage = ref.read(selectedCharacterIndexProvider).toDouble();

    _pageController.addListener(_onPageScroll);
  }

  void _onPageScroll() {
    setState(() {
      _currentPage = _pageController.page ?? 0;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final characters = CharacterData.characters;
    final selectedIndex = ref.watch(selectedCharacterIndexProvider);

    // Make carousel height responsive to screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = screenHeight < 700 ? 320.0 : (screenHeight < 800 ? 360.0 : 400.0);

    return SizedBox(
      height: carouselHeight,
      child: PageView.builder(
        controller: _pageController,
        itemCount: characters.length,
        onPageChanged: (index) {
          ref.read(selectedCharacterIndexProvider.notifier).state = index;
        },
        itemBuilder: (context, index) {
          return _buildCarouselCard(
            character: characters[index],
            index: index,
            isActive: index == selectedIndex,
          );
        },
      ),
    );
  }

  Widget _buildCarouselCard({
    required CharacterModel character,
    required int index,
    required bool isActive,
  }) {
    // Calculate parallax values based on scroll position
    final double difference = index - _currentPage;
    final double scale = 1 - (difference.abs() * 0.15).clamp(0.0, 0.15);
    final double opacity = 1 - (difference.abs() * 0.5).clamp(0.0, 0.5);
    final double rotation = difference * 0.05;
    final double translateY = difference.abs() * 30;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(rotation)
        ..scale(scale)
        ..translate(0.0, translateY),
      child: Opacity(
        opacity: opacity,
        child: _CharacterCard(
          character: character,
          isActive: isActive,
          onTap: () => _onCharacterTap(index, isActive),
        ),
      ),
    );
  }

  void _onCharacterTap(int index, bool isActive) {
    if (!isActive) {
      // Animate to this character's page
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Already selected - show character details or proceed to reading
      _showCharacterSelected(index);
    }
  }

  void _showCharacterSelected(int index) {
    final character = CharacterData.characters[index];

    if (character.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${character.name} is locked. Coming soon!'),
          backgroundColor: character.themeColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Show confirmation that character is selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${character.name} will guide your reading'),
        backgroundColor: character.themeColor.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Individual character card with glassmorphism design.
class _CharacterCard extends StatelessWidget {
  final CharacterModel character;
  final bool isActive;
  final VoidCallback? onTap;

  const _CharacterCard({
    required this.character,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = character.themeColor;

    Widget card = GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSmall,
        vertical: AppConstants.spacingMedium,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.glassBorderRadius),
        // Glowing border for active card
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: themeColor.withOpacity(0.6),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: themeColor.withOpacity(0.3),
                  blurRadius: 50,
                  spreadRadius: 5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.glassBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppConstants.glassBlur,
            sigmaY: AppConstants.glassBlur,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.glassBorderRadius),
              border: Border.all(
                color: isActive
                    ? themeColor.withOpacity(0.5)
                    : AppColors.glassBorder,
                width: isActive ? 2 : AppConstants.glassBorderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeColor.withOpacity(0.15),
                  AppColors.glassFill,
                  themeColor.withOpacity(0.1),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Background gradient effect
                _buildBackgroundGradient(themeColor),

                // Main content
                _buildCardContent(context),

                // Lock overlay
                if (character.isLocked) _buildLockOverlay(context),
              ],
            ),
          ),
        ),
      ),
      ),
    );

    // Add pulse animation for active card
    if (isActive) {
      card = card
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.02, 1.02),
            duration: 2.seconds,
            curve: Curves.easeInOut,
          );
    }

    return card;
  }

  Widget _buildBackgroundGradient(Color themeColor) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              themeColor.withOpacity(0.3),
              themeColor.withOpacity(0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final themeColor = character.themeColor;
    // Use white/light text for better contrast against colored gradients
    final nameColor = Colors.white;
    final titleColor = Colors.white.withOpacity(0.85);
    final descColor = Colors.white.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Character avatar placeholder with gradient
          _buildCharacterAvatar(themeColor),

          const SizedBox(height: AppConstants.spacingLarge),

          // Character name (Cinzel font) - white with glow for contrast
          Text(
            character.name.toUpperCase(),
            style: AppTypography.headlineMedium.copyWith(
              color: nameColor,
              letterSpacing: 2.5,
              shadows: [
                Shadow(
                  color: themeColor,
                  blurRadius: 15,
                ),
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 5,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.spacingSmall),

          // Character title
          Text(
            character.title,
            style: AppTypography.mysticalQuote.copyWith(
              color: titleColor,
              fontSize: 14,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.spacingMedium),

          // Character description
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingSmall,
            ),
            child: Text(
              character.description,
              style: AppTypography.bodySmall.copyWith(
                color: descColor,
                height: 1.6,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 3,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const Spacer(),

          // Status indicator
          _buildStatusIndicator(themeColor),
        ],
      ),
    );
  }

  Widget _buildCharacterAvatar(Color themeColor) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            themeColor.withOpacity(0.5),
            themeColor.withOpacity(0.3),
            themeColor.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _getCharacterIcon(),
          size: 48,
          color: Colors.white,
          shadows: [
            Shadow(
              color: themeColor,
              blurRadius: 10,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }

  IconData _getCharacterIcon() {
    switch (character.id) {
      case 'madame_luna':
        return Icons.nightlight_round;
      case 'elder_weiss':
        return Icons.auto_stories;
      case 'nova':
        return Icons.stars;
      case 'shadow':
        return Icons.visibility;
      default:
        return Icons.person;
    }
  }

  Widget _buildStatusIndicator(Color themeColor) {
    if (character.isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMedium,
          vertical: AppConstants.spacingSmall,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
          color: AppColors.backgroundTertiary.withOpacity(0.8),
          border: Border.all(
            color: AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppConstants.spacingXSmall),
            Text(
              'LOCKED',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMedium,
        vertical: AppConstants.spacingSmall,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
        gradient: LinearGradient(
          colors: [
            themeColor.withOpacity(0.3),
            themeColor.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: themeColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 14,
            color: themeColor,
          ),
          const SizedBox(width: AppConstants.spacingXSmall),
          Text(
            'AVAILABLE',
            style: AppTypography.labelSmall.copyWith(
              color: themeColor,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockOverlay(BuildContext context) {
    final themeColor = character.themeColor;

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.glassBorderRadius),
        child: Container(
          decoration: BoxDecoration(
            // Subtle gradient overlay - less harsh than solid black
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.5),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            children: [
              // Coming Soon badge at top
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMedium),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMedium,
                    vertical: AppConstants.spacingSmall,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
                    gradient: LinearGradient(
                      colors: [
                        themeColor.withOpacity(0.4),
                        themeColor.withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(
                      color: themeColor.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'COMING SOON',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .shimmer(
                      duration: 2.seconds,
                      color: themeColor.withOpacity(0.3),
                    ),
              ),

              const Spacer(),

              // Character name visible at bottom
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingLarge),
                child: Column(
                  children: [
                    Text(
                      character.name.toUpperCase(),
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: themeColor,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      character.title,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
