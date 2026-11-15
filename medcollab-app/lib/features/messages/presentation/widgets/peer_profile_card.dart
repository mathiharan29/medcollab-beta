import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/availability_pill.dart';

/// Modern peer profile sheet shown from a DM app bar tap / overflow menu.
Future<void> showPeerProfileCard(
  BuildContext context, {
  required UserModel user,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (dialogContext) {
      final availability = user.availability.status;
      final roleLine = [
        user.role.label,
        if (user.speciality != null && user.speciality!.isNotEmpty)
          user.speciality!,
      ].join(' · ');

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(
                name: user.displayName,
                imageUrl: user.avatarUrl,
                size: 72,
                backgroundColor: AppColors.tealTint,
                foregroundColor: AppColors.tealDark,
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
              ),
              if (roleLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  roleLine,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AvailabilityPill(status: availability),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundApp,
                  borderRadius: AppRadius.card,
                  border: Border.all(
                    color: AppColors.borderDefault,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    if (user.institution != null &&
                        user.institution!.isNotEmpty)
                      _MetaRow(
                        icon: Icons.local_hospital_outlined,
                        label: user.institution!,
                      ),
                    if (user.city != null && user.city!.isNotEmpty)
                      _MetaRow(
                        icon: Icons.location_on_outlined,
                        label: user.city!,
                      ),
                    if (user.pgYear != null)
                      _MetaRow(
                        icon: Icons.school_outlined,
                        label: 'PG Year ${user.pgYear}',
                      ),
                    if (user.bio.trim().isNotEmpty)
                      _MetaRow(
                        icon: Icons.info_outline,
                        label: user.bio.trim(),
                      ),
                    if ((user.institution == null ||
                            user.institution!.isEmpty) &&
                        (user.city == null || user.city!.isEmpty) &&
                        user.pgYear == null &&
                        user.bio.trim().isEmpty)
                      Text(
                        'No extra profile details yet',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.actionFill,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tealDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
