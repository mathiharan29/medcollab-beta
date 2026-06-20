import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_decorations.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_priority_colors.dart';

class HandoffListTile extends StatelessWidget {
  const HandoffListTile({
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
    final priorityColor = HandoffPriorityColors.forHandoff(handoff);
    final patient = handoff.primaryPatient;
    final updated = handoff.lastUpdated;
    final timeLabel = updated != null
        ? DateFormat('d MMM, h:mm a').format(updated.toLocal())
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: priorityColor, width: 4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                patient?.patientIdentifier ??
                                    '${handoff.patients.length} patients',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusChip(status: handoff.status),
                            if (handoff.hasFlaggedPatient) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const Icon(
                                Icons.flag_outlined,
                                size: 15,
                                color: AppColors.emergency,
                              ),
                            ],
                          ],
                        ),
                        if (patient?.diagnosis.isNotEmpty == true) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            patient!.diagnosis,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Expanded(
                              child: Text(
                                handoff.toUser.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Updated $timeLabel',
                            style:
                                Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
                if (onArchive != null)
                  IconButton(
                    tooltip:
                        handoff.isDraft ? 'Delete draft' : 'Archive',
                    onPressed: onArchive,
                    icon: Icon(
                      handoff.isDraft
                          ? Icons.delete_outline
                          : Icons.archive_outlined,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final HandoffStatus status;

  @override
  Widget build(BuildContext context) {
    final color = HandoffPriorityColors.handoffStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        HandoffPriorityColors.handoffStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class HandoffPatientCard extends StatelessWidget {
  const HandoffPatientCard({
    required this.patient,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final HandoffPatientModel patient;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = HandoffPriorityColors.forPatient(patient);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  patient.patientIdentifier,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (patient.isFlagged)
                const Icon(
                  Icons.flag_outlined,
                  size: 15,
                  color: AppColors.emergency,
                ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textTertiary,
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textTertiary,
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (patient.diagnosis.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              patient.diagnosis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xxs),
          Text(
            HandoffPriorityColors.statusLabel(patient.status),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (patient.pendingTasks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Pending tasks',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
            ),
            ...patient.pendingTasks.map(
              (t) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '· ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Expanded(
                      child: Text(t, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (patient.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              patient.notes,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
