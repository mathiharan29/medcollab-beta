import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';

/// Horizontally scrolling filter pills used by every handoff list, so the
/// Handoffs tab and a group's handoffs look and behave the same. Labels never
/// wrap mid-word (the old segmented control split "Pending" into "Pendi/ng").
class HandoffFilterPills<T> extends StatelessWidget {
  const HandoffFilterPills({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    // Grows with the user's text size instead of clipping.
    final height = 24 + 16 * MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppGaps.screenH),
        children: [
          for (final value in values) ...[
            HandoffFilterPill(
              label: labelOf(value),
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class HandoffFilterPill extends StatelessWidget {
  const HandoffFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        // Navy on the dark navy page was nearly invisible; teal in dark mode
        // matches the dark-theme primary buttons.
        color: selected
            ? (AppColors.isDark ? AppColors.tealDark : AppColors.navyPrimary)
            : AppColors.surfaceCard,
        borderRadius: AppRadius.pill,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pill,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.pill,
              border: selected
                  ? null
                  : Border.all(color: AppColors.borderDefault, width: 0.5),
            ),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.textOnDark : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
