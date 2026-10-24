import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_priority_colors.dart';
import 'package:medcollab_app/features/home/data/dashboard_preferences_service.dart';
import 'package:medcollab_app/features/home/presentation/cubit/home_dashboard_cubit.dart';
import 'package:medcollab_app/features/home/presentation/cubit/home_dashboard_state.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/availability_pill.dart';
import 'package:medcollab_app/shared/presentation/widgets/clinical_card.dart';
import 'package:medcollab_app/shared/presentation/widgets/emergency_banner.dart';
import 'package:medcollab_app/shared/presentation/widgets/section_header.dart';

class DashboardConfigurationSheet extends StatefulWidget {
  const DashboardConfigurationSheet({
    required this.initialPreferences,
    required this.onSave,
    required this.onReset,
    super.key,
  });

  final List<DashboardWidgetPreference> initialPreferences;
  final ValueChanged<List<DashboardWidgetPreference>> onSave;
  final VoidCallback onReset;

  @override
  State<DashboardConfigurationSheet> createState() =>
      _DashboardConfigurationSheetState();
}

class _DashboardConfigurationSheetState
    extends State<DashboardConfigurationSheet> {
  late List<DashboardWidgetPreference> _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = List.of(widget.initialPreferences);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppGaps.screenH,
                AppGaps.sectionGap,
                8,
                AppGaps.itemGap,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Configure Home',
                      style: AppTextStyles.screenTitle,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      widget.onReset();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Reset'),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppGaps.screenH),
              child: Text(
                'Drag to reorder. Hidden widgets can be turned back on here.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppGaps.itemGap),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _preferences.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _preferences.removeAt(oldIndex);
                    _preferences.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final preference = _preferences[index];
                  return SwitchListTile(
                    key: ValueKey(preference.id),
                    secondary: const Icon(Icons.drag_handle),
                    title: Text(preference.id.label),
                    value: preference.isVisible,
                    onChanged: (value) {
                      setState(() {
                        _preferences[index] =
                            preference.copyWith(isVisible: value);
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppGaps.screenH),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onSave(_preferences);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save layout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayShiftWidget extends StatelessWidget {
  const TodayShiftWidget({
    required this.handoffs,
    required this.onOpenHandoffs,
    super.key,
  });

  final List<HandoffModel> handoffs;
  final VoidCallback onOpenHandoffs;

  @override
  Widget build(BuildContext context) {
    final handoff = handoffs.firstOrNull;
    return _DashboardSection(
      title: "Today's shift",
      child: ClinicalCard(
        onTap: handoff == null
            ? onOpenHandoffs
            : () => context.push(
                  AppRoutes.spaceHandoffDetailPath(
                    handoff.spaceId,
                    handoff.id,
                  ),
                ),
        child: handoff == null
            ? const _EmptyWidgetMessage(
                icon: Icons.event_available_outlined,
                title: 'No shift assignment for today',
                subtitle:
                    'Shift information appears here from assigned handoffs.',
              )
            : Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.tealTint,
                    child: Icon(
                      Icons.schedule_outlined,
                      color: AppColors.tealPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shiftLabel(handoff.shiftType),
                          style: AppTextStyles.cardTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${handoff.patients.length} patients · '
                          '${handoff.lifecycleLabel}',
                          style: AppTextStyles.caption,
                        ),
                        if (handoff.shiftSummary.isNotEmpty)
                          Text(
                            handoff.shiftSummary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
      ),
    );
  }
}

class AvailabilityWidget extends StatelessWidget {
  const AvailabilityWidget({required this.user, super.key});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final availability =
        user?.availability.status ?? AvailabilityStatus.available;
    return _DashboardSection(
      title: 'Current availability',
      child: ClinicalCard(
        onTap: () => context.go(AppRoutes.profile),
        child: Row(
          children: [
            AvailabilityPill(status: availability),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user?.availability.note.trim().isNotEmpty == true
                    ? user!.availability.note
                    : 'Tap to update your status',
                style: AppTextStyles.caption,
              ),
            ),
            const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class AssignedHandoffsWidget extends StatelessWidget {
  const AssignedHandoffsWidget({required this.handoffs, super.key});

  final List<HandoffModel> handoffs;

  @override
  Widget build(BuildContext context) {
    // Vocle Home: only handoffs still awaiting acknowledgement (submitted).
    final pending = handoffs.take(2).toList();
    return _DashboardSection(
      title: 'Pending handoffs',
      actionLabel: 'See all',
      onAction: () => context.go(AppRoutes.handoffs),
      child: pending.isEmpty
          ? const ClinicalCard(
              child: _EmptyWidgetMessage(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No pending handoffs',
                subtitle: 'Acknowledged handoffs move to Active / Completed.',
              ),
            )
          : Column(
              children: [
                for (final handoff in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppGaps.itemGap),
                    child: _PendingHandoffCard(handoff: handoff),
                  ),
              ],
            ),
    );
  }
}

class _PendingHandoffCard extends StatelessWidget {
  const _PendingHandoffCard({required this.handoff});

  final HandoffModel handoff;

  @override
  Widget build(BuildContext context) {
    final accent = handoffAccentColor(
      handoff.lifecycleLabel == 'Not attended'
          ? 'not_attended'
          : handoff.status.value,
    );
    final chip = HandoffPriorityColors.statusChip(handoff);
    final patient = handoff.primaryPatient;
    final title = patient != null
        ? patient.patientIdentifier.trim()
        : '${_shiftLabel(handoff.shiftType)} · ${handoff.patients.length} patients';
    final fromName = handoff.fromUser.displayName;
    final datePart = handoff.shiftDate == null
        ? 'Unscheduled'
        : DateFormat('d MMM').format(handoff.shiftDate!);
    final subtitle =
        'From $fromName · ${_shiftLabel(handoff.shiftType)} · $datePart';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: () async {
          await context.push<HandoffModel>(
            AppRoutes.spaceHandoffDetailPath(handoff.spaceId, handoff.id),
          );
          if (!context.mounted) return;
          // Refresh Home immediately so pending list doesn't stay stale.
          context.read<HomeDashboardCubit>().load();
        },
        child: ClipRRect(
          borderRadius: AppRadius.card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.borderDefault, width: 0.5),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 11, 13, 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: chip.$1,
                              borderRadius: AppRadius.pill,
                            ),
                            child: Text(
                              chip.$3,
                              style: AppTextStyles.badge.copyWith(
                                color: chip.$2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PendingTasksWidget extends StatelessWidget {
  const PendingTasksWidget({required this.state, super.key});

  final HomeDashboardState state;

  @override
  Widget build(BuildContext context) {
    final tasks = [
      (
        icon: Icons.assignment_late_outlined,
        label: 'Handoffs awaiting action',
        count: state.pendingHandoffs,
        onTap: () => context.go(AppRoutes.handoffs),
      ),
      (
        icon: Icons.alternate_email,
        label: 'Unread mentions',
        count: state.unreadMentions,
        onTap: () => context.go(AppRoutes.notifications),
      ),
      (
        icon: Icons.reply_outlined,
        label: 'Unread thread replies',
        count: state.unreadThreads,
        onTap: () => context.go(AppRoutes.notifications),
      ),
      (
        icon: Icons.group_add_outlined,
        label: 'Space invitations',
        count: state.inviteCount,
        onTap: () => context.go(AppRoutes.notifications),
      ),
    ].where((task) => task.count > 0).toList();

    return _DashboardSection(
      title: 'Pending tasks',
      child: ClinicalCard(
        padding: tasks.isEmpty
            ? const EdgeInsets.all(AppGaps.screenH)
            : EdgeInsets.zero,
        child: tasks.isEmpty
            ? const _EmptyWidgetMessage(
                icon: Icons.task_alt,
                title: 'All caught up',
                subtitle: 'No communication tasks need attention.',
              )
            : Column(
                children: tasks.map((task) {
                  return ListTile(
                    leading: Icon(task.icon, color: AppColors.tealPrimary),
                    title: Text(task.label, style: AppTextStyles.cardTitle),
                    trailing: CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.tealPrimary,
                      child: Text(
                        '${task.count}',
                        style: AppTextStyles.badge.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      ),
                    ),
                    onTap: task.onTap,
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class PatientDiscussionsWidget extends StatelessWidget {
  const PatientDiscussionsWidget({required this.discussions, super.key});

  final List<PatientDiscussionPreview> discussions;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'Recent patient discussions',
      actionLabel: 'Messages',
      onAction: () => context.go(AppRoutes.messages),
      child: discussions.isEmpty
          ? const ClinicalCard(
              child: _EmptyWidgetMessage(
                icon: Icons.forum_outlined,
                title: 'No recent discussions',
                subtitle: 'Recent subgroup conversations appear here.',
              ),
            )
          : Column(
              children: discussions.take(4).map((discussion) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppGaps.itemGap),
                  child: ClinicalCard(
                    onTap: () => context.push(
                      AppRoutes.channelPath(
                        discussion.spaceId,
                        discussion.channelId,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${discussion.spaceName} · '
                          '${discussion.channelName}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          discussion.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        if (discussion.senderName != null)
                          Text(
                            discussion.senderName!,
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class RecentDmsWidget extends StatelessWidget {
  const RecentDmsWidget({required this.dms, super.key});

  final List<ChannelModel> dms;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'Recent DMs',
      actionLabel: 'Find doctor',
      onAction: () => context.push(AppRoutes.startDm),
      child: Column(
        children: [
          if (dms.isEmpty)
            ClinicalCard(
              onTap: () => context.push(AppRoutes.startDm),
              child: const _EmptyWidgetMessage(
                icon: Icons.person_add_alt_1_outlined,
                title: 'No direct messages',
                subtitle: 'Start a private conversation with a colleague.',
              ),
            )
          else
            ClinicalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: dms.take(4).map((dm) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.tealTint,
                      child: Text(
                        dm.displayName.isEmpty
                            ? '?'
                            : dm.displayName[0].toUpperCase(),
                      ),
                    ),
                    title: Text(dm.displayName, style: AppTextStyles.cardTitle),
                    subtitle: dm.lastMessage?.text == null
                        ? null
                        : Text(
                            dm.lastMessage!.text!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(AppRoutes.dmPath(dm.id), extra: dm),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class WorkspaceQuickActionsWidget extends StatelessWidget {
  const WorkspaceQuickActionsWidget({
    required this.onNewHandoff,
    required this.onNewMessage,
    super.key,
  });

  final VoidCallback onNewHandoff;
  final VoidCallback onNewMessage;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.swap_horiz_rounded,
        label: 'New handoff',
        onTap: onNewHandoff,
      ),
      (
        icon: Icons.chat_bubble_outline,
        label: 'New message',
        onTap: onNewMessage,
      ),
    ];

    return _DashboardSection(
      title: 'Quick actions',
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _QuickActionCard(
                icon: actions[i].icon,
                label: actions[i].label,
                onTap: actions[i].onTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.borderDefault, width: 0.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.tealTint,
                  borderRadius: AppRadius.button,
                ),
                child: Icon(icon, color: AppColors.tealPrimary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmergencyWorkspaceWidget extends StatelessWidget {
  const EmergencyWorkspaceWidget({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGaps.screenH,
        14,
        AppGaps.screenH,
        0,
      ),
      child: EmergencyBanner(onPressed: onPressed),
    );
  }
}

class WorkspaceAnnouncementsWidget extends StatelessWidget {
  const WorkspaceAnnouncementsWidget({
    required this.title,
    required this.announcements,
    required this.emptyMessage,
    super.key,
  });

  final String title;
  final List<AnnouncementPreview> announcements;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: title,
      child: announcements.isEmpty
          ? ClinicalCard(
              child: _EmptyWidgetMessage(
                icon: Icons.campaign_outlined,
                title: 'No announcements',
                subtitle: emptyMessage,
              ),
            )
          : Column(
              children: announcements.take(3).map((announcement) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppGaps.itemGap),
                  child: ClinicalCard(
                    onTap: () => context.push(
                      AppRoutes.channelPath(
                        announcement.spaceId,
                        announcement.channelId,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement.spaceName,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          announcement.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppGaps.screenH,
        AppGaps.sectionGap,
        AppGaps.screenH,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            label: title,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          child,
        ],
      ),
    );
  }
}

class _EmptyWidgetMessage extends StatelessWidget {
  const _EmptyWidgetMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.cardTitle),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

String _shiftLabel(ShiftType shiftType) {
  final value = shiftType.value;
  return '${value[0].toUpperCase()}${value.substring(1)} shift';
}
