import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Mystic App Typography
/// Cinzel for mystical headlines, Lato for clean body text.
abstract class AppTypography {
  // ═══════════════════════════════════════════════════════════════════════════
  // BASE TEXT STYLES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cinzel - Mystical, ancient feel for headlines
  static TextStyle get _cinzelBase => GoogleFonts.cinzel(
        color: AppColors.textPrimary,
        letterSpacing: 1.2,
      );

  /// Lato - Clean, modern for body text
  static TextStyle get _latoBase => GoogleFonts.lato(
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      );

  /// Montserrat - Alternative body font
  static TextStyle get _montserratBase => GoogleFonts.montserrat(
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPLAY STYLES (Cinzel - Mystical Headers)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Display Large - App title, splash screens
  static TextStyle get displayLarge => _cinzelBase.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        height: 1.2,
        letterSpacing: 3.0,
      );

  /// Display Medium - Section titles
  static TextStyle get displayMedium => _cinzelBase.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        height: 1.25,
        letterSpacing: 2.5,
      );

  /// Display Small - Card titles
  static TextStyle get displaySmall => _cinzelBase.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 2.0,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADLINE STYLES (Cinzel)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Headline Large
  static TextStyle get headlineLarge => _cinzelBase.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: 1.5,
      );

  /// Headline Medium
  static TextStyle get headlineMedium => _cinzelBase.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.2,
      );

  /// Headline Small
  static TextStyle get headlineSmall => _cinzelBase.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 1.0,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // TITLE STYLES (Lato)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Title Large
  static TextStyle get titleLarge => _latoBase.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  /// Title Medium
  static TextStyle get titleMedium => _latoBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.45,
      );

  /// Title Small
  static TextStyle get titleSmall => _latoBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.45,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // BODY STYLES (Lato)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Body Large
  static TextStyle get bodyLarge => _latoBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.6,
      );

  /// Body Medium
  static TextStyle get bodyMedium => _latoBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.55,
      );

  /// Body Small
  static TextStyle get bodySmall => _latoBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        height: 1.5,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // LABEL STYLES (Lato)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Label Large - Buttons
  static TextStyle get labelLarge => _latoBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.8,
      );

  /// Label Medium - Small buttons, chips
  static TextStyle get labelMedium => _latoBase.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.6,
      );

  /// Label Small - Captions, hints
  static TextStyle get labelSmall => _latoBase.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIAL STYLES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mystical quote style
  static TextStyle get mysticalQuote => _cinzelBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.8,
        letterSpacing: 1.0,
        color: AppColors.textSecondary,
      );

  /// Card name (Tarot cards)
  static TextStyle get cardName => _cinzelBase.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        color: AppColors.primary,
      );

  /// Glowing text style (base - apply shader/glow separately)
  static TextStyle get glowingText => _cinzelBase.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        color: AppColors.primary,
      );

  /// Button text
  static TextStyle get button => _latoBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: AppColors.textOnPrimary,
      );

  /// Input text
  static TextStyle get input => _latoBase.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  /// Hint text
  static TextStyle get hint => _latoBase.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textTertiary,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT THEME (For Material Theme)
  // ═══════════════════════════════════════════════════════════════════════════

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
