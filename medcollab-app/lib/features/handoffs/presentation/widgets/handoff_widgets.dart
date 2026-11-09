import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_priority_colors.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_card.dart';
import 'package:medcollab_app/features/media/data/services/document_open_service.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppGaps.screenH,
        vertical: AppGaps.itemGap / 2,
      ),
      child: HandoffCard(
        handoff: handoff,
        onTap: onTap,
        onArchive: onArchive,
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
    final statusBg = color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(AppGaps.cardH),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  patient.patientIdentifier,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (patient.isFlagged)
                const Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: AppColors.emergencyRed,
                ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit patient',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textMuted,
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Remove patient',
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textMuted,
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (patient.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(patient.diagnosis, style: AppTextStyles.body),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: AppRadius.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  patient.status == PatientStatus.critical
                      ? Icons.warning_amber_rounded
                      : Icons.monitor_heart_outlined,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  HandoffPriorityColors.statusLabel(patient.status),
                  style: AppTextStyles.badge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (patient.pendingTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Pending tasks',
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ...patient.pendingTasks.map(
              (t) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.tealPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t, style: AppTextStyles.body),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (patient.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Attachments',
              style: AppTextStyles.cardTitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final attachment in patient.attachments)
                  ActionChip(
                    avatar: Icon(
                      attachment.isImage
                          ? Icons.image_outlined
                          : Icons.description_outlined,
                      size: 16,
                      color: AppColors.tealPrimary,
                    ),
                    label: Text(
                      attachment.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    onPressed: () => DocumentOpenService.open(
                      context,
                      url: attachment.url,
                      fileName: attachment.displayName,
                      mimeType: attachment.mimeType,
                    ),
                  ),
              ],
            ),
          ],
          if (patient.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              patient.notes,
              style: AppTextStyles.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

