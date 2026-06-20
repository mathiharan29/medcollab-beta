import 'package:flutter/material.dart';

/// MedCollab design tokens.
///
/// Personality: calm · professional · premium · trustworthy · clinical
/// No gradients. Border-first surfaces.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF0D5C56);
  static const Color primaryContainer = Color(0xFFCCFBF1);
  static const Color onPrimaryContainer = Color(0xFF134E4A);

  static const Color secondary = Color(0xFF1E293B);
  static const Color secondaryMuted = Color(0xFF334155);

  static const Color accent = Color(0xFFF59E0B);
  static const Color accentMuted = Color(0xFFFEF3C7);

  // ── Surfaces ─────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceVariant = Color(0xFFE2E8F0);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successMuted = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color errorMuted = Color(0xFFFEE2E2);
  static const Color emergency = Color(0xFFDC2626);
  static const Color urgent = Color(0xFFEA580C);

  // ── Presence ─────────────────────────────────────────────────────────────
  static const Color available = Color(0xFF22C55E);
  static const Color onCall = Color(0xFF0284C7);
  static const Color inOt = Color(0xFF7C3AED);
  static const Color offDuty = Color(0xFF94A3B8);
  static const Color busy = Color(0xFFF59E0B);

  // ── Structure ────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color shadow = Color(0x0A0F172A);

  // ── Chat ─────────────────────────────────────────────────────────────────
  static const Color bubbleMine = Color(0xFFCCFBF1);
  static const Color bubbleOther = Color(0xFFF1F5F9);
  static const Color bubbleBorderMine = Color(0xFF99F6E4);
  static const Color bubbleBorderOther = Color(0xFFE2E8F0);

  // Legacy aliases
  static const Color primaryMuted = primaryContainer;
  static const Color primaryLight = primaryContainer;
}
