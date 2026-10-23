import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';

/// Material theme wired to Vocle redesign tokens (Cursor brief Step 1).
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.tealPrimary,
      onPrimary: AppColors.textOnDark,
      primaryContainer: AppColors.tealTint,
      onPrimaryContainer: AppColors.navyPrimary,
      secondary: AppColors.navyPrimary,
      onSecondary: AppColors.textOnDark,
      secondaryContainer: AppColors.navySecondary,
      onSecondaryContainer: AppColors.textOnDark,
      tertiary: AppColors.statusPending,
      onTertiary: AppColors.textOnDark,
      error: AppColors.emergencyRed,
      onError: AppColors.textOnDark,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderDefault,
      outlineVariant: AppColors.borderLight,
      shadow: AppColors.shadow,
      surfaceContainerHighest: AppColors.surfaceInput,
      surfaceContainerHigh: AppColors.surfaceCard,
      surfaceContainer: AppColors.backgroundApp,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundApp,
      fontFamily: 'Roboto',
      textTheme: AppTextStyles.textTheme,
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: AppDesignSystem.iconMd,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppDesignSystem.appBarHeight,
        backgroundColor: AppColors.surfaceCard,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.screenTitle,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: AppDesignSystem.iconMd,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: AppDesignSystem.iconMd,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: AppSpacing.minTouchTarget + 8,
        backgroundColor: AppColors.navyPrimary,
        indicatorColor: AppColors.tealPrimary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.caption.copyWith(
              color: AppColors.tealPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 9,
            );
          }
          return AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.tealPrimary,
              size: AppDesignSystem.iconMd,
            );
          }
          return IconThemeData(
            color: Colors.white.withValues(alpha: 0.35),
            size: AppDesignSystem.iconMd,
          );
        }),
      ),
      bottomAppBarTheme: const BottomAppBarTheme(
        elevation: 0,
        color: AppColors.navyPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: AppColors.borderDefault, width: 0.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGaps.cardH,
          vertical: AppSpacing.xs,
        ),
        minVerticalPadding: AppSpacing.xs,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.cardTitle,
        subtitleTextStyle: AppTextStyles.caption,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 0.5,
        space: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGaps.cardH,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(
            color: AppColors.tealPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: const BorderSide(color: AppColors.emergencyRed),
        ),
        labelStyle: AppTextStyles.body,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: AppColors.textOnDark,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppGaps.screenH,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textOnDark,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: AppColors.textOnDark,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppGaps.screenH,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textOnDark,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          side: const BorderSide(color: AppColors.borderDefault),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppGaps.screenH,
            vertical: AppSpacing.sm,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.tealDark,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.tealPrimary,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceCard,
        selectedColor: AppColors.navyPrimary,
        labelStyle: AppTextStyles.badge,
        secondaryLabelStyle: AppTextStyles.badge.copyWith(
          color: AppColors.textOnDark,
        ),
        side: const BorderSide(color: AppColors.borderDefault, width: 0.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(AppColors.surfaceCard),
        side: WidgetStateProperty.all(
          const BorderSide(color: AppColors.borderDefault, width: 0.5),
        ),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(borderRadius: AppRadius.card),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        constraints: const BoxConstraints(
          minHeight: AppDesignSystem.searchBarHeight,
        ),
        textStyle: WidgetStateProperty.all(AppTextStyles.bodyLarge),
        hintStyle: WidgetStateProperty.all(
          AppTextStyles.body.copyWith(color: AppColors.textMuted),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.button,
          side: BorderSide(color: AppColors.borderDefault, width: 0.5),
        ),
        backgroundColor: AppColors.navyPrimary,
        contentTextStyle: AppTextStyles.body.copyWith(
          color: AppColors.textOnDark,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.tealPrimary,
        linearTrackColor: AppColors.borderLight,
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: AppColors.borderDefault, width: 0.5),
        ),
        titleTextStyle: AppTextStyles.screenTitle,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
    );
  }

  // ── Dark (navy/teal clinical, not purple) ───────────────────────────────
  static const Color _darkBg = Color(0xFF0A1428);
  static const Color _darkSurface = Color(0xFF111F3D);
  static const Color _darkSurfaceHigh = Color(0xFF162952);
  static const Color _darkBorder = Color(0xFF24365C);
  static const Color _darkText = Color(0xFFE8EEF8);
  static const Color _darkTextSecondary = Color(0xFFA8B4CC);
  static const Color _darkTextMuted = Color(0xFF7A89A5);

  /// Dark clinical theme: inverted navy surfaces with the Vocle teal accent.
  ///
  /// NOTE: many widgets still read the `const` [AppColors] light tokens
  /// directly, so those surfaces stay light until they are migrated to
  /// `Theme.of(context)` / a ThemeExtension.
  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.tealPrimary,
      onPrimary: AppColors.navyPrimary,
      primaryContainer: _darkSurfaceHigh,
      onPrimaryContainer: AppColors.tealPrimary,
      secondary: AppColors.tealDark,
      onSecondary: AppColors.navyPrimary,
      secondaryContainer: _darkSurfaceHigh,
      onSecondaryContainer: _darkText,
      tertiary: AppColors.statusPending,
      onTertiary: AppColors.navyPrimary,
      error: Color(0xFFF87171),
      onError: AppColors.navyPrimary,
      surface: _darkSurface,
      onSurface: _darkText,
      onSurfaceVariant: _darkTextSecondary,
      outline: _darkBorder,
      outlineVariant: _darkBorder,
      shadow: Colors.black,
      surfaceContainerHighest: _darkSurfaceHigh,
      surfaceContainerHigh: _darkSurfaceHigh,
      surfaceContainer: _darkSurface,
    );

    final textTheme = AppTextStyles.textTheme.apply(
      bodyColor: _darkText,
      displayColor: _darkText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBg,
      canvasColor: _darkBg,
      fontFamily: 'Roboto',
      textTheme: textTheme,
      iconTheme: const IconThemeData(
        color: _darkTextSecondary,
        size: AppDesignSystem.iconMd,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppDesignSystem.appBarHeight,
        backgroundColor: _darkSurface,
        foregroundColor: _darkText,
        titleTextStyle: AppTextStyles.screenTitle.copyWith(color: _darkText),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(
          color: _darkTextSecondary,
          size: AppDesignSystem.iconMd,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: AppSpacing.minTouchTarget + 8,
        backgroundColor: AppColors.navyPrimary,
        indicatorColor: AppColors.tealPrimary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: _darkBorder, width: 0.5),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _darkTextSecondary,
        textColor: _darkText,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGaps.cardH,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: _darkBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: _darkBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: AppColors.tealPrimary, width: 1.5),
        ),
        labelStyle: AppTextStyles.body.copyWith(color: _darkTextSecondary),
        hintStyle: AppTextStyles.body.copyWith(color: _darkTextMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tealPrimary,
          foregroundColor: AppColors.navyPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tealPrimary,
          foregroundColor: AppColors.navyPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkText,
          side: const BorderSide(color: _darkBorder),
          minimumSize: const Size(0, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.tealPrimary,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.tealPrimary,
        foregroundColor: AppColors.navyPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurface,
        selectedColor: _darkSurfaceHigh,
        labelStyle: AppTextStyles.badge.copyWith(color: _darkText),
        side: const BorderSide(color: _darkBorder, width: 0.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        backgroundColor: _darkSurfaceHigh,
        contentTextStyle: AppTextStyles.body.copyWith(color: _darkText),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.tealPrimary,
        linearTrackColor: _darkBorder,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: _darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: _darkBorder, width: 0.5),
        ),
        titleTextStyle: AppTextStyles.screenTitle.copyWith(color: _darkText),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
    );
  }

  /// Light theme with a selectable accent palette (nav / FAB / primary actions).
  static ThemeData lightFor(ThemePalette palette) {
    final base = light;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: palette.primary,
        primaryContainer: palette.primary.withValues(alpha: 0.14),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: palette.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: AppColors.borderLight,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: palette.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.caption.copyWith(
              color: palette.primary,
              fontWeight: FontWeight.w500,
              fontSize: 9,
            );
          }
          return AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9,
          );
        }),
      ),
    );
  }

  /// Dark theme with the same accent remap.
  static ThemeData darkFor(ThemePalette palette) {
    final base = dark;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: palette.primary,
        primaryContainer: palette.primary.withValues(alpha: 0.22),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: palette.primary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: _darkBorder,
      ),
    );
  }
}
