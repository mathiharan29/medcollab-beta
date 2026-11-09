import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:medcollab_app/features/notifications/presentation/widgets/alert_card.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationsCubit(
        repository: AppDependencies.instance.notificationRepository,
        socketClient: AppDependencies.instance.socketClient,
        badgeCubit: AppDependencies.instance.notificationBadgeCubit,
      ),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  static const _visibleFilters = [
    NotificationFilter.all,
    NotificationFilter.mentions,
    NotificationFilter.channels,
    NotificationFilter.handoffs,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppGaps.screenH,
                12,
                8,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Alerts', style: AppTextStyles.screenTitle),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () =>
                        context.push(AppRoutes.notificationSettings),
                    icon: Icon(
                      Icons.settings_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  BlocBuilder<NotificationsCubit, NotificationsState>(
                    builder: (context, state) {
                      if (state.unreadCount == 0) {
                        return const SizedBox.shrink();
                      }
                      return TextButton(
                        onPressed: () =>
                            context.read<NotificationsCubit>().markAllRead(),
                        child: Text(
                          'Mark all read',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.tealDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                buildWhen: (p, n) => p.filter != n.filter,
                builder: (context, state) {
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppGaps.screenH,
                    ),
                    children: [
                      for (final f in _visibleFilters) ...[
                        _FilterPill(
                          label: _filterLabel(f),
                          selected: state.filter == f,
                          onTap: () =>
                              context.read<NotificationsCubit>().setFilter(f),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  if (state.isLoading) return const AppListSkeleton();
                  if (state.error != null) {
                    return Center(child: ErrorBanner(message: state.error!));
                  }
                  final items = state.visible;
                  if (items.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.notifications_none_outlined,
                      title: 'All caught up',
                      subtitle:
                          'Mentions, replies, handoffs, and invites appear here.',
                    );
                  }

                  final sections = _groupByDay(items);
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<NotificationsCubit>().load(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppGaps.screenH,
                        4,
                        AppGaps.screenH,
                        AppGaps.sectionGap,
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: index == 0 ? 0 : 16,
                                bottom: 8,
                              ),
                              child: Text(
                                section.label,
                                style: AppTextStyles.sectionLabel,
                              ),
                            ),
                            ...section.items.map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppGaps.itemGap + 2,
                                ),
                                child: _AlertTile(notification: n),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(NotificationFilter f) => switch (f) {
        NotificationFilter.all => 'All',
        NotificationFilter.mentions => 'Mentions',
        NotificationFilter.channels => 'Channels',
        NotificationFilter.handoffs => 'Handoffs',
        NotificationFilter.invites => 'Invites',
        NotificationFilter.announcements => 'Announcements',
      };

  List<_AlertSection> _groupByDay(List<AppNotificationModel> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final today = <AppNotificationModel>[];
    final earlier = <AppNotificationModel>[];

    for (final n in items) {
      final created = n.createdAt?.toLocal();
      if (created != null && !created.isBefore(todayStart)) {
        today.add(n);
      } else {
        earlier.add(n);
      }
    }

    return [
      if (today.isNotEmpty) _AlertSection(label: 'TODAY', items: today),
      if (earlier.isNotEmpty) _AlertSection(label: 'EARLIER', items: earlier),
    ];
  }
}

class _AlertSection {
  const _AlertSection({required this.label, required this.items});

  final String label;
  final List<AppNotificationModel> items;
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? (AppColors.isDark ? AppColors.tealDark : AppColors.navyPrimary)
          : AppColors.surfaceCard,
      borderRadius: AppRadius.pill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pill,
            border: selected
                ? null
                : Border.all(color: AppColors.borderDefault, width: 0.5),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textOnDark : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.notification});

  final AppNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    return AlertCard(
      notification: notification,
      onTap: () => _open(context),
      onLongPress: () => _showMenu(context),
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final cubit = context.read<NotificationsCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.read)
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined),
                title: const Text('Mark read'),
                onTap: () => Navigator.pop(ctx, 'read'),
              )
            else
              ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: const Text('Mark unread'),
                onTap: () => Navigator.pop(ctx, 'unread'),
              ),
          ],
        ),
      ),
    );
    if (action == 'read') {
      await cubit.markRead(notification);
    } else if (action == 'unread') {
      await cubit.markUnread(notification);
    }
  }

  void _open(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    final meta = notification.metadata;

    if (!notification.read) {
      cubit.markRead(notification);
    }

    if (meta.handoffId != null && meta.spaceId != null) {
      context.push(
        AppRoutes.spaceHandoffDetailPath(meta.spaceId!, meta.handoffId!),
      );
    } else if (meta.channelId != null &&
        (meta.spaceId == null || meta.spaceId!.isEmpty)) {
      context.push(AppRoutes.dmPath(meta.channelId!));
    } else if (meta.channelId != null && meta.spaceId != null) {
      context.push(
        AppRoutes.channelPath(meta.spaceId!, meta.channelId!),
      );
    } else if (meta.spaceId != null) {
      context.push(AppRoutes.spaceDetailPath(meta.spaceId!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to open for this notification')),
      );
    }
  }
}
