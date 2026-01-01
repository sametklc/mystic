import 'package:flutter/material.dart';

/// Mystic App Color Palette
/// A deep, mystical dark theme with neon accents for a spiritual experience.
abstract class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND COLORS - The Void
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary background - Deep Void Blue/Black
  static const Color background = Color(0xFF050511);

  /// Secondary background - Slightly lighter for cards
  static const Color backgroundSecondary = Color(0xFF0A0A1A);

  /// Tertiary background - For elevated surfaces
  static const Color backgroundTertiary = Color(0xFF12122A);

  /// Surface color for cards and containers
  static const Color surface = Color(0xFF0D0D1F);

  /// Dark purple for gradient endpoints
  static const Color backgroundPurple = Color(0xFF1A0A2E);

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY ACCENT - Neon Gold (Interactive Elements)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary neon gold
  static const Color primary = Color(0xFFFFD700);

  /// Lighter gold for highlights
  static const Color primaryLight = Color(0xFFFFE55C);

  /// Darker gold for pressed states
  static const Color primaryDark = Color(0xFFB8960F);

  /// Gold with opacity for glows
  static const Color primaryGlow = Color(0x40FFD700);

  /// Subtle gold for backgrounds
  static const Color primarySurface = Color(0x1AFFD700);

  // ═══════════════════════════════════════════════════════════════════════════
  // SECONDARY ACCENT - Electric Purple (Magical Auras)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Electric purple - magical auras
  static const Color secondary = Color(0xFF9D00FF);

  /// Lighter purple for highlights
  static const Color secondaryLight = Color(0xFFBB66FF);

  /// Darker purple for pressed states
  static const Color secondaryDark = Color(0xFF7000B8);

  /// Purple glow effect
  static const Color secondaryGlow = Color(0x409D00FF);

  /// Subtle purple for backgrounds
  static const Color secondarySurface = Color(0x1A9D00FF);

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary text - Off-white/Silver
  static const Color textPrimary = Color(0xFFE0E0E0);

  /// Secondary text - Muted silver
  static const Color textSecondary = Color(0xFFA0A0A0);

  /// Tertiary text - Very muted
  static const Color textTertiary = Color(0xFF707070);

  /// Disabled text
  static const Color textDisabled = Color(0xFF505050);

  /// Text on primary colored backgrounds
  static const Color textOnPrimary = Color(0xFF050511);

  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Success - Mystical Emerald
  static const Color success = Color(0xFF00D9A5);

  /// Warning - Amber Flame
  static const Color warning = Color(0xFFFFAA00);

  /// Error - Blood Ruby
  static const Color error = Color(0xFFFF4757);

  /// Info - Celestial Blue
  static const Color info = Color(0xFF00B4D8);

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIAL EFFECTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Glassmorphism border
  static const Color glassBorder = Color(0x30FFFFFF);

  /// Glassmorphism fill
  static const Color glassFill = Color(0x10FFFFFF);

  /// Star/particle color
  static const Color starWhite = Color(0xFFFFFFFF);

  /// Cosmic dust
  static const Color cosmicDust = Color(0xFF3D3D6B);

  /// Mystic teal accent
  static const Color mysticTeal = Color(0xFF00CED1);

  /// Deep indigo
  static const Color deepIndigo = Color(0xFF2E0854);

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      background,
      backgroundPurple,
      background,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Primary button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryLight,
      primary,
      primaryDark,
    ],
  );

  /// Secondary/magical gradient
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      secondaryLight,
      secondary,
      secondaryDark,
    ],
  );

  /// Mystical purple-gold gradient
  static const LinearGradient mysticGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      secondary,
      primary,
    ],
  );

  /// Card/surface gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF15152D),
      Color(0xFF0A0A1A),
    ],
  );

  /// Glow gradient for neon effects
  static const RadialGradient glowGradient = RadialGradient(
    colors: [
      Color(0x60FFD700),
      Color(0x00FFD700),
    ],
  );
}
