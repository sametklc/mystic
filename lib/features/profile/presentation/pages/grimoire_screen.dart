import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/mystic_background/mystic_background_scaffold.dart';
import '../../data/providers/grimoire_provider.dart';
import '../../domain/models/grimoire_entry_model.dart';
import '../widgets/gallery_art_card.dart';
import '../widgets/journal_entry_card.dart';

/// The Grimoire screen - user's mystical journal and art gallery.
class GrimoireScreen extends ConsumerStatefulWidget {
  const GrimoireScreen({super.key});

  @override
  ConsumerState<GrimoireScreen> createState() => _GrimoireScreenState();
}

class _GrimoireScreenState extends ConsumerState<GrimoireScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MysticBackgroundScaffold(
      child: SafeArea(
        bottom: false, // Bottom nav handles this
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab Bar
            _buildTabBar(),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildJournalTab(),
                  _buildGalleryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(
            'GRIMOIRE',
            style: GoogleFonts.cinzel(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your Mystical Archive',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.glassBorder,
        ),
        color: AppColors.glassFill,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.3),
              AppColors.primary.withValues(alpha: 0.15),
            ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.cinzel(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: GoogleFonts.cinzel(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories, size: 16),
                const SizedBox(width: 8),
                const Text('JOURNAL'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 16),
                const SizedBox(width: 8),
                const Text('GALLERY'),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildJournalTab() {
    final grimoireState = ref.watch(grimoireProvider);

    if (grimoireState.isLoading) {
      return _buildLoadingState();
    }

    if (grimoireState.hasError) {
      return _buildErrorState(grimoireState.error!);
    }

    if (!grimoireState.hasEntries) {
      return _buildEmptyJournalState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(grimoireProvider.notifier).refresh(),
      color: AppColors.primary,
      backgroundColor: AppColors.backgroundSecondary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: grimoireState.entries.length,
        itemBuilder: (context, index) {
          final entry = grimoireState.entries[index];
          return JournalEntryCard(
            entry: entry,
            index: index,
            onTap: () => _showJournalDetail(entry),
          );
        },
      ),
    );
  }

  Widget _buildGalleryTab() {
    final galleryItems = ref.watch(galleryItemsProvider);

    if (galleryItems.isEmpty) {
      return _buildEmptyGalleryState();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: galleryItems.length,
        itemBuilder: (context, index) {
          final art = galleryItems[index];
          return GalleryArtCard(
            art: art,
            index: index,
            onTap: () => _openArtViewer(art),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Opening the Grimoire...',
            style: GoogleFonts.cinzel(
              fontSize: 14,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'The pages are obscured...',
            style: GoogleFonts.cinzel(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => ref.read(grimoireProvider.notifier).refresh(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Try Again',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyJournalState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.auto_stories,
              size: 36,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your Grimoire Awaits',
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Your past readings will be inscribed here for eternal wisdom.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildEmptyGalleryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
                width: 2,
              ),
              color: AppColors.secondary.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 36,
              color: AppColors.secondary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Gallery Empty',
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Enable AI Vision during readings to create mystical artwork.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  void _showJournalDetail(GrimoireEntryModel entry) {
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JournalDetailSheet(entry: entry),
    );
  }

  void _openArtViewer(GalleryArtModel art) {
    HapticFeedback.mediumImpact();

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ArtViewerScreen(art: art);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

/// Bottom sheet for journal entry details.
class _JournalDetailSheet extends StatelessWidget {
  final GrimoireEntryModel entry;

  const _JournalDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.backgroundTertiary,
                AppColors.background,
              ],
            ),
            border: Border(
              top: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Date and moon phase
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.formattedDate,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (entry.moonPhase != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.nightlight_round,
                            size: 14,
                            color: AppColors.secondary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.moonPhase!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Card name
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.cardName,
                              style: GoogleFonts.cinzel(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 1,
                              ),
                            ),
                            if (!entry.isUpright) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(Reversed)',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Image if available
                    if (entry.hasImage)
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            entry.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),

                    // Question
                    Text(
                      'Your Question',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${entry.question}"',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primary.withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Interpretation
                    Text(
                      'The Reading',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      entry.interpretation,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.8,
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
