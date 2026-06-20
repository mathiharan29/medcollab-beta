import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/members/data/models/space_member_model.dart';

/// Presence dot + availability label for a member.
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
    if (!isOnline) return AppColors.textSecondary;
    return switch (status) {
      AvailabilityStatus.available => AppColors.success,
      AvailabilityStatus.doNotDisturb => AppColors.warning,
      AvailabilityStatus.inOt => AppColors.emergency,
      AvailabilityStatus.offDuty => AppColors.textSecondary,
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final label = isOnline ? status.presenceLabel : 'Offline';
    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _dotColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
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
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage:
                      user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: Theme.of(context).textTheme.headlineSmall,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
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
              const SizedBox(height: 16),
              _InfoRow(label: 'Speciality', value: user.speciality!),
            ],
            if (user.institution != null)
              _InfoRow(label: 'Institution', value: user.institution!),
            if (user.city != null) _InfoRow(label: 'City', value: user.city!),
            if (user.bio.isNotEmpty) ...[
              const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(user.displayName.isNotEmpty ? user.displayName[0] : '?')
                : null,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: PresenceIndicator(
              isOnline: member.isOnline,
              status: user.availability.status,
              compact: true,
            ),
          ),
        ],
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
