import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';

/// Data for Major Arcana cards
class MajorArcanaCard {
  final int index;
  final String name;
  final String numeral;

  const MajorArcanaCard({
    required this.index,
    required this.name,
    required this.numeral,
  });
}

/// The 22 Major Arcana cards
const List<MajorArcanaCard> majorArcana = [
  MajorArcanaCard(index: 0, name: 'The Fool', numeral: '0'),
  MajorArcanaCard(index: 1, name: 'The Magician', numeral: 'I'),
  MajorArcanaCard(index: 2, name: 'The High Priestess', numeral: 'II'),
  MajorArcanaCard(index: 3, name: 'The Empress', numeral: 'III'),
  MajorArcanaCard(index: 4, name: 'The Emperor', numeral: 'IV'),
  MajorArcanaCard(index: 5, name: 'The Hierophant', numeral: 'V'),
  MajorArcanaCard(index: 6, name: 'The Lovers', numeral: 'VI'),
  MajorArcanaCard(index: 7, name: 'The Chariot', numeral: 'VII'),
  MajorArcanaCard(index: 8, name: 'Strength', numeral: 'VIII'),
  MajorArcanaCard(index: 9, name: 'The Hermit', numeral: 'IX'),
  MajorArcanaCard(index: 10, name: 'Wheel of Fortune', numeral: 'X'),
  MajorArcanaCard(index: 11, name: 'Justice', numeral: 'XI'),
  MajorArcanaCard(index: 12, name: 'The Hanged Man', numeral: 'XII'),
  MajorArcanaCard(index: 13, name: 'Death', numeral: 'XIII'),
  MajorArcanaCard(index: 14, name: 'Temperance', numeral: 'XIV'),
  MajorArcanaCard(index: 15, name: 'The Devil', numeral: 'XV'),
  MajorArcanaCard(index: 16, name: 'The Tower', numeral: 'XVI'),
  MajorArcanaCard(index: 17, name: 'The Star', numeral: 'XVII'),
  MajorArcanaCard(index: 18, name: 'The Moon', numeral: 'XVIII'),
  MajorArcanaCard(index: 19, name: 'The Sun', numeral: 'XIX'),
  MajorArcanaCard(index: 20, name: 'Judgement', numeral: 'XX'),
  MajorArcanaCard(index: 21, name: 'The World', numeral: 'XXI'),
];

/// A fan of tarot cards that the user can scroll through and select.
class TarotCardFan extends StatefulWidget {
  /// Callback when a card is selected.
  final void Function(int cardIndex)? onCardSelected;

  /// Whether the fan should animate in on first build.
  final bool animateIn;

  /// Selected card index (null if none selected).
  final int? selectedCardIndex;

  /// Whether selection is enabled.
  final bool selectionEnabled;

  const TarotCardFan({
    super.key,
    this.onCardSelected,
    this.animateIn = true,
    this.selectedCardIndex,
    this.selectionEnabled = true,
  });

  @override
  State<TarotCardFan> createState() => _TarotCardFanState();
}

class _TarotCardFanState extends State<TarotCardFan>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _selectionController;
  late AnimationController _glowController;

  int? _hoveredIndex;
  bool _hasAnimatedIn = false;

  // Card dimensions
  static const double cardWidth = 70;
  static const double cardHeight = 120;
  static const double cardSpacing = 25; // Overlap amount

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Center the scroll initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(maxScroll / 2);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selectionController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TarotCardFan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCardIndex != null &&
        oldWidget.selectedCardIndex == null) {
      _selectionController.forward();
    }
  }

  void _onCardTap(int index) {
    if (!widget.selectionEnabled) return;

    HapticFeedback.mediumImpact();
    widget.onCardSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = majorArcana.length * cardSpacing + cardWidth;

    return SizedBox(
      height: cardHeight + 100, // Extra space for hover lift
      child: AnimatedBuilder(
        animation: Listenable.merge([_selectionController, _glowController]),
        builder: (context, child) {
          return SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: widget.selectedCardIndex == null
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width / 2 - cardWidth / 2,
            ),
            child: SizedBox(
              width: totalWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(majorArcana.length, (index) {
                  return _buildCard(index);
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(int index) {
    final isSelected = widget.selectedCardIndex == index;
    final hasSelection = widget.selectedCardIndex != null;
    final isHovered = _hoveredIndex == index;

    // Calculate position in the fan
    final baseX = index * cardSpacing;

    // Calculate rotation angle for fan effect (-15 to +15 degrees)
    final normalizedIndex = (index - majorArcana.length / 2) / (majorArcana.length / 2);
    final rotationAngle = normalizedIndex * 0.15; // radians

    // Selection animation values
    final selectionProgress = _selectionController.value;
    final glowIntensity = _glowController.value;

    // Calculate transforms based on state
    double translateY = 50; // Base position
    double scale = 1.0;
    double opacity = 1.0;

    if (hasSelection) {
      if (isSelected) {
        // Selected card floats up and grows
        translateY = 50 - (80 * selectionProgress);
        scale = 1.0 + (0.3 * selectionProgress);
      } else {
        // Other cards fade out and sink
        opacity = 1.0 - (0.8 * selectionProgress);
        translateY = 50 + (30 * selectionProgress);
        scale = 1.0 - (0.1 * selectionProgress);
      }
    } else if (isHovered) {
      translateY = 30;
      scale = 1.1;
    }

    Widget card = Positioned(
      left: baseX,
      top: 0,
      child: GestureDetector(
        onTap: () => _onCardTap(index),
        onTapDown: (_) => setState(() => _hoveredIndex = index),
        onTapUp: (_) => setState(() => _hoveredIndex = null),
        onTapCancel: () => setState(() => _hoveredIndex = null),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: opacity,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translate(0.0, translateY)
              ..rotateZ(hasSelection && isSelected ? 0 : rotationAngle)
              ..scale(scale),
            child: _TarotCardBack(
              isSelected: isSelected,
              glowIntensity: isSelected ? glowIntensity : 0,
            ),
          ),
        ),
      ),
    );

    // Apply entrance animation
    if (widget.animateIn && !_hasAnimatedIn) {
      card = card
          .animate(
            delay: Duration(milliseconds: 50 * index),
            onComplete: (controller) {
              if (index == majorArcana.length - 1) {
                _hasAnimatedIn = true;
              }
            },
          )
          .fadeIn(duration: 400.ms)
          .slideY(begin: 2, end: 0, duration: 600.ms, curve: Curves.easeOutBack)
          .rotate(begin: 0.5, end: 0, duration: 500.ms);
    }

    return card;
  }
}

/// The back of a tarot card (face down).
class _TarotCardBack extends StatelessWidget {
  final bool isSelected;
  final double glowIntensity;

  const _TarotCardBack({
    this.isSelected = false,
    this.glowIntensity = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withOpacity(0.8 + glowIntensity * 0.2)
              : AppColors.primary.withOpacity(0.3),
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
          // Base shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
          // Gold glow when selected
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3 + glowIntensity * 0.4),
              blurRadius: 20 + glowIntensity * 15,
              spreadRadius: 2 + glowIntensity * 3,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Mystical pattern on card back
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _CardBackPatternPainter(
                  isSelected: isSelected,
                  glowIntensity: glowIntensity,
                ),
              ),
            ),
          ),
          // Center ornament
          Center(
            child: Container(
              width: 40,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.6 + glowIntensity * 0.4)
                      : AppColors.secondary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome,
                  size: 24,
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.8 + glowIntensity * 0.2)
                      : AppColors.secondary.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the mystical pattern on card backs.
class _CardBackPatternPainter extends CustomPainter {
  final bool isSelected;
  final double glowIntensity;

  _CardBackPatternPainter({
    this.isSelected = false,
    this.glowIntensity = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw mystical pattern lines
    final patternColor = isSelected
        ? AppColors.primary.withOpacity(0.2 + glowIntensity * 0.2)
        : AppColors.secondary.withOpacity(0.1);
    paint.color = patternColor;

    // Diagonal lines
    for (int i = -10; i < 20; i++) {
      final startX = i * 10.0;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }

    // Border lines
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = isSelected
          ? AppColors.primary.withOpacity(0.3)
          : AppColors.secondary.withOpacity(0.15);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CardBackPatternPainter oldDelegate) {
    return oldDelegate.isSelected != isSelected ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
