import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_design_system.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';

/// Shared surface treatments — border-first, minimal shadow.
abstract final class AppDecorations {
  static BoxDecoration card({
    Color? color,
    double radius = AppSpacing.radiusMd,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border),
      boxShadow: shadow ? AppDesignSystem.cardShadow : null,
    );
  }

  static BoxDecoration bubble({required bool isMine}) {
    return BoxDecoration(
      color: isMine ? AppColors.bubbleMine : AppColors.bubbleOther,
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(AppSpacing.radiusMd),
        topRight: const Radius.circular(AppSpacing.radiusMd),
        bottomLeft: Radius.circular(isMine ? AppSpacing.radiusMd : AppSpacing.radiusSm),
        bottomRight: Radius.circular(isMine ? AppSpacing.radiusSm : AppSpacing.radiusMd),
      ),
      border: Border.all(
        color: isMine ? AppColors.bubbleBorderMine : AppColors.bubbleBorderOther,
      ),
    );
  }

  static BoxDecoration searchField() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      border: Border.all(color: AppColors.border),
    );
  }

  static BoxDecoration bottomBar() {
    return const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    );
  }

  static BoxDecoration presenceChip({required Color dotColor}) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      border: Border.all(color: AppColors.border),
    );
  }

  static BoxDecoration emptyStateIcon() {
    return BoxDecoration(
      color: AppColors.primaryContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      border: Border.all(color: AppColors.bubbleBorderMine),
    );
  }

  static BoxDecoration skeleton({double radius = AppSpacing.radiusSm}) {
    return BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
