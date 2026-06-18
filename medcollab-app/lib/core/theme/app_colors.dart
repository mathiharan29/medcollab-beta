import 'package:flutter/material.dart';

/// MedCollab color palette — clinical, trustworthy, emergency-aware.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF0D6E6E);
  static const Color primaryDark = Color(0xFF084848);
  static const Color primaryLight = Color(0xFF4A9E9E);

  // Surfaces
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8EDF2);

  // Text
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF5C6B7A);
  static const Color textTertiary = Color(0xFF8A97A6);

  // Semantic
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFE67E22);
  static const Color error = Color(0xFFC62828);
  static const Color emergency = Color(0xFFD32F2F);
  static const Color urgent = Color(0xFFEF6C00);

  // Availability dots
  static const Color available = Color(0xFF43A047);
  static const Color onCall = Color(0xFF1E88E5);
  static const Color inOt = Color(0xFF8E24AA);
  static const Color offDuty = Color(0xFF9E9E9E);

  // Borders & dividers
  static const Color border = Color(0xFFDDE3EA);
  static const Color divider = Color(0xFFE8EDF2);
}
