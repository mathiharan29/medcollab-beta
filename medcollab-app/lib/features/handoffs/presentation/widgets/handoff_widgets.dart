import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: priorityColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                        ],
                      ),
                      if (patient?.diagnosis.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          patient!.diagnosis,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: AppColors.textSecondary,),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              handoff.toUser.displayName,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Updated $timeLabel',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onArchive != null)
                IconButton(
                  tooltip: handoff.isDraft
                      ? 'Delete draft'
                      : 'Archive',
                  onPressed: onArchive,
                  icon: Icon(
                    handoff.isDraft
                        ? Icons.delete_outline
                        : Icons.archive_outlined,
                    color: AppColors.textSecondary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: HandoffPriorityColors.handoffStatusColor(status)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        HandoffPriorityColors.handoffStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: HandoffPriorityColors.handoffStatusColor(status),
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patient.patientIdentifier,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (patient.isFlagged)
                  const Icon(Icons.flag, size: 16, color: AppColors.emergency),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (patient.diagnosis.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Diagnosis: ${patient.diagnosis}'),
            ],
            const SizedBox(height: 4),
            Text(
              'Status: ${HandoffPriorityColors.statusLabel(patient.status)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
            if (patient.pendingTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Pending tasks',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              ...patient.pendingTasks.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(t)),
                    ],
                  ),
                ),
              ),
            ],
            if (patient.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                patient.notes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
