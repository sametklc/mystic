import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../paywall/paywall.dart';
import '../../data/character_data.dart';
import '../../domain/models/character_model.dart';
import '../providers/character_provider.dart';

/// Gold color for premium accents
const Color _goldColor = Color(0xFFFFD700);
const Color _goldLight = Color(0xFFFFE55C);
const Color _goldDark = Color(0xFFB8860B);

/// An immersive 3D carousel for selecting tarot reader characters.
/// Features portrait Tarot-style cards with golden borders and ethereal effects.
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
      viewportFraction: 0.65, // Adjusted for portrait cards with room for neighbors
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

    final isPremium = ref.watch(isPremiumProvider);

    // Allow overflow so shadows and glows don't get clipped
    return ClipRect(
      clipBehavior: Clip.none,
      child: PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.none, // Critical: prevents clipping of scaled/glowing cards
        itemCount: characters.length,
        onPageChanged: (index) {
          ref.read(selectedCharacterIndexProvider.notifier).selectCharacter(index);
        },
        itemBuilder: (context, index) {
          final character = characters[index];
          // Luna (madame_luna) is free, others require premium
          final requiresPremium = character.id != 'madame_luna';
          final isLockedForUser = requiresPremium && !isPremium;

          return _buildCarouselCard(
            character: character,
            index: index,
            isActive: index == selectedIndex,
            isLockedForUser: isLockedForUser,
          );
        },
      ),
    );
  }

  Widget _buildCarouselCard({
    required CharacterModel character,
    required int index,
    required bool isActive,
    required bool isLockedForUser,
  }) {
    // Calculate parallax values based on scroll position
    final double difference = index - _currentPage;
    // More dramatic scaling for active card
    final double scale = isActive
        ? 1.0
        : 1 - (difference.abs() * 0.1).clamp(0.0, 0.12);
    final double opacity = 1 - (difference.abs() * 0.35).clamp(0.0, 0.45);
    final double rotation = difference * 0.06;
    final double translateY = difference.abs() * 20;

    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // Perspective
          ..rotateY(rotation)
          ..scale(isActive ? 1.05 : scale) // Active card scales up
          ..translate(0.0, isActive ? 0.0 : translateY),
        child: Opacity(
          opacity: opacity,
          child: _TarotCharacterCard(
            character: character,
            isActive: isActive,
            isLockedForUser: isLockedForUser,
            onTap: () => _onCharacterTap(index, isActive, isLockedForUser),
          ),
        ),
      ),
    );
  }

  void _onCharacterTap(int index, bool isActive, bool isLockedForUser) {
    if (!isActive) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _showCharacterSelected(index, isLockedForUser);
    }
  }

  void _showCharacterSelected(int index, bool isLockedForUser) {
    final character = CharacterData.characters[index];

    // If locked for this user (premium required), navigate to paywall
    if (isLockedForUser) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaywallView(
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
      return;
    }

    // If locked by system (coming soon)
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

/// Tarot-style portrait card with golden border and ethereal design.
class _TarotCharacterCard extends StatelessWidget {
  final CharacterModel character;
  final bool isActive;
  final bool isLockedForUser;
  final VoidCallback? onTap;

  const _TarotCharacterCard({
    required this.character,
    required this.isActive,
    this.isLockedForUser = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = character.themeColor;

    Widget card = GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate card dimensions based on available space
          // Use 3:4.5 aspect ratio (portrait tarot style)
          final cardHeight = constraints.maxHeight * 0.92; // Leave room for glow
          final cardWidth = cardHeight * 0.65; // 3:4.5 aspect ratio

          return Center(
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // Golden border with glow
                border: Border.all(
                  color: isActive ? _goldColor : _goldDark.withOpacity(0.5),
                  width: isActive ? 2.5 : 1.5,
                ),
                // Dramatic glow for active card
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _goldColor.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: _goldDark.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Deep gradient background
                    _buildBackground(themeColor),

                    // Noise texture overlay
                    _buildNoiseTexture(),

                    // Main content
                    _buildCardContent(context, themeColor),

                    // Premium lock overlay (for non-premium users)
                    if (isLockedForUser) _buildPremiumLockOverlay(themeColor),

                    // System lock overlay (coming soon)
                    if (character.isLocked && !isLockedForUser) _buildLockOverlay(themeColor),

                    // Golden corner accents
                    _buildCornerAccents(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // Subtle pulse animation for active card (only if unlocked)
    if (isActive && !character.isLocked && !isLockedForUser) {
      card = card
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .shimmer(
            duration: 3.seconds,
            color: _goldColor.withOpacity(0.15),
          );
    }

    return card;
  }

  /// Premium lock overlay - shows when character requires premium
  Widget _buildPremiumLockOverlay(Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium crown icon with glow
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_goldColor, _goldDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: _goldColor.withOpacity(0.5),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              size: 32,
              color: Color(0xFF1A0A2E),
            ),
          ),
          const SizedBox(height: 16),
          // "PREMIUM" text with gold gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_goldDark, _goldColor, _goldLight, _goldColor, _goldDark],
            ).createShader(bounds),
            child: Text(
              'PREMIUM',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
                letterSpacing: 3.0,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // "Tap to Unlock" subtitle
          Text(
            'Tap to Unlock',
            style: AppTypography.bodySmall.copyWith(
              color: _goldColor.withOpacity(0.7),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            themeColor.withOpacity(0.4),
            const Color(0xFF1A0A2E), // Deep violet
            const Color(0xFF0D0514), // Near black
            Colors.black,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildNoiseTexture() {
    return Opacity(
      opacity: 0.05,
      child: CustomPaint(
        painter: _NoisePainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Large character image in top portion
          Expanded(
            flex: 6,
            child: _buildLargeAvatar(themeColor),
          ),

          const SizedBox(height: 8),

          // Divider with gold gradient
          _buildGoldDivider(),

          const SizedBox(height: 8),

          // Name and title at bottom with gold gradient text
          _buildNameSection(themeColor),
        ],
      ),
    );
  }

  Widget _buildLargeAvatar(Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: _goldColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          character.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    themeColor.withOpacity(0.3),
                    themeColor.withOpacity(0.1),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  _getCharacterIcon(),
                  size: 48,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.easeOutBack,
        );
  }

  Widget _buildGoldDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _goldColor.withOpacity(0.3),
            _goldColor.withOpacity(0.6),
            _goldColor.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _goldColor.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(Color themeColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Character name with gold gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_goldDark, _goldColor, _goldLight, _goldColor, _goldDark],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(bounds),
          child: Text(
            character.name.toUpperCase(),
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
              letterSpacing: 3.0,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 6),

        // Character title with subtle gold
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              _goldDark.withOpacity(0.8),
              _goldColor.withOpacity(0.9),
              _goldDark.withOpacity(0.8),
            ],
          ).createShader(bounds),
          child: Text(
            character.title,
            style: AppTypography.mysticalQuote.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 8),

        // Description
        Text(
          character.description,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.6),
            fontSize: 9,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCornerAccents() {
    return Stack(
      children: [
        // Top left corner
        Positioned(
          top: 8,
          left: 8,
          child: _buildCornerSymbol(),
        ),
        // Top right corner (mirrored)
        Positioned(
          top: 8,
          right: 8,
          child: Transform.scale(
            scaleX: -1,
            child: _buildCornerSymbol(),
          ),
        ),
        // Bottom left corner (rotated)
        Positioned(
          bottom: 8,
          left: 8,
          child: Transform.rotate(
            angle: math.pi,
            child: Transform.scale(
              scaleX: -1,
              child: _buildCornerSymbol(),
            ),
          ),
        ),
        // Bottom right corner (rotated)
        Positioned(
          bottom: 8,
          right: 8,
          child: Transform.rotate(
            angle: math.pi,
            child: _buildCornerSymbol(),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerSymbol() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _goldColor.withOpacity(0.4), width: 1),
          left: BorderSide(color: _goldColor.withOpacity(0.4), width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _goldColor.withOpacity(0.5),
            boxShadow: [
              BoxShadow(
                color: _goldColor.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockOverlay(Color themeColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.4),
              border: Border.all(
                color: _goldColor.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _goldColor.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.lock_outline,
              size: 32,
              color: _goldColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_goldDark, _goldColor, _goldDark],
            ).createShader(bounds),
            child: Text(
              'COMING SOON',
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
                letterSpacing: 2.5,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
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
}

/// Custom painter for subtle noise texture
class _NoisePainter extends CustomPainter {
  final math.Random _random = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (int i = 0; i < 500; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final opacity = _random.nextDouble() * 0.5;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
