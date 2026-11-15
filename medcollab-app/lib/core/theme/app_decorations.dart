import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

/// Shared surface treatments — Vocle border-first cards.
abstract final class AppDecorations {
  static BoxDecoration card({
    Color? color,
    double radius = VocleRadius.card,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border, width: 0.5),
      boxShadow: shadow ? const [VocleShadows.card] : null,
    );
  }

  static BoxDecoration bubble({required bool isMine}) {
    if (isMine) {
      return BoxDecoration(
        color: AppColors.navyPrimary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      );
    }
    return BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(16),
      ),
      border: Border.all(color: AppColors.borderDefault, width: 0.5),
    );
  }

  static BoxDecoration searchField() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(VocleRadius.button),
      border: Border.all(color: AppColors.border, width: 0.5),
    );
  }

  static BoxDecoration bottomBar() {
    return BoxDecoration(color: AppColors.chrome);
  }

  static BoxDecoration presenceChip({required Color dotColor}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      border: Border.all(color: AppColors.border, width: 0.5),
    );
  }

  static BoxDecoration emptyStateIcon() {
    return BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(VocleRadius.icon),
      border: Border.all(color: AppColors.border, width: 0.5),
    );
  }

  static BoxDecoration skeleton({double radius = VocleRadius.button}) {
    return BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
