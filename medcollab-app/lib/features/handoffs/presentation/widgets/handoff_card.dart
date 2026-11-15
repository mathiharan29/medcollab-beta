import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';

/// Status key for [handoffAccentColor] / [handoffBadgeColors].
String handoffStatusToken(HandoffModel handoff) {
  if (handoff.lifecycleLabel == 'Not attended') return 'not_attended';
  return handoff.status.value;
}

/// Vocle handoff list row — accent bar + status badge (brief § SCREEN 5).
class HandoffCard extends StatelessWidget {
  const HandoffCard({
    required this.handoff,
    required this.onTap,
    this.onArchive,
    super.key,
  });

  final HandoffModel handoff;
  final VoidCallback onTap;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final patient = handoff.primaryPatient;
    final title = patient?.patientIdentifier ??
        '${handoff.patients.length} patients';
    final diagnosis = patient?.diagnosis.trim() ?? '';
    final shift = _shiftLabel(handoff);
    final date = handoff.shiftDate != null
        ? DateFormat('d MMM').format(handoff.shiftDate!.toLocal())
        : (handoff.lastUpdated != null
            ? DateFormat('d MMM').format(handoff.lastUpdated!.toLocal())
            : '');
    final metaParts = <String>[
      if (diagnosis.isNotEmpty) diagnosis,
      'From ${handoff.fromUser.displayName}',
      if (shift.isNotEmpty) shift,
      if (date.isNotEmpty) date,
    ];
    final token = handoffStatusToken(handoff);
    final accent = handoffAccentColor(token);
    final badge = handoffBadgeColors(token);
    final badgeLabel = _badgeLabel(handoff);

    return Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: AppColors.borderDefault, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badge.bg,
                              borderRadius: AppRadius.pill,
                            ),
                            child: Text(
                              badgeLabel,
                              style: AppTextStyles.badge.copyWith(
                                color: badge.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onArchive != null) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Archive',
                              onPressed: onArchive,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: AppGaps.itemGap),
                        Text(
                          metaParts.join(' · '),
                          style: AppTextStyles.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _badgeLabel(HandoffModel handoff) {
    final label = handoff.lifecycleLabel;
    if (label == 'Completed') return 'Done';
    return label;
  }

  static String _shiftLabel(HandoffModel handoff) {
    final raw = handoff.shiftType.value;
    if (raw.isEmpty) return '';
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}
