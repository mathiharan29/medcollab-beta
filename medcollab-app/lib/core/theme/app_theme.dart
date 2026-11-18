import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/fast_page_transitions.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/theme/theme_mode_cubit.dart';

/// Colours one theme needs. Light and dark differ ONLY here.
class _Tokens {
  const _Tokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.chrome,
    required this.border,
    required this.borderLight,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.action,
    required this.onAction,
    required this.error,
    required this.shadow,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color chrome;
  final Color border;
  final Color borderLight;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color action;
  final Color onAction;
  final Color error;
  final Color shadow;

  static const light = _Tokens(
    brightness: Brightness.light,
    background: AppColorsLight.backgroundApp,
    surface: AppColorsLight.surfaceCard,
    surfaceHigh: AppColorsLight.surfaceInput,
    chrome: AppColorsLight.navyPrimary,
    border: AppColorsLight.borderDefault,
    borderLight: AppColorsLight.borderLight,
    text: AppColorsLight.textPrimary,
    textSecondary: AppColorsLight.textSecondary,
    textMuted: AppColorsLight.textMuted,
    action: AppColorsLight.navyPrimary,
    onAction: AppColorsLight.textOnDark,
    error: AppColorsLight.emergencyRed,
    shadow: AppColorsLight.shadow,
  );

  static const dark = _Tokens(
    brightness: Brightness.dark,
    background: AppColorsDark.backgroundApp,
    surface: AppColorsDark.surfaceCard,
    surfaceHigh: AppColorsDark.surfaceInput,
    chrome: AppColorsDark.chrome,
    border: AppColorsDark.borderDefault,
    borderLight: AppColorsDark.borderLight,
    text: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    textMuted: AppColorsDark.textMuted,
    action: AppColorsLight.tealDark,
    onAction: AppColorsLight.textOnDark,
    error: Color(0xFFF87171),
    shadow: Colors.black,
  );
}

/// Material theme wired to Vocle tokens.
///
/// Light and dark are produced by ONE builder: every size, padding, height
/// and font is identical, only colours change. Previously the dark theme was
/// a separate, partial copy (no ListTile/nav-label/search/chip/button sizes),
/// so switching theme visibly resized text (13→15 px list titles, 9→12 px
/// tab labels) and moved rows.
abstract final class AppTheme {
  static ThemeData get light => _build(_Tokens.light, AppColorsLight.tealPrimary);
  static ThemeData get dark => _build(_Tokens.dark, AppColorsLight.tealPrimary);

  /// Light theme with a selectable accent palette (nav / FAB / primary actions).
  static ThemeData lightFor(ThemePalette palette) =>
      _build(_Tokens.light, palette.primary);

  /// Dark theme with the same accent remap.
  static ThemeData darkFor(ThemePalette palette) =>
      _build(_Tokens.dark, palette.primary);

  /// Text theme with explicit colours for [t] (independent of the global
  /// [AppColors] brightness flag, which may still hold the other theme).
  static TextTheme _textTheme(_Tokens t) {
    TextStyle c(TextStyle s, Color color) => s.copyWith(color: color);
    return TextTheme(
      displayLarge: c(AppTextStyles.displayLarge, t.text),
      displayMedium: c(AppTextStyles.displayMedium, t.text),
      headlineMedium: c(AppTextStyles.headlineMedium, t.text),
      titleLarge: c(AppTextStyles.titleLarge, t.text),
      titleMedium: c(AppTextStyles.titleMedium, t.text),
      titleSmall: c(AppTextStyles.titleSmall, t.text),
      bodyLarge: c(AppTextStyles.bodyLarge, t.text),
      bodyMedium: c(AppTextStyles.bodyMedium, t.textSecondary),
      bodySmall: c(AppTextStyles.bodySmall, t.textMuted),
      labelLarge: c(AppTextStyles.labelLarge, t.text),
      labelMedium: c(AppTextStyles.labelMedium, t.textSecondary),
      labelSmall: c(AppTextStyles.labelSmall, t.textMuted),
    );
  }

  static ThemeData _build(_Tokens t, Color accent) {
    final isDark = t.brightness == Brightness.dark;
    final text = _textTheme(t);
    final navInactive = Colors.white.withValues(alpha: isDark ? 0.45 : 0.35);

    final colorScheme = ColorScheme(
      brightness: t.brightness,
      primary: accent,
      onPrimary: isDark ? AppColorsLight.navyPrimary : AppColorsLight.textOnDark,
      primaryContainer: accent.withValues(alpha: isDark ? 0.22 : 0.14),
      onPrimaryContainer:
          isDark ? AppColorsDark.onPrimaryContainer : AppColorsLight.navyPrimary,
      secondary: isDark ? AppColorsLight.tealDark : AppColorsLight.navyPrimary,
      onSecondary: AppColorsLight.textOnDark,
      secondaryContainer: isDark ? t.surfaceHigh : AppColorsLight.navySecondary,
      onSecondaryContainer: isDark ? t.text : AppColorsLight.textOnDark,
      tertiary: AppColorsLight.statusPending,
      onTertiary: AppColorsLight.textOnDark,
      error: t.error,
      onError: AppColorsLight.textOnDark,
      surface: t.surface,
      onSurface: t.text,
      onSurfaceVariant: t.textSecondary,
      outline: t.border,
      outlineVariant: t.borderLight,
      shadow: t.shadow,
      surfaceContainerHighest: t.surfaceHigh,
      surfaceContainerHigh: t.surface,
      surfaceContainer: t.background,
    );

    final navLabel = WidgetStateProperty.resolveWith<TextStyle>((states) {
      final selected = states.contains(WidgetState.selected);
      return text.bodySmall!.copyWith(
        fontSize: 9,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        color: selected ? accent : navInactive,
      );
    });
    final navIcon = WidgetStateProperty.resolveWith<IconThemeData>((states) {
      return IconThemeData(
        color: states.contains(WidgetState.selected) ? accent : navInactive,
        size: AppDesignSystem.iconMd,
      );
    });

    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppGaps.screenH,
      vertical: AppSpacing.sm,
    );
    final buttonLabel = text.labelLarge!;

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.card,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      fontFamily: 'Roboto',
      textTheme: text,
      // Page changes feel instant (beta feedback: "still so much time to move
      // around"): a 200 ms fade-and-slide instead of the default 300 ms
      // zoom, which also snapshots both pages every frame.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: VocleFastPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: VocleFastPageTransitionsBuilder(),
          TargetPlatform.linux: VocleFastPageTransitionsBuilder(),
          TargetPlatform.fuchsia: VocleFastPageTransitionsBuilder(),
        },
      ),
      // Same density/tap targets in both themes.
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(
        color: t.textSecondary,
        size: AppDesignSystem.iconMd,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: AppDesignSystem.appBarHeight,
        backgroundColor: t.surface,
        foregroundColor: t.text,
        titleTextStyle: text.titleLarge,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: t.textSecondary,
          size: AppDesignSystem.iconMd,
        ),
        actionsIconTheme: IconThemeData(
          color: t.textSecondary,
          size: AppDesignSystem.iconMd,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: AppSpacing.minTouchTarget + 8,
        backgroundColor: t.chrome,
        indicatorColor: accent.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: navLabel,
        iconTheme: navIcon,
      ),
      bottomAppBarTheme: BottomAppBarTheme(
        elevation: 0,
        color: t.chrome,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: t.border, width: 0.5),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGaps.cardH,
          vertical: AppSpacing.xs,
        ),
        minVerticalPadding: AppSpacing.xs,
        iconColor: t.textSecondary,
        textColor: t.text,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        leadingAndTrailingTextStyle: text.bodySmall,
      ),
      dividerTheme: DividerThemeData(
        color: t.borderLight,
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
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppGaps.cardH,
          vertical: 14,
        ),
        border: inputBorder(t.border),
        enabledBorder: inputBorder(t.border),
        focusedBorder: inputBorder(AppColorsLight.tealPrimary, 1.5),
        errorBorder: inputBorder(t.error),
        labelStyle: text.bodyMedium,
        hintStyle: text.bodyMedium!.copyWith(color: t.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: buttonPadding,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: buttonLabel,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          padding: buttonPadding,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? t.text : AppColorsLight.navyPrimary,
          side: BorderSide(color: t.border),
          minimumSize: const Size(0, 52),
          padding: buttonPadding,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
          textStyle: buttonLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? AppColorsLight.tealPrimary : AppColorsLight.tealDark,
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          textStyle: buttonLabel,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: AppColorsLight.textOnDark,
        elevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: isDark ? t.surfaceHigh : AppColorsLight.navyPrimary,
        labelStyle: AppTextStyles.badge.copyWith(color: t.text),
        secondaryLabelStyle: AppTextStyles.badge.copyWith(
          color: AppColorsLight.textOnDark,
        ),
        side: BorderSide(color: t.border, width: 0.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(t.surface),
        side: WidgetStateProperty.all(BorderSide(color: t.border, width: 0.5)),
        shape: WidgetStateProperty.all(
          const RoundedRectangleBorder(borderRadius: AppRadius.card),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        constraints: const BoxConstraints(
          minHeight: AppDesignSystem.searchBarHeight,
        ),
        textStyle: WidgetStateProperty.all(text.bodyLarge),
        hintStyle: WidgetStateProperty.all(
          text.bodyMedium!.copyWith(color: t.textMuted),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
          side: BorderSide(color: t.border, width: 0.5),
        ),
        backgroundColor: isDark ? t.surfaceHigh : AppColorsLight.navyPrimary,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: isDark ? t.text : AppColorsLight.textOnDark,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: t.borderLight,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: t.border, width: 0.5),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        dragHandleColor: t.border,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
          side: BorderSide(color: t.border, width: 0.5),
        ),
      ),
    );
  }
}
