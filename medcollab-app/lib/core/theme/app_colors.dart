import 'package:flutter/material.dart';

/// Light palette — the original Vocle tokens ([VOCLE_UI_REDESIGN_CURSOR_BRIEF.md] §2).
///
/// Constant, so it can be used where a compile-time colour is required
/// (e.g. the light [ThemeData]). UI code should use [AppColors], which
/// follows the active light/dark theme.
abstract final class AppColorsLight {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color navyPrimary = Color(0xFF0D1B3E);
  static const Color navySecondary = Color(0xFF162952);
  static const Color tealPrimary = Color(0xFF00C2A8);
  static const Color tealDark = Color(0xFF00A88F);
  static const Color tealTint = Color(0xFFE8FBF8);

  // ── Surfaces ───────────────────────────────────────────────────────────
  static const Color backgroundApp = Color(0xFFF5F7FA);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceInput = Color(0xFFF5F7FA);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0D1B3E);
  static const Color textSecondary = Color(0xFF5A6A85);
  static const Color textMuted = Color(0xFF9CA8B8);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0x8DFFFFFF);

  // ── Borders ────────────────────────────────────────────────────────────
  static const Color borderDefault = Color(0xFFE4E8EF);
  static const Color borderLight = Color(0xFFF0F2F5);
  static const Color borderStrong = Color(0xFFC5CDD8);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color emergencyRed = Color(0xFFDC2626);
  static const Color emergencyTint = Color(0xFFFEE2E2);
  static const Color emergencyBorder = Color(0xFFFCA5A5);
  static const Color statusSuccess = Color(0xFF059669);
  static const Color statusSuccTint = Color(0xFFD1FAE5);
  static const Color statusWarning = Color(0xFFD97706);
  static const Color statusWarnTint = Color(0xFFFEF3C7);
  static const Color statusPending = Color(0xFFE8740A);
  static const Color statusPendTint = Color(0xFFFFF3E0);
  static const Color statusError = Color(0xFFDC2626);
  static const Color statusErrorTint = Color(0xFFFEE2E2);
  static const Color statusNeutral = Color(0xFF5A6A85);
  static const Color statusNeutTint = Color(0xFFF1F2F4);

  // ── Compatibility aliases used by the light ThemeData ──────────────────
  static const Color primary = tealPrimary;
  static const Color primaryDark = tealDark;
  static const Color primaryContainer = tealTint;
  static const Color onPrimaryContainer = navyPrimary;
  static const Color background = backgroundApp;
  static const Color surface = surfaceCard;
  static const Color surfaceMuted = surfaceInput;
  static const Color surfaceVariant = borderLight;
  static const Color textTertiary = textMuted;
  static const Color textOnPrimary = textOnDark;
  static const Color border = borderDefault;
  static const Color divider = borderLight;
  static const Color error = statusError;
  static const Color secondary = navyPrimary;
  static const Color shadow = Color(0x08000000);
}

/// Dark counterparts of the neutral tokens (REQ 6). Brand and semantic
/// colours (teal, navy chrome, emergency red, status colours) are shared.
abstract final class AppColorsDark {
  static const Color backgroundApp = Color(0xFF0A1428);
  static const Color surfaceCard = Color(0xFF111F3D);
  static const Color surfaceInput = Color(0xFF162952);
  static const Color textPrimary = Color(0xFFE8EEF8);
  static const Color textSecondary = Color(0xFFA8B4CC);
  static const Color textMuted = Color(0xFF7A89A5);
  static const Color borderDefault = Color(0xFF24365C);
  static const Color borderLight = Color(0xFF1A2B4E);
  static const Color borderStrong = Color(0xFF34497A);
  static const Color tealTint = Color(0xFF0F3B44);
  static const Color onPrimaryContainer = Color(0xFFB8F2E9);
  static const Color emergencyTint = Color(0xFF3B1620);
  static const Color emergencyBorder = Color(0xFF7F1D1D);
  static const Color statusSuccTint = Color(0xFF0E3B2E);
  static const Color statusWarnTint = Color(0xFF3D2E0B);
  static const Color statusPendTint = Color(0xFF3D2410);
  static const Color statusErrorTint = Color(0xFF3B1620);
  static const Color statusNeutTint = Color(0xFF1E2A44);
  static const Color shadow = Color(0x33000000);
  static const Color bubbleMine = Color(0xFF0E5A52);
}

/// Vocle colour tokens that follow the active theme (REQ 6).
///
/// Brand / semantic colours are compile-time constants and identical in both
/// themes. Neutral tokens (backgrounds, cards, text, borders, tints) are
/// getters resolved against the current brightness, which the app sets via
/// [setBrightness] whenever the theme changes. Before this, all 675 call
/// sites used light-only constants, so dark mode left white cards and
/// navy-on-navy text.
abstract final class AppColors {
  static bool _dark = false;

  static bool get isDark => _dark;

  /// Returns true if the brightness changed (caller should rebuild the UI).
  static bool setBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (dark == _dark) return false;
    _dark = dark;
    return true;
  }

  // ── Brand (shared) ─────────────────────────────────────────────────────
  static const Color navyPrimary = AppColorsLight.navyPrimary;
  static const Color navySecondary = AppColorsLight.navySecondary;
  static const Color tealPrimary = AppColorsLight.tealPrimary;
  static const Color tealDark = AppColorsLight.tealDark;
  static Color get tealTint =>
      _dark ? AppColorsDark.tealTint : AppColorsLight.tealTint;

  // ── Surfaces ───────────────────────────────────────────────────────────
  static Color get backgroundApp =>
      _dark ? AppColorsDark.backgroundApp : AppColorsLight.backgroundApp;
  static Color get surfaceCard =>
      _dark ? AppColorsDark.surfaceCard : AppColorsLight.surfaceCard;
  static Color get surfaceInput =>
      _dark ? AppColorsDark.surfaceInput : AppColorsLight.surfaceInput;

  // ── Text ───────────────────────────────────────────────────────────────
  static Color get textPrimary =>
      _dark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary;
  static Color get textSecondary =>
      _dark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary;
  static Color get textMuted =>
      _dark ? AppColorsDark.textMuted : AppColorsLight.textMuted;
  static const Color textOnDark = AppColorsLight.textOnDark;
  static const Color textOnDarkMuted = AppColorsLight.textOnDarkMuted;

  // ── Borders ────────────────────────────────────────────────────────────
  static Color get borderDefault =>
      _dark ? AppColorsDark.borderDefault : AppColorsLight.borderDefault;
  static Color get borderLight =>
      _dark ? AppColorsDark.borderLight : AppColorsLight.borderLight;

  // ── Semantic — Emergency ───────────────────────────────────────────────
  static const Color emergencyRed = AppColorsLight.emergencyRed;
  static Color get emergencyTint =>
      _dark ? AppColorsDark.emergencyTint : AppColorsLight.emergencyTint;
  static Color get emergencyBorder =>
      _dark ? AppColorsDark.emergencyBorder : AppColorsLight.emergencyBorder;

  // ── Semantic — Status ──────────────────────────────────────────────────
  static const Color statusSuccess = AppColorsLight.statusSuccess;
  static Color get statusSuccTint =>
      _dark ? AppColorsDark.statusSuccTint : AppColorsLight.statusSuccTint;
  static const Color statusWarning = AppColorsLight.statusWarning;
  static Color get statusWarnTint =>
      _dark ? AppColorsDark.statusWarnTint : AppColorsLight.statusWarnTint;
  static const Color statusPending = AppColorsLight.statusPending;
  static Color get statusPendTint =>
      _dark ? AppColorsDark.statusPendTint : AppColorsLight.statusPendTint;
  static const Color statusError = AppColorsLight.statusError;
  static Color get statusErrorTint =>
      _dark ? AppColorsDark.statusErrorTint : AppColorsLight.statusErrorTint;
  static const Color statusNeutral = AppColorsLight.statusNeutral;
  static Color get statusNeutTint =>
      _dark ? AppColorsDark.statusNeutTint : AppColorsLight.statusNeutTint;

  // ── Compatibility aliases (pre-redesign call sites) ───────────────────
  static const Color primary = tealPrimary;
  static const Color primaryDark = tealDark;
  static Color get primaryContainer => tealTint;
  static Color get onPrimaryContainer => _dark
      ? AppColorsDark.onPrimaryContainer
      : AppColorsLight.onPrimaryContainer;
  static Color get primaryMuted => tealTint;
  static Color get primaryLight => tealTint;

  static const Color secondary = navyPrimary;
  static const Color secondaryMuted = navySecondary;

  static const Color accent = statusPending;
  static Color get accentMuted => statusPendTint;

  static Color get background => backgroundApp;
  static Color get surface => surfaceCard;
  static Color get surfaceMuted => surfaceInput;
  static Color get surfaceVariant => borderLight;

  static Color get textTertiary => textMuted;
  static const Color textOnPrimary = textOnDark;

  static const Color success = statusSuccess;
  static Color get successMuted => statusSuccTint;
  static const Color warning = statusWarning;
  static const Color error = statusError;
  static Color get errorMuted => statusErrorTint;
  static const Color emergency = emergencyRed;
  static const Color urgent = statusPending;

  static const Color available = statusSuccess;
  static const Color onCall = statusWarning;
  /// Clinical blue — distinct from offline/muted grey.
  static const Color inOt = Color(0xFF2563EB);
  static Color get offDuty => textMuted;
  static const Color busy = statusError;

  static Color get border => borderDefault;
  static Color get borderStrong =>
      _dark ? AppColorsDark.borderStrong : AppColorsLight.borderStrong;
  static Color get divider => borderLight;
  static Color get shadow =>
      _dark ? AppColorsDark.shadow : const Color(0x08000000);

  /// Own-message bubble. Navy on the light background; deep teal in dark
  /// mode, where navy was indistinguishable from the dark page (REQ 6).
  static Color get bubbleMine =>
      _dark ? AppColorsDark.bubbleMine : navyPrimary;
  static Color get bubbleOther => surfaceCard;
  static Color get bubbleBorderMine => bubbleMine;
  static Color get bubbleBorderOther => borderDefault;
}

/// Availability status → color (brief §2). Accepts API `status` string values.
Color availabilityStatusColor(String status) {
  switch (status) {
    case 'available':
      return AppColors.statusSuccess;
    case 'on_call':
      return AppColors.statusWarning;
    case 'in_ot':
      return AppColors.inOt;
    case 'in_icu':
      return AppColors.statusError;
    case 'on_rounds':
      return AppColors.tealPrimary;
    case 'off_duty':
      return AppColors.textMuted;
    case 'do_not_disturb':
      return AppColors.statusNeutral;
    case 'offline':
      return AppColors.textMuted;
    default:
      return AppColors.textMuted;
  }
}

/// Handoff list accent bar (left 4px) — brief §2.
Color handoffAccentColor(String status) {
  switch (status) {
    case 'submitted':
      return AppColors.statusPending;
    case 'acknowledged':
      return AppColors.statusSuccess;
    case 'draft':
      return AppColors.textMuted;
    default:
      return AppColors.statusError;
  }
}

/// Handoff status badge chip colors — brief §2.
({Color bg, Color text}) handoffBadgeColors(String status) {
  // Backgrounds already follow the theme; the text must too, or dark-mode
  // badges were dark green/brown on dark tints (unreadable "Active" chip).
  final dark = AppColors.isDark;
  switch (status) {
    case 'submitted':
      return (
        bg: AppColors.statusPendTint,
        text: dark ? const Color(0xFFFDBA74) : const Color(0xFF9A4F0A),
      );
    case 'acknowledged':
      return (
        bg: AppColors.statusSuccTint,
        text: dark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
      );
    case 'draft':
      return (
        bg: AppColors.statusNeutTint,
        text: dark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
      );
    default:
      return (
        bg: AppColors.statusErrorTint,
        text: dark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
      );
  }
}

/// Temporary aliases used by the interim redesign pass — map onto brief tokens.
abstract final class VocleColors {
  static const Color navy = AppColors.navyPrimary;
  static const Color teal = AppColors.tealPrimary;
  static const Color tealDark = AppColors.tealDark;
  static Color get tealBg => AppColors.tealTint;
  static const Color emergency = AppColors.emergencyRed;
  static Color get emergencyBg => AppColors.emergencyTint;
  static const Color success = AppColors.statusSuccess;
  static const Color warning = AppColors.statusWarning;
  static const Color blue = Color(0xFF1A6FBF);
  static Color get pageBg => AppColors.backgroundApp;
  static Color get surface => AppColors.surfaceCard;
  static Color get border => AppColors.borderDefault;
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textMuted => AppColors.textMuted;
}

abstract final class VocleRadius {
  static const double card = 12;
  static const double chip = 20;
  static const double button = 8;
  static const double avatar = 50;
  static const double icon = 8;
}

abstract final class VocleShadows {
  static const BoxShadow card = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const BoxShadow emergency = BoxShadow(
    color: Color(0x4DDC2626),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
}
