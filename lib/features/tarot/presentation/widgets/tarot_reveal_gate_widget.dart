import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../paywall/paywall.dart';

/// A high-tension tarot card reveal widget with monetization gate.
///
/// CRITICAL FLOW:
/// 1. User taps card
/// 2. 2-second tension animation plays (shaking + progress)
/// 3. AFTER animation completes, check isPremium
/// 4. Premium: flip card | Free: show paywall
class TarotRevealGateWidget extends ConsumerStatefulWidget {
  /// The front widget (revealed card face).
  final Widget front;

  /// The back widget (face-down card).
  final Widget back;

  /// Card width.
  final double width;

  /// Card height.
  final double height;

  /// Duration of the tension-building phase.
  final Duration tensionDuration;

  /// Callback when card is successfully revealed.
  final VoidCallback? onRevealComplete;

  /// Whether the card has already been revealed (for returning users).
  final bool isRevealed;

  const TarotRevealGateWidget({
    super.key,
    required this.front,
    required this.back,
    this.width = 200,
    this.height = 340,
    this.tensionDuration = const Duration(milliseconds: 2000),
    this.onRevealComplete,
    this.isRevealed = false,
  });

  @override
  ConsumerState<TarotRevealGateWidget> createState() =>
      _TarotRevealGateWidgetState();
}

class _TarotRevealGateWidgetState extends ConsumerState<TarotRevealGateWidget>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _shakeController;
  late AnimationController _glowPulseController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // State
  bool _isCharging = false;
  bool _isRevealed = false;
  bool _showPaywallPrompt = false;
  double _progress = 0;

  // Shake animation values
  double _shakeX = 0;
  double _shakeY = 0;
  double _shakeRotation = 0;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.isRevealed;

    // Progress animation (0 to 100% over tensionDuration)
    _progressController = AnimationController(
      vsync: this,
      duration: widget.tensionDuration,
    )..addListener(_onProgressUpdate);

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onTensionComplete();
      }
    });

    // Shake animation (fast loop)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateShake);

    // Glow pulse for idle state
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Flip animation - ONLY triggered programmatically
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _flipController,
        curve: Curves.easeInOutBack,
      ),
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onRevealComplete?.call();
      }
    });

    // If already revealed, set flip to complete state
    if (_isRevealed) {
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TarotRevealGateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle external reveal state change (e.g., after purchase)
    if (widget.isRevealed && !_isRevealed) {
      setState(() {
        _isRevealed = true;
        _isCharging = false;
        _showPaywallPrompt = false;
      });
      _flipController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _shakeController.dispose();
    _glowPulseController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _onProgressUpdate() {
    setState(() {
      _progress = _progressController.value;
    });

    // Haptic feedback based on progress
    if (_progress > 0) {
      final progressPercent = (_progress * 100).toInt();
      if (progressPercent % 10 == 0) {
        if (_progress < 0.5) {
          HapticFeedback.lightImpact();
        } else if (_progress < 0.8) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
      }
    }
  }

  void _updateShake() {
    if (!_isCharging) return;

    // Intensity increases as progress approaches 100%
    final baseIntensity = 2.0;
    final maxIntensity = 8.0;
    final intensity = baseIntensity + (_progress * (maxIntensity - baseIntensity));

    final random = math.Random();
    setState(() {
      _shakeX = (random.nextDouble() - 0.5) * intensity * 2;
      _shakeY = (random.nextDouble() - 0.5) * intensity;
      _shakeRotation = (random.nextDouble() - 0.5) * 0.05 * _progress;
    });
  }

  void _startTensionBuild() {
    if (_isRevealed || _isCharging) return;

    debugPrint('🎴 Starting tension build...');

    setState(() {
      _isCharging = true;
      _showPaywallPrompt = false;
    });

    HapticFeedback.lightImpact();
    _progressController.forward(from: 0);
    _startShakeLoop();
  }

  void _startShakeLoop() async {
    while (_isCharging && mounted) {
      await _shakeController.forward(from: 0);
      if (!_isCharging || !mounted) break;
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  void _onTensionComplete() {
    debugPrint('🎴 Tension complete! Checking premium status...');

    final isPremium = ref.read(isPremiumProvider);

    debugPrint('🎴 isPremium = $isPremium');

    if (isPremium) {
      debugPrint('🎴 Premium user - revealing card');
      _revealCard();
    } else {
      debugPrint('🎴 Free user - blocking and showing paywall');
      _blockAndShowPaywall();
    }
  }

  void _revealCard() {
    HapticFeedback.heavyImpact();

    setState(() {
      _isCharging = false;
      _isRevealed = true;
      _shakeX = 0;
      _shakeY = 0;
      _shakeRotation = 0;
    });

    // ONLY NOW trigger the flip animation
    _flipController.forward();
  }

  void _blockAndShowPaywall() {
    HapticFeedback.heavyImpact();

    setState(() {
      _isCharging = false;
      _progress = 0;
      _shakeX = 0;
      _shakeY = 0;
      _shakeRotation = 0;
      _showPaywallPrompt = true;
    });

    _progressController.reset();
  }

  void _navigateToPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallView(
          onClose: () {
            Navigator.of(context).pop();
            // Check if user is now premium after returning
            final isPremium = ref.read(isPremiumProvider);
            if (isPremium && mounted) {
              // Auto-reveal for newly premium users
              setState(() {
                _showPaywallPrompt = false;
              });
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _revealCard();
              });
            }
          },
        ),
      ),
    );
  }

  void _onCardTap() {
    debugPrint('🎴 Card tapped! isRevealed=$_isRevealed, isCharging=$_isCharging');

    // Don't allow tap if already revealed or currently charging
    if (_isRevealed) {
      debugPrint('🎴 Already revealed, ignoring tap');
      return;
    }

    if (_isCharging) {
      debugPrint('🎴 Currently charging, ignoring tap');
      return;
    }

    // If paywall prompt is showing, navigate to paywall
    if (_showPaywallPrompt) {
      debugPrint('🎴 Paywall prompt showing, navigating to paywall');
      _navigateToPaywall();
      return;
    }

    // CRITICAL: Start the tension build animation
    // Premium check happens ONLY after the 2-second animation completes
    debugPrint('🎴 Starting tension build animation');
    _startTensionBuild();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onCardTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The card with shake transform - WRAPPED IN ABSORBPOINTER
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(_shakeX, _shakeY, 0.0)
              ..rotateZ(_shakeRotation),
            child: AbsorbPointer(
              // CRITICAL: Prevent the card from receiving any touch events
              absorbing: true,
              child: _buildFlipCard(),
            ),
          ),

          // Progress overlay (during charging)
          if (_isCharging) _buildProgressOverlay(),

          // Paywall prompt overlay
          if (_showPaywallPrompt) _buildPaywallPrompt(),
        ],
      ),
    );
  }

  Widget _buildFlipCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowPulseController, _flipAnimation]),
      builder: (context, child) {
        final glowIntensity = _isCharging
            ? 0.5 + (_progress * 0.5)
            : (_isRevealed ? 0.3 : _glowPulseController.value * 0.3);

        // Calculate flip rotation
        final flipAngle = _flipAnimation.value * math.pi;
        final showBack = flipAngle <= math.pi / 2;

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!_isRevealed && !_isCharging)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2 + glowIntensity * 0.3),
                  blurRadius: 20 + glowIntensity * 15,
                  spreadRadius: 2 + glowIntensity * 3,
                ),
              if (_isCharging)
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3 + _progress * 0.4),
                  blurRadius: 30 + _progress * 30,
                  spreadRadius: 5 + _progress * 10,
                ),
            ],
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..rotateY(flipAngle),
            child: showBack
                ? widget.back
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.front,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildProgressOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular progress with glow
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow behind
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.5 * _progress),
                            blurRadius: 30,
                            spreadRadius: 10 * _progress,
                          ),
                        ],
                      ),
                    ),
                    // Progress indicator
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 4,
                        backgroundColor: AppColors.glassBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.lerp(
                            AppColors.primary,
                            AppColors.secondary,
                            _progress,
                          )!,
                        ),
                      ),
                    ),
                    // Percentage text
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: AppTypography.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Mystical text
                Text(
                  _getChargingText(),
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getChargingText() {
    if (_progress < 0.3) return 'Awakening the card...';
    if (_progress < 0.6) return 'Channeling energy...';
    if (_progress < 0.9) return 'The spirits stir...';
    return 'Destiny awaits...';
  }

  Widget _buildPaywallPrompt() {
    const goldAccent = Color(0xFFFFD700);
    const goldDark = Color(0xFFB8860B);

    return Positioned.fill(
      child: GestureDetector(
        onTap: _navigateToPaywall,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon with glow
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: goldAccent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
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
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mystical text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'The cards vibrate\nwith energy...',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Unlock button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1025),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: goldAccent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goldAccent.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [goldAccent, goldDark],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [goldAccent, goldDark],
                      ).createShader(bounds),
                      child: Text(
                        'Reveal Destiny',
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// =============================================================================
// COMPACT VERSION FOR GRID/SPREAD LAYOUTS
// =============================================================================

/// A simpler version for multiple cards on a table layout.
/// Use this in grid/spread views where cards are smaller.
class TarotCardRevealGate extends ConsumerStatefulWidget {
  /// Index of this card in the spread.
  final int cardIndex;

  /// The card back widget.
  final Widget cardBack;

  /// The card front widget.
  final Widget cardFront;

  /// Card dimensions.
  final double width;
  final double height;

  /// Tension duration before reveal/block.
  final Duration tensionDuration;

  /// Whether already revealed.
  final bool isRevealed;

  /// Callback when reveal completes.
  final void Function(int index)? onRevealComplete;

  const TarotCardRevealGate({
    super.key,
    required this.cardIndex,
    required this.cardBack,
    required this.cardFront,
    this.width = 60,
    this.height = 100,
    this.tensionDuration = const Duration(milliseconds: 2000),
    this.isRevealed = false,
    this.onRevealComplete,
  });

  @override
  ConsumerState<TarotCardRevealGate> createState() => _TarotCardRevealGateState();
}

class _TarotCardRevealGateState extends ConsumerState<TarotCardRevealGate>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _shakeController;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  bool _isCharging = false;
  bool _isRevealed = false;
  bool _showPaywall = false;
  double _progress = 0;
  double _shakeX = 0;
  double _shakeY = 0;

  @override
  void initState() {
    super.initState();
    _isRevealed = widget.isRevealed;

    _progressController = AnimationController(
      vsync: this,
      duration: widget.tensionDuration,
    )..addListener(() {
        setState(() => _progress = _progressController.value);
        // Haptics every 20%
        final percent = (_progress * 100).toInt();
        if (percent % 20 == 0 && percent > 0) {
          HapticFeedback.lightImpact();
        }
      });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onComplete();
      }
    });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 40),
    )..addListener(_updateShake);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    if (_isRevealed) {
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TarotCardRevealGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !_isRevealed) {
      setState(() => _isRevealed = true);
      _flipController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _shakeController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _updateShake() {
    if (!_isCharging) return;
    final intensity = 1.5 + (_progress * 3);
    final random = math.Random();
    setState(() {
      _shakeX = (random.nextDouble() - 0.5) * intensity * 2;
      _shakeY = (random.nextDouble() - 0.5) * intensity;
    });
  }

  void _onTap() {
    debugPrint('🎴 [${widget.cardIndex}] Card tapped!');

    if (_isRevealed || _isCharging) {
      debugPrint('🎴 [${widget.cardIndex}] Ignoring - revealed=$_isRevealed, charging=$_isCharging');
      return;
    }

    if (_showPaywall) {
      _navigateToPaywall();
      return;
    }

    // Start tension build - NO early premium check
    debugPrint('🎴 [${widget.cardIndex}] Starting tension build...');
    setState(() => _isCharging = true);
    HapticFeedback.lightImpact();
    _progressController.forward(from: 0);
    _startShakeLoop();
  }

  void _startShakeLoop() async {
    while (_isCharging && mounted) {
      await _shakeController.forward(from: 0);
      if (!mounted || !_isCharging) break;
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  void _onComplete() {
    debugPrint('🎴 [${widget.cardIndex}] Tension complete! Checking premium...');

    final isPremium = ref.read(isPremiumProvider);

    debugPrint('🎴 [${widget.cardIndex}] isPremium = $isPremium');

    if (isPremium) {
      debugPrint('🎴 [${widget.cardIndex}] Premium - revealing!');
      HapticFeedback.heavyImpact();
      setState(() {
        _isCharging = false;
        _isRevealed = true;
        _shakeX = 0;
        _shakeY = 0;
      });
      _flipController.forward();
      widget.onRevealComplete?.call(widget.cardIndex);
    } else {
      debugPrint('🎴 [${widget.cardIndex}] Free user - blocking!');
      HapticFeedback.heavyImpact();
      _progressController.reset();
      setState(() {
        _isCharging = false;
        _progress = 0;
        _shakeX = 0;
        _shakeY = 0;
        _showPaywall = true;
      });
    }
  }

  void _navigateToPaywall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallView(
          onClose: () {
            Navigator.of(context).pop();
            // Auto-reveal if now premium
            final isPremium = ref.read(isPremiumProvider);
            if (isPremium && mounted) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {
                    _isRevealed = true;
                    _showPaywall = false;
                  });
                  _flipController.forward();
                  widget.onRevealComplete?.call(widget.cardIndex);
                }
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFFFD700);

    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: Offset(_shakeX, _shakeY),
        child: Stack(
          children: [
            // Card with flip - ABSORBED
            AbsorbPointer(
              absorbing: true,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final flipAngle = _flipAnimation.value * math.pi;
                    final showBack = flipAngle <= math.pi / 2;

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(flipAngle),
                      child: showBack
                          ? widget.cardBack
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: widget.cardFront,
                            ),
                    );
                  },
                ),
              ),
            ),

            // Progress overlay
            if (_isCharging)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: widget.width * 0.5,
                        height: widget.width * 0.5,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.lerp(AppColors.primary, AppColors.secondary, _progress)!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Paywall overlay
            if (_showPaywall)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withValues(alpha: 0.8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: widget.width * 0.4,
                        color: goldAccent,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock',
                        style: TextStyle(
                          color: goldAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
