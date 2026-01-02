import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/astrology_profile_model.dart';
import 'zodiac_wheel_painter.dart';

/// A mystical animated zodiac wheel widget.
/// Used for the dramatic "calculation" reveal during onboarding.
class ZodiacWheel extends StatefulWidget {
  /// Size of the wheel
  final double size;

  /// Whether the wheel is spinning
  final bool isSpinning;

  /// Spin speed multiplier (1.0 = normal)
  final double spinSpeed;

  /// Highlighted zodiac sign (shown after reveal)
  final ZodiacSign? highlightedSign;

  /// Whether to enable haptic feedback during spin
  final bool enableHaptics;

  /// Called when the spin animation completes
  final VoidCallback? onSpinComplete;

  /// Duration of the spin animation
  final Duration spinDuration;

  const ZodiacWheel({
    super.key,
    this.size = 300,
    this.isSpinning = false,
    this.spinSpeed = 1.0,
    this.highlightedSign,
    this.enableHaptics = true,
    this.onSpinComplete,
    this.spinDuration = const Duration(seconds: 4),
  });

  @override
  State<ZodiacWheel> createState() => _ZodiacWheelState();
}

class _ZodiacWheelState extends State<ZodiacWheel>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _glowController;
  late AnimationController _revealController;

  late Animation<double> _spinAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _revealAnimation;

  bool _wasSpinning = false;
  int _hapticCounter = 0;

  @override
  void initState() {
    super.initState();

    // Spin animation controller
    _spinController = AnimationController(
      vsync: this,
      duration: widget.spinDuration,
    );

    // Create a custom curve that starts fast and slows down
    _spinAnimation = Tween<double>(
      begin: 0,
      end: 8 * pi * widget.spinSpeed, // Multiple full rotations
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutExpo,
    ));

    _spinController.addListener(_onSpinUpdate);
    _spinController.addStatusListener(_onSpinStatusChange);

    // Glow animation controller (continuous)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Reveal animation controller
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _revealAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    ));

    // Start reveal animation
    _revealController.forward();

    // Start spinning if initially spinning
    if (widget.isSpinning) {
      _wasSpinning = true;
      _startSpinning();
    }
  }

  @override
  void didUpdateWidget(ZodiacWheel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle spinning state changes
    if (widget.isSpinning && !_wasSpinning) {
      _startSpinning();
    } else if (!widget.isSpinning && _wasSpinning) {
      _stopSpinning();
    }

    _wasSpinning = widget.isSpinning;
  }

  void _startSpinning() {
    _hapticCounter = 0;
    _spinController.forward(from: 0);
  }

  void _stopSpinning() {
    // Let it finish naturally
  }

  void _onSpinUpdate() {
    if (!widget.enableHaptics || !widget.isSpinning) return;

    // Calculate haptic frequency based on spin speed
    final progress = _spinController.value;
    final speed = 1.0 - progress; // Faster at start, slower at end

    // Trigger haptics at varying intervals
    final threshold = (10 + (progress * 30)).toInt();
    _hapticCounter++;

    if (_hapticCounter >= threshold) {
      _hapticCounter = 0;

      // Intensity based on speed
      if (speed > 0.7) {
        HapticFeedback.heavyImpact();
      } else if (speed > 0.3) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _onSpinStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Final haptic burst
      if (widget.enableHaptics) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.mediumImpact();
        });
      }

      widget.onSpinComplete?.call();
    }
  }

  @override
  void dispose() {
    _spinController.removeListener(_onSpinUpdate);
    _spinController.removeStatusListener(_onSpinStatusChange);
    _spinController.dispose();
    _glowController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _spinAnimation,
        _glowAnimation,
        _revealAnimation,
      ]),
      builder: (context, child) {
        // Calculate glow intensity - increases during spin
        double glowIntensity = _glowAnimation.value;
        if (widget.isSpinning) {
          final spinProgress = _spinController.value;
          glowIntensity = 0.5 + (1.0 - spinProgress) * 0.5; // Brighter during fast spin
        }

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: ZodiacWheelPainter(
              rotation: _spinAnimation.value,
              glowIntensity: glowIntensity,
              showSymbols: true,
              highlightedSign: widget.isSpinning ? null : widget.highlightedSign,
              revealProgress: _revealAnimation.value,
            ),
            size: Size(widget.size, widget.size),
          ),
        );
      },
    );
  }
}

/// A simplified zodiac wheel that just displays statically
class ZodiacWheelStatic extends StatelessWidget {
  final double size;
  final ZodiacSign? highlightedSign;
  final double glowIntensity;

  const ZodiacWheelStatic({
    super.key,
    this.size = 200,
    this.highlightedSign,
    this.glowIntensity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ZodiacWheelPainter(
          rotation: 0,
          glowIntensity: glowIntensity,
          showSymbols: true,
          highlightedSign: highlightedSign,
          revealProgress: 1.0,
        ),
        size: Size(size, size),
      ),
    );
  }
}
