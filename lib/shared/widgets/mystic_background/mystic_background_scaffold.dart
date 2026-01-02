import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_colors.dart';
import 'cosmic_painter.dart';
import 'cosmic_particle.dart';

/// A reusable wrapper widget that provides an atmospheric, cosmic background
/// for the entire Mystic app. Features:
/// - Deep radial gradient background
/// - Animated floating star/dust particles
/// - Optional noise texture overlay
/// - High-performance 60fps animation
///
/// Usage:
/// ```dart
/// MysticBackgroundScaffold(
///   child: YourPageContent(),
/// )
/// ```
class MysticBackgroundScaffold extends StatefulWidget {
  /// The content to display on top of the background
  final Widget child;

  /// Number of particles to render (default: 80)
  /// Lower for better performance on low-end devices
  final int particleCount;

  /// Whether to show the noise texture overlay
  final bool showNoise;

  /// Opacity of the noise overlay (0.0 - 1.0)
  final double noiseOpacity;

  /// Whether to enable glow effects on stars
  final bool enableGlow;

  /// Custom gradient colors (optional)
  final List<Color>? gradientColors;

  /// Custom gradient stops (optional)
  final List<double>? gradientStops;

  /// Center point of the radial gradient (0.0-1.0 for x and y)
  final Offset gradientCenter;

  /// Whether to show the animated particles
  final bool showParticles;

  /// Animation speed multiplier (1.0 = normal)
  final double animationSpeed;

  const MysticBackgroundScaffold({
    super.key,
    required this.child,
    this.particleCount = 80,
    this.showNoise = true,
    this.noiseOpacity = 0.02,
    this.enableGlow = true,
    this.gradientColors,
    this.gradientStops,
    this.gradientCenter = const Offset(0.5, 0.3),
    this.showParticles = true,
    this.animationSpeed = 1.0,
  });

  @override
  State<MysticBackgroundScaffold> createState() =>
      _MysticBackgroundScaffoldState();
}

class _MysticBackgroundScaffoldState extends State<MysticBackgroundScaffold>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0;
  List<CosmicParticle> _particles = [];
  Size _lastSize = Size.zero;
  bool _isInitialized = false;

  // Default particle colors matching our theme
  static const List<Color> _defaultParticleColors = [
    AppColors.starWhite,
    AppColors.primary,
    AppColors.primaryLight,
    AppColors.secondary,
    AppColors.secondaryLight,
    AppColors.mysticTeal,
  ];

  // Default gradient colors
  static const List<Color> _defaultGradientColors = [
    Color(0xFF1A0A2E), // Deep purple center
    Color(0xFF0D0620), // Mid purple
    Color(0xFF050511), // Void black
    Color(0xFF030308), // Deep void
  ];

  static const List<double> _defaultGradientStops = [0.0, 0.3, 0.7, 1.0];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _time = elapsed.inMilliseconds / 1000.0 * widget.animationSpeed;

      // Update particle positions
      if (_isInitialized && widget.showParticles) {
        for (final particle in _particles) {
          particle.update(_time, _lastSize);
        }
      }
    });
  }

  void _initializeParticles(Size size) {
    if (size == Size.zero) return;

    final random = Random(42); // Seeded for consistent layout
    _particles = List.generate(
      widget.particleCount,
      (_) => CosmicParticle.random(
        random: random,
        bounds: size,
        colors: _defaultParticleColors,
      ),
    );

    // Sort by depth for proper layering (far to near)
    _particles.sort((a, b) => a.depth.compareTo(b.depth));

    _lastSize = size;
    _isInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Initialize or reinitialize particles if size changed significantly
        final sizeDiff = (_lastSize.width - size.width).abs() + (_lastSize.height - size.height).abs();
        if (!_isInitialized || sizeDiff > 50) {
          // Schedule initialization after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeParticles(size);
          });
        }

        return Stack(
          children: [
            // Layer 1: Gradient Background (static)
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: GradientBackgroundPainter(
                    colors: widget.gradientColors ?? _defaultGradientColors,
                    stops: widget.gradientStops ?? _defaultGradientStops,
                    center: widget.gradientCenter,
                  ),
                  isComplex: false,
                  willChange: false,
                ),
              ),
            ),

            // Layer 2: Animated Particles
            if (widget.showParticles && _isInitialized)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CosmicPainter(
                      particles: _particles,
                      time: _time,
                      enableGlow: widget.enableGlow,
                    ),
                    isComplex: true,
                    willChange: true,
                  ),
                ),
              ),

            // Layer 3: Noise Texture (static, cached)
            if (widget.showNoise)
              Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: NoisePainter(
                        opacity: widget.noiseOpacity,
                      ),
                      isComplex: false,
                      willChange: false,
                    ),
                  ),
                ),
              ),

            // Layer 4: Vignette Effect
            Positioned.fill(
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.6),
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Layer 5: Child Content (wrapped in Material for TextField, IconButton, etc.)
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A simpler variant for performance-critical pages with fewer particles
class MysticBackgroundScaffoldLite extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;

  const MysticBackgroundScaffoldLite({
    super.key,
    required this.child,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return MysticBackgroundScaffold(
      particleCount: 40,
      showNoise: false,
      enableGlow: false,
      gradientColors: gradientColors,
      child: child,
    );
  }
}

/// Static background variant (no animation) for dialogs and overlays
class MysticBackgroundStatic extends StatelessWidget {
  final Widget child;
  final List<Color>? gradientColors;

  const MysticBackgroundStatic({
    super.key,
    required this.child,
    this.gradientColors,
  });

  static const List<Color> _defaultGradientColors = [
    Color(0xFF1A0A2E),
    Color(0xFF0D0620),
    Color(0xFF050511),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.5,
          colors: gradientColors ?? _defaultGradientColors,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}
