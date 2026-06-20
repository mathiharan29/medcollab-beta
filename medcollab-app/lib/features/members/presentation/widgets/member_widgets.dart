import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_decorations.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/features/members/data/models/space_member_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

/// Presence indicator — compact dot or labeled pill chip.
class PresenceIndicator extends StatelessWidget {
  const PresenceIndicator({
    required this.isOnline,
    required this.status,
    this.compact = false,
    super.key,
  });

  final bool isOnline;
  final AvailabilityStatus status;
  final bool compact;

  Color get _dotColor {
    if (!isOnline) return AppColors.offDuty;
    return switch (status) {
      AvailabilityStatus.available => AppColors.available,
      AvailabilityStatus.doNotDisturb => AppColors.busy,
      AvailabilityStatus.inOt => AppColors.inOt,
      AvailabilityStatus.offDuty => AppColors.offDuty,
      AvailabilityStatus.onCall => AppColors.onCall,
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _dotColor,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
      );
    }

    final label = isOnline ? status.presenceLabel : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: AppDecorations.presenceChip(dotColor: _dotColor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet profile card for a space member.
class UserProfileSheet extends StatelessWidget {
  const UserProfileSheet({
    required this.member,
    super.key,
  });

  final SpaceMemberModel member;

  static Future<void> show(BuildContext context, SpaceMemberModel member) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UserProfileSheet(member: member),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = member.user;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                  size: 56,
                  showPresence: true,
                  isOnline: member.isOnline,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        user.role.label,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      PresenceIndicator(
                        isOnline: member.isOnline,
                        status: user.availability.status,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user.speciality != null) ...[
              const SizedBox(height: AppSpacing.md),
              _InfoRow(label: 'Speciality', value: user.speciality!),
            ],
            if (user.institution != null)
              _InfoRow(label: 'Institution', value: user.institution!),
            if (user.city != null) _InfoRow(label: 'City', value: user.city!),
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.bio,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// List tile for a space member.
class MemberListTile extends StatelessWidget {
  const MemberListTile({
    required this.member,
    required this.onTap,
    super.key,
  });

  final SpaceMemberModel member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = member.user;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      leading: AppAvatar(
        name: user.displayName,
        imageUrl: user.avatarUrl,
        showPresence: true,
        isOnline: member.isOnline,
      ),
      title: Text(user.displayName),
      subtitle: Text(
        user.speciality ?? user.role.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PresenceIndicator(
        isOnline: member.isOnline,
        status: user.availability.status,
      ),
      onTap: onTap,
    );
  }
}
