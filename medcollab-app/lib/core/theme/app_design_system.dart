import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

/// MedCollab design system — single reference for tokens and component specs.
///
/// Inspired by Linear (precision), Notion (calm surfaces), Slack (clinical chat).
abstract final class AppDesignSystem {
  // Brand personality
  static const String brandName = 'MedCollab';
  static const List<String> personality = [
    'Calm',
    'Professional',
    'Premium',
    'Trustworthy',
    'Clinical',
  ];

  // Touch & density (healthcare: large targets, gloved hands)
  static const double minTouchTarget = 48;
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double iconLg = 24;

  // App bar
  static const double appBarHeight = 56;
  static const Color appBarBackground = AppColors.surface;
  static const Color appBarForeground = AppColors.textPrimary;

  // Bottom bar / navigation
  static const Color bottomBarBackground = AppColors.surface;
  static const Color bottomBarBorder = AppColors.border;

  // FAB
  static const Color fabBackground = AppColors.primary;
  static const Color fabForeground = AppColors.textOnPrimary;
  static const double fabHeight = 48;

  // Search
  static const double searchBarHeight = 48;

  // Cards
  static const double cardRadius = AppSpacing.radiusMd;
  static const Color cardBackground = AppColors.surface;
  static const Color cardBorder = AppColors.border;

  // Avatar sizes
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;

  // Elevation — border over shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}
