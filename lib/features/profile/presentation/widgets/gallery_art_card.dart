import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../paywall/paywall.dart';
import '../../../tarot/data/tarot_deck_assets.dart';
import '../../domain/models/grimoire_entry_model.dart';

/// A gallery art card for the masonry grid.
/// Shows blur + lock for non-premium users.
class GalleryArtCard extends ConsumerWidget {
  final GalleryArtModel art;
  final VoidCallback? onTap;
  final int index;

  const GalleryArtCard({
    super.key,
    required this.art,
    this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPremium) {
          onTap?.call();
        } else {
          // Navigate to paywall
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaywallView(
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          );
        }
      },
      child: Hero(
        tag: 'gallery_${art.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                // Image with asset fallback - BLURRED if not premium
                ImageFiltered(
                  imageFilter: isPremium
                      ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                      : ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: _buildCardImage(),
                ),

                // Bottom gradient overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      art.cardName,
                      style: GoogleFonts.cinzel(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Shine effect on top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Lock overlay for non-premium users
                if (!isPremium) _buildLockOverlay(),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 400.ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 400.ms);
  }

  Widget _buildLockOverlay() {
    const goldAccent = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lock icon with glow
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1025),
                border: Border.all(
                  color: goldAccent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: goldAccent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [goldAccent, goldDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Unlock text
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [goldAccent, goldDark],
              ).createShader(bounds),
              child: Text(
                'UNLOCK',
                style: GoogleFonts.cinzel(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage() {
    final assetPath = TarotDeckAssets.getCardByName(art.cardName);

    // Try network image first, fallback to asset
    if (art.imageUrl.isNotEmpty) {
      return Image.network(
        art.imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return AspectRatio(
            aspectRatio: 9 / 16,
            child: Container(
              color: AppColors.backgroundSecondary,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Fallback to local asset
          return Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  color: AppColors.backgroundSecondary,
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary.withValues(alpha: 0.5),
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // No network URL, use local asset
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            color: AppColors.backgroundSecondary,
            child: Center(
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full screen art viewer with Hero animation.
/// Only accessible for premium users.
class ArtViewerScreen extends StatefulWidget {
  final GalleryArtModel art;

  const ArtViewerScreen({
    super.key,
    required this.art,
  });

  @override
  State<ArtViewerScreen> createState() => _ArtViewerScreenState();
}

class _ArtViewerScreenState extends State<ArtViewerScreen> {
  bool _isSaving = false;
  bool _isSharing = false;

  GalleryArtModel get art => widget.art;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image with Hero
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Hero(
                  tag: 'gallery_${art.id}',
                  child: _buildFullImage(),
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        art.cardName.toUpperCase(),
                        style: GoogleFonts.cinzel(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Save button
                      _buildActionButton(
                        icon: _isSaving ? Icons.hourglass_empty : Icons.download_rounded,
                        label: _isSaving ? 'Saving...' : 'Save',
                        onTap: _isSaving ? null : _saveImage,
                      ),

                      const SizedBox(width: 32),

                      // Share button
                      _buildActionButton(
                        icon: _isSharing ? Icons.hourglass_empty : Icons.share_rounded,
                        label: _isSharing ? 'Sharing...' : 'Share',
                        onTap: _isSharing ? null : _shareImage,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      Uint8List? imageBytes;

      if (art.imageUrl.isNotEmpty) {
        // Download from network
        final response = await http.get(Uri.parse(art.imageUrl));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      }

      if (imageBytes == null) {
        // Fallback to asset
        final assetPath = TarotDeckAssets.getCardByName(art.cardName);
        final byteData = await rootBundle.load(assetPath);
        imageBytes = byteData.buffer.asUint8List();
      }

      // Save to gallery
      final result = await ImageGallerySaverPlus.saveImage(
        imageBytes,
        quality: 100,
        name: 'mystic_${art.cardName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        final success = result['isSuccess'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(success ? 'Saved to gallery!' : 'Failed to save'),
              ],
            ),
            backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      Uint8List? imageBytes;

      if (art.imageUrl.isNotEmpty) {
        // Download from network
        final response = await http.get(Uri.parse(art.imageUrl));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      }

      if (imageBytes == null) {
        // Fallback to asset
        final assetPath = TarotDeckAssets.getCardByName(art.cardName);
        final byteData = await rootBundle.load(assetPath);
        imageBytes = byteData.buffer.asUint8List();
      }

      // Save to temp file for sharing
      final tempDir = await getTemporaryDirectory();
      final fileName = 'mystic_${art.cardName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Get share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '✨ ${art.cardName} - Created with Mystic ✨',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            color: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullImage() {
    final assetPath = TarotDeckAssets.getCardByName(art.cardName);

    if (art.imageUrl.isNotEmpty) {
      return Image.network(
        art.imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            assetPath,
            fit: BoxFit.contain,
          );
        },
      );
    }

    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
    );
  }
}
