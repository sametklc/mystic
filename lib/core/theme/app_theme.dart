import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/constants.dart';

/// Mystic App Theme
/// A deeply customized Material 3 dark theme for a mystical, spiritual experience.
class AppTheme {
  AppTheme._();

  /// The main dark theme for the Mystic app
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ═══════════════════════════════════════════════════════════════════════
      // COLOR SCHEME
      // ═══════════════════════════════════════════════════════════════════════
      colorScheme: const ColorScheme.dark(
        // Primary - Neon Gold
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primarySurface,
        onPrimaryContainer: AppColors.primary,

        // Secondary - Electric Purple
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimary,
        secondaryContainer: AppColors.secondarySurface,
        onSecondaryContainer: AppColors.secondary,

        // Tertiary - Mystic Teal
        tertiary: AppColors.mysticTeal,
        onTertiary: AppColors.textOnPrimary,

        // Error
        error: AppColors.error,
        onError: AppColors.textPrimary,

        // Background & Surface
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,

        // Outline
        outline: AppColors.glassBorder,
        outlineVariant: AppColors.cosmicDust,

        // Inverse (for snackbars, etc.)
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.background,
        inversePrimary: AppColors.primaryDark,

        // Shadow
        shadow: Colors.black,
        scrim: Colors.black,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // SCAFFOLD & BACKGROUNDS
      // ═══════════════════════════════════════════════════════════════════════
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,

      // ═══════════════════════════════════════════════════════════════════════
      // TYPOGRAPHY
      // ═══════════════════════════════════════════════════════════════════════
      textTheme: AppTypography.textTheme,
      primaryTextTheme: AppTypography.textTheme,

      // ═══════════════════════════════════════════════════════════════════════
      // APP BAR
      // ═══════════════════════════════════════════════════════════════════════
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: AppTypography.headlineMedium,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: 24,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // ELEVATED BUTTON
      // ═══════════════════════════════════════════════════════════════════════
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.primaryDark.withOpacity(0.3),
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          shadowColor: AppColors.primaryGlow,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLarge,
            vertical: AppConstants.spacingMedium,
          ),
          minimumSize: const Size(120, AppConstants.buttonHeightMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
          textStyle: AppTypography.button,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // OUTLINED BUTTON
      // ═══════════════════════════════════════════════════════════════════════
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          side: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLarge,
            vertical: AppConstants.spacingMedium,
          ),
          minimumSize: const Size(120, AppConstants.buttonHeightMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          ),
          textStyle: AppTypography.button.copyWith(color: AppColors.primary),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // TEXT BUTTON
      // ═══════════════════════════════════════════════════════════════════════
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMedium,
            vertical: AppConstants.spacingSmall,
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // ICON BUTTON
      // ═══════════════════════════════════════════════════════════════════════
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          highlightColor: AppColors.primarySurface,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // FLOATING ACTION BUTTON
      // ═══════════════════════════════════════════════════════════════════════
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 8,
        highlightElevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // CARD
      // ═══════════════════════════════════════════════════════════════════════
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          side: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(AppConstants.spacingSmall),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // INPUT DECORATION
      // ═══════════════════════════════════════════════════════════════════════
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMedium,
          vertical: AppConstants.spacingMedium,
        ),
        hintStyle: AppTypography.hint,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        errorStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.error,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // BOTTOM NAVIGATION BAR
      // ═══════════════════════════════════════════════════════════════════════
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // NAVIGATION BAR (Material 3)
      // ═══════════════════════════════════════════════════════════════════════
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.backgroundSecondary.withOpacity(0.95),
        indicatorColor: AppColors.primarySurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textTertiary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(color: AppColors.primary);
          }
          return AppTypography.labelSmall.copyWith(color: AppColors.textTertiary);
        }),
        elevation: 0,
        height: 70,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // BOTTOM SHEET
      // ═══════════════════════════════════════════════════════════════════════
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        modalBackgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.borderRadiusXLarge),
          ),
        ),
        dragHandleColor: AppColors.textTertiary,
        dragHandleSize: Size(40, 4),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // DIALOG
      // ═══════════════════════════════════════════════════════════════════════
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
          side: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        titleTextStyle: AppTypography.headlineMedium,
        contentTextStyle: AppTypography.bodyMedium,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // SNACK BAR
      // ═══════════════════════════════════════════════════════════════════════
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.backgroundTertiary,
        contentTextStyle: AppTypography.bodyMedium,
        actionTextColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // CHIP
      // ═══════════════════════════════════════════════════════════════════════
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        selectedColor: AppColors.primarySurface,
        disabledColor: AppColors.backgroundTertiary,
        labelStyle: AppTypography.labelMedium,
        secondaryLabelStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingSmall,
          vertical: AppConstants.spacingXSmall,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusRound),
          side: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // DIVIDER
      // ═══════════════════════════════════════════════════════════════════════
      dividerTheme: const DividerThemeData(
        color: AppColors.glassBorder,
        thickness: 1,
        space: AppConstants.spacingMedium,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // PROGRESS INDICATOR
      // ═══════════════════════════════════════════════════════════════════════
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.backgroundTertiary,
        circularTrackColor: AppColors.backgroundTertiary,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // SLIDER
      // ═══════════════════════════════════════════════════════════════════════
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.backgroundTertiary,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primaryGlow,
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: AppTypography.labelMedium.copyWith(
          color: AppColors.textOnPrimary,
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // SWITCH
      // ═══════════════════════════════════════════════════════════════════════
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primarySurface;
          }
          return AppColors.backgroundTertiary;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // CHECKBOX
      // ═══════════════════════════════════════════════════════════════════════
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
        side: const BorderSide(
          color: AppColors.textSecondary,
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // RADIO
      // ═══════════════════════════════════════════════════════════════════════
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textSecondary;
        }),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // TOOLTIP
      // ═══════════════════════════════════════════════════════════════════════
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(color: AppColors.glassBorder),
        ),
        textStyle: AppTypography.bodySmall,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // POPUP MENU
      // ═══════════════════════════════════════════════════════════════════════
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.backgroundSecondary,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          side: const BorderSide(
            color: AppColors.glassBorder,
            width: 1,
          ),
        ),
        textStyle: AppTypography.bodyMedium,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // DRAWER
      // ═══════════════════════════════════════════════════════════════════════
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        scrimColor: Colors.black54,
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // LIST TILE
      // ═══════════════════════════════════════════════════════════════════════
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.primarySurface,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.bodyLarge,
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMedium,
          vertical: AppConstants.spacingSmall,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // TAB BAR
      // ═══════════════════════════════════════════════════════════════════════
      tabBarTheme: TabBarThemeData(
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTypography.labelLarge,
        unselectedLabelStyle: AppTypography.labelLarge,
        overlayColor: WidgetStateProperty.all(AppColors.primarySurface),
      ),

      // ═══════════════════════════════════════════════════════════════════════
      // EXTENSIONS
      // ═══════════════════════════════════════════════════════════════════════
      extensions: const <ThemeExtension<dynamic>>[
        MysticThemeExtension(
          neonGold: AppColors.primary,
          electricPurple: AppColors.secondary,
          voidBlack: AppColors.background,
          mysticTeal: AppColors.mysticTeal,
          starWhite: AppColors.starWhite,
          glowColor: AppColors.primaryGlow,
        ),
      ],
    );
  }
}

/// Custom theme extension for Mystic-specific colors and effects
class MysticThemeExtension extends ThemeExtension<MysticThemeExtension> {
  final Color neonGold;
  final Color electricPurple;
  final Color voidBlack;
  final Color mysticTeal;
  final Color starWhite;
  final Color glowColor;

  const MysticThemeExtension({
    required this.neonGold,
    required this.electricPurple,
    required this.voidBlack,
    required this.mysticTeal,
    required this.starWhite,
    required this.glowColor,
  });

  @override
  MysticThemeExtension copyWith({
    Color? neonGold,
    Color? electricPurple,
    Color? voidBlack,
    Color? mysticTeal,
    Color? starWhite,
    Color? glowColor,
  }) {
    return MysticThemeExtension(
      neonGold: neonGold ?? this.neonGold,
      electricPurple: electricPurple ?? this.electricPurple,
      voidBlack: voidBlack ?? this.voidBlack,
      mysticTeal: mysticTeal ?? this.mysticTeal,
      starWhite: starWhite ?? this.starWhite,
      glowColor: glowColor ?? this.glowColor,
    );
  }

  @override
  MysticThemeExtension lerp(ThemeExtension<MysticThemeExtension>? other, double t) {
    if (other is! MysticThemeExtension) {
      return this;
    }
    return MysticThemeExtension(
      neonGold: Color.lerp(neonGold, other.neonGold, t)!,
      electricPurple: Color.lerp(electricPurple, other.electricPurple, t)!,
      voidBlack: Color.lerp(voidBlack, other.voidBlack, t)!,
      mysticTeal: Color.lerp(mysticTeal, other.mysticTeal, t)!,
      starWhite: Color.lerp(starWhite, other.starWhite, t)!,
      glowColor: Color.lerp(glowColor, other.glowColor, t)!,
    );
  }
}

/// Extension to easily access MysticThemeExtension
extension MysticThemeExtensionAccess on ThemeData {
  MysticThemeExtension get mystic => extension<MysticThemeExtension>()!;
}
