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

  /// Vocle's own message shape — a clinical "chart note" card, not a
  /// messenger speech bubble: soft 12 px corners, the sender's top corner
  /// squared like a clipped note, and incoming notes carry a teal margin
  /// rule on their left edge (like a ruled case sheet).
  static BoxDecoration bubble({required bool isMine}) {
    if (isMine) {
      return BoxDecoration(
        color: AppColors.bubbleMine,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(3),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      );
    }
    final rule = AppColors.tealPrimary.withValues(alpha: AppColors.isDark ? 0.55 : 0.45);
    return BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(3),
        topRight: Radius.circular(12),
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      border: Border(
        left: BorderSide(color: rule, width: 3),
        top: BorderSide(color: rule, width: 0.5),
        right: BorderSide(color: rule, width: 0.5),
        bottom: BorderSide(color: rule, width: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: AppColors.isDark ? 0.18 : 0.04),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
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
