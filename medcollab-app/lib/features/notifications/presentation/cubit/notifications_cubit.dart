import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';

enum NotificationFilter {
  all,
  mentions,
  channels,
  invites,
  handoffs,
  announcements,
}

class NotificationsState extends Equatable {
  const NotificationsState({
    this.isLoading = true,
    this.error,
    this.notifications = const [],
    this.filter = NotificationFilter.all,
    this.unreadCount = 0,
  });

  final bool isLoading;
  final String? error;
  final List<AppNotificationModel> notifications;
  final NotificationFilter filter;
  final int unreadCount;

  List<AppNotificationModel> get visible {
    if (filter == NotificationFilter.all) return notifications;
    return notifications.where((n) {
      return switch (filter) {
        NotificationFilter.mentions =>
          n.category == AppNotificationCategory.mention,
        // Space channel traffic only; pure DMs (no spaceId) are excluded.
        NotificationFilter.channels =>
          (n.category == AppNotificationCategory.message ||
                  n.category == AppNotificationCategory.reply) &&
              (n.metadata.spaceId?.isNotEmpty ?? false),
        NotificationFilter.invites =>
          n.category == AppNotificationCategory.invite,
        NotificationFilter.handoffs =>
          n.category == AppNotificationCategory.handoff,
        NotificationFilter.announcements =>
          n.category == AppNotificationCategory.announcement,
        NotificationFilter.all => true,
      };
    }).toList();
  }

  NotificationsState copyWith({
    bool? isLoading,
    String? error,
    List<AppNotificationModel>? notifications,
    NotificationFilter? filter,
    int? unreadCount,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      notifications: notifications ?? this.notifications,
      filter: filter ?? this.filter,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, error, notifications, filter, unreadCount];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required NotificationRepository repository,
    required SocketClient socketClient,
    required NotificationBadgeCubit badgeCubit,
  })  : _repository = repository,
        _socketClient = socketClient,
        _badgeCubit = badgeCubit,
        super(const NotificationsState()) {
    load();
    _notifSub = _socketClient
        .onMapEvent(SocketEvents.newNotification)
        .listen(_onSocketNotification);
    // Debounced re-sync when badge drops because chat marked channel alerts read.
    _badgeSub = _badgeCubit.stream.listen((count) {
      if (!_acceptBadgeSync || count == state.unreadCount) return;
      unawaited(loadSilent());
    });
  }

  final NotificationRepository _repository;
  final SocketClient _socketClient;
  final NotificationBadgeCubit _badgeCubit;
  StreamSubscription<Map<String, dynamic>>? _notifSub;
  StreamSubscription<int>? _badgeSub;
  bool _acceptBadgeSync = false;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final page = await _repository.getNotifications(limit: 50);
      emit(
        state.copyWith(
          isLoading: false,
          notifications: page.notifications,
          unreadCount: page.unreadCount,
        ),
      );
      _acceptBadgeSync = false;
      _badgeCubit.setCount(page.unreadCount);
      _acceptBadgeSync = true;
    } on AppException catch (e) {
      _acceptBadgeSync = true;
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  Future<void> loadSilent() async {
    try {
      final page = await _repository.getNotifications(limit: 50);
      emit(
        state.copyWith(
          isLoading: false,
          notifications: page.notifications,
          unreadCount: page.unreadCount,
          error: null,
        ),
      );
    } on AppException {
      /* ignore silent refresh failures */
    }
  }

  void setFilter(NotificationFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  void _onSocketNotification(Map<String, dynamic> data) {
    try {
      final incoming = AppNotificationModel.fromJson(data);
      final exists = state.notifications.any((n) => n.id == incoming.id);
      if (exists) {
        _badgeCubit.refresh();
        return;
      }
      final updated = [incoming, ...state.notifications];
      final unread = incoming.read
          ? state.unreadCount
          : state.unreadCount + 1;
      emit(
        state.copyWith(
          notifications: updated,
          unreadCount: unread,
          isLoading: false,
        ),
      );
      _badgeCubit.setCount(unread);
    } catch (_) {
      // Fallback: refresh from API if payload shape differs.
      load();
    }
  }

  Future<void> markRead(AppNotificationModel notification) async {
    if (notification.read) return;
    try {
      await _repository.markAsRead(notification.id);
      _updateNotification(notification.id, read: true);
    } on AppException {
      // Keep UI responsive — tap navigation should not depend on this.
    }
  }

  Future<void> markUnread(AppNotificationModel notification) async {
    if (!notification.read) return;
    try {
      await _repository.markAsUnread(notification.id);
      _updateNotification(notification.id, read: false);
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  void _updateNotification(String id, {required bool read}) {
    final updated = state.notifications
        .map(
          (n) => n.id == id
              ? AppNotificationModel(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  read: read,
                  createdAt: n.createdAt,
                  actorName: n.actorName,
                  metadata: n.metadata,
                )
              : n,
        )
        .toList();
    final unreadDelta = read ? -1 : 1;
    final unread = (state.unreadCount + unreadDelta).clamp(0, 999);
    emit(
      state.copyWith(
        notifications: updated,
        unreadCount: unread,
      ),
    );
    _badgeCubit.setCount(unread);
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllAsRead();
      final updated = state.notifications
          .map(
            (n) => AppNotificationModel(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              read: true,
              createdAt: n.createdAt,
              actorName: n.actorName,
              metadata: n.metadata,
            ),
          )
          .toList();
      emit(state.copyWith(notifications: updated, unreadCount: 0));
      _badgeCubit.clear();
    } on AppException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }

  @override
  Future<void> close() {
    _notifSub?.cancel();
    _badgeSub?.cancel();
    return super.close();
  }
}
