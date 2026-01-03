import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import 'tarot_card_fan.dart';

/// A grid of tarot cards displayed in 6-6-6-4 pattern.
/// Shows all 22 Major Arcana cards for selection.
class TarotCardGrid extends StatefulWidget {
  /// Callback when a card is selected.
  final void Function(int cardIndex)? onCardSelected;

  /// Selected card index (null if none selected).
  final int? selectedCardIndex;

  /// Whether selection is enabled.
  final bool selectionEnabled;

  const TarotCardGrid({
    super.key,
    this.onCardSelected,
    this.selectedCardIndex,
    this.selectionEnabled = true,
  });

  @override
  State<TarotCardGrid> createState() => _TarotCardGridState();
}

class _TarotCardGridState extends State<TarotCardGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  int? _tappedIndex;

  // Grid layout: 6-6-6-4 = 22 cards total
  static const List<int> rowCounts = [6, 6, 6, 4];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _onCardTap(int index) {
    if (!widget.selectionEnabled) return;

    HapticFeedback.mediumImpact();
    widget.onCardSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card size based on available width
        // 6 cards per row with spacing
        final availableWidth = constraints.maxWidth - 32; // 16px padding each side
        const horizontalSpacing = 6.0;
        final cardWidth = (availableWidth - (5 * horizontalSpacing)) / 6;
        final cardHeight = cardWidth * 1.5; // 2:3 aspect ratio
        const verticalSpacing = 8.0;

        return AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildRows(
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                  horizontalSpacing: horizontalSpacing,
                  verticalSpacing: verticalSpacing,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildRows({
    required double cardWidth,
    required double cardHeight,
    required double horizontalSpacing,
    required double verticalSpacing,
  }) {
    final rows = <Widget>[];
    int cardIndex = 0;

    for (int rowIndex = 0; rowIndex < rowCounts.length; rowIndex++) {
      final cardsInRow = rowCounts[rowIndex];
      final rowCards = <Widget>[];

      for (int i = 0; i < cardsInRow; i++) {
        final currentIndex = cardIndex;
        rowCards.add(
          _buildCard(currentIndex, cardWidth, cardHeight),
        );
        cardIndex++;

        // Add spacing between cards (not after last card)
        if (i < cardsInRow - 1) {
          rowCards.add(SizedBox(width: horizontalSpacing));
        }
      }

      // Create row - center all rows
      Widget row = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: rowCards,
      );

      // Animate each row with stagger
      row = row
          .animate(delay: Duration(milliseconds: 80 * rowIndex))
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);

      rows.add(row);

      // Add spacing between rows (not after last row)
      if (rowIndex < rowCounts.length - 1) {
        rows.add(SizedBox(height: verticalSpacing));
      }
    }

    return rows;
  }

  Widget _buildCard(int index, double cardWidth, double cardHeight) {
    final isSelected = widget.selectedCardIndex == index;
    final hasSelection = widget.selectedCardIndex != null;
    final isTapped = _tappedIndex == index;
    final glowIntensity = _glowController.value;

    double scale = 1.0;
    double opacity = 1.0;

    if (hasSelection) {
      if (isSelected) {
        scale = 1.15;
      } else {
        opacity = 0.3;
        scale = 0.95;
      }
    } else if (isTapped) {
      scale = 1.1;
    }

    return GestureDetector(
      onTap: () => _onCardTap(index),
      onTapDown: (_) => setState(() => _tappedIndex = index),
      onTapUp: (_) => setState(() => _tappedIndex = null),
      onTapCancel: () => setState(() => _tappedIndex = null),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: scale,
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.8 + glowIntensity * 0.2)
                    : AppColors.primary.withOpacity(0.25),
                width: isSelected ? 2 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.backgroundTertiary,
                  AppColors.backgroundSecondary,
                  AppColors.background,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3 + glowIntensity * 0.3),
                    blurRadius: 12 + glowIntensity * 8,
                    spreadRadius: 1 + glowIntensity * 2,
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Diagonal pattern
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: CustomPaint(
                      painter: _GridCardPatternPainter(
                        isSelected: isSelected,
                        glowIntensity: glowIntensity,
                      ),
                    ),
                  ),
                ),
                // Center icon
                Center(
                  child: Icon(
                    Icons.auto_awesome,
                    size: cardWidth * 0.35,
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.8 + glowIntensity * 0.2)
                        : AppColors.secondary.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pattern painter for grid cards
class _GridCardPatternPainter extends CustomPainter {
  final bool isSelected;
  final double glowIntensity;

  _GridCardPatternPainter({
    this.isSelected = false,
    this.glowIntensity = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    final patternColor = isSelected
        ? AppColors.primary.withOpacity(0.15 + glowIntensity * 0.15)
        : AppColors.secondary.withOpacity(0.08);
    paint.color = patternColor;

    // Diagonal lines
    for (int i = -5; i < 15; i++) {
      final startX = i * 8.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }

    // Inner border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = isSelected
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.secondary.withOpacity(0.1);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GridCardPatternPainter oldDelegate) {
    return oldDelegate.isSelected != isSelected ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
