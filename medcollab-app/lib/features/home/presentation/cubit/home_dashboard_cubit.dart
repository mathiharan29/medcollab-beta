import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/home/data/dashboard_preferences_service.dart';
import 'package:medcollab_app/features/home/presentation/cubit/home_dashboard_state.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';

class HomeDashboardCubit extends Cubit<HomeDashboardState> with SafeEmit<HomeDashboardState> {
  HomeDashboardCubit({
    required SpaceRepository spaceRepository,
    required HandoffRepository handoffRepository,
    required ChannelRepository channelRepository,
    required NotificationRepository notificationRepository,
    required RecentItemsService recentItemsService,
    required BookmarkService bookmarkService,
    required DashboardPreferencesService dashboardPreferencesService,
    required this.currentUserId,
    SocketClient? socketClient,
  })  : _spaceRepository = spaceRepository,
        _handoffRepository = handoffRepository,
        _channelRepository = channelRepository,
        _notificationRepository = notificationRepository,
        _recentItemsService = recentItemsService,
        _bookmarkService = bookmarkService,
        _dashboardPreferencesService = dashboardPreferencesService,
        _socketClient = socketClient,
        super(const HomeDashboardState()) {
    _listenHandoffAck();
    load();
  }

  final SpaceRepository _spaceRepository;
  final HandoffRepository _handoffRepository;
  final ChannelRepository _channelRepository;
  final NotificationRepository _notificationRepository;
  final RecentItemsService _recentItemsService;
  final BookmarkService _bookmarkService;
  final DashboardPreferencesService _dashboardPreferencesService;
  final SocketClient? _socketClient;
  final String currentUserId;

  StreamSubscription<Map<String, dynamic>>? _ackSub;

  void _listenHandoffAck() {
    final socket = _socketClient;
    if (socket == null) return;
    _ackSub = socket.onMapEvent(SocketEvents.handoffAcknowledged).listen((_) {
      // Silent refresh — keep UI snappy after ack elsewhere.
      load(silent: true);
    });
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final spacesFut = _spaceRepository.getMySpaces();
      final handoffsFut = _handoffRepository.getMyHandoffs();
      final notifFut = _notificationRepository.getNotifications(limit: 50);
      final recentSpacesFut = _recentItemsService.getRecentSpaces();
      final recentChannelsFut = _recentItemsService.getRecentChannels();
      final pinnedFut = _recentItemsService.getPinnedItems();
      final bookmarksFut = _bookmarkService.getAll();
      final prefsFut = _dashboardPreferencesService.load();
      final dmsFut = () async {
        try {
          return await _channelRepository.getMyDMs();
        } catch (_) {
          return <ChannelModel>[];
        }
      }();

      final spaces = await spacesFut;
      final handoffs = await handoffsFut;
      final notificationsPage = await notifFut;
      final recentSpaces = await recentSpacesFut;
      final recentChannels = await recentChannelsFut;
      final pinnedItems = await pinnedFut;
      final bookmarks = await bookmarksFut;
      final widgetPreferences = await prefsFut;
      final recentDms = await dmsFut;

      final notifications = notificationsPage.notifications;

      final pendingHandoffs = handoffs
          .where(
            (h) =>
                h.status == HandoffStatus.submitted &&
                h.toUser.id == currentUserId,
          )
          .length;

      final assignedHandoffs = handoffs
          .where(
            (handoff) =>
                handoff.toUser.id == currentUserId &&
                handoff.status == HandoffStatus.submitted,
          )
          .toList()
        ..sort((a, b) {
          final aPast = a.isShiftPast ? 1 : 0;
          final bPast = b.isShiftPast ? 1 : 0;
          if (aPast != bPast) return aPast.compareTo(bPast);
          return (b.lastUpdated ?? b.shiftDate ?? DateTime(0)).compareTo(
            a.lastUpdated ?? a.shiftDate ?? DateTime(0),
          );
        });

      final now = DateTime.now();
      final todayHandoffs = assignedHandoffs.where((handoff) {
        final date = handoff.shiftDate;
        return date != null &&
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList();

      final unreadMentions = notifications
          .where(
            (n) => !n.read && n.category == AppNotificationCategory.mention,
          )
          .length;

      final unreadThreads = notifications
          .where((n) => !n.read && n.category == AppNotificationCategory.reply)
          .length;

      final inviteCount = notifications
          .where((n) => !n.read && n.category == AppNotificationCategory.invite)
          .length;

      final hospitalAnnouncements = <AnnouncementPreview>[];
      final departmentAnnouncements = <AnnouncementPreview>[];
      final patientDiscussions = <PatientDiscussionPreview>[];
      for (final space in spaces) {
        for (final channel in space.channels) {
          if (channel.type == ChannelType.announcements &&
              channel.lastMessage?.text != null) {
            final preview = AnnouncementPreview(
              spaceName: space.name,
              channelName: channel.displayName,
              text: channel.lastMessage!.text!,
              spaceId: space.id,
              channelId: channel.id,
              sentAt: channel.lastMessage!.sentAt,
            );
            if (space.type == SpaceType.hospital) {
              hospitalAnnouncements.add(preview);
            } else if (space.type == SpaceType.department) {
              departmentAnnouncements.add(preview);
            }
          } else if (channel.type != ChannelType.direct &&
              channel.lastMessage?.text != null) {
            patientDiscussions.add(
              PatientDiscussionPreview(
                spaceName: space.name,
                channelName: channel.displayName,
                text: channel.lastMessage!.text!,
                spaceId: space.id,
                channelId: channel.id,
                senderName: channel.lastMessage!.senderName,
                sentAt: channel.lastMessage!.sentAt,
              ),
            );
          }
        }
      }
      int newestFirst(DateTime? a, DateTime? b) {
        final at = a ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      }

      hospitalAnnouncements.sort(
        (a, b) => newestFirst(a.sentAt, b.sentAt),
      );
      departmentAnnouncements.sort(
        (a, b) => newestFirst(a.sentAt, b.sentAt),
      );
      patientDiscussions.sort(
        (a, b) => newestFirst(a.sentAt, b.sentAt),
      );

      emit(
        state.copyWith(
          isLoading: false,
          spaces: spaces,
          handoffs: handoffs,
          unreadNotifications: notificationsPage.unreadCount,
          unreadMentions: unreadMentions,
          pendingHandoffs: pendingHandoffs,
          unreadThreads: unreadThreads,
          inviteCount: inviteCount,
          bookmarkCount: bookmarks.length,
          recentSpaces: recentSpaces,
          recentChannels: recentChannels,
          pinnedItems: pinnedItems,
          assignedHandoffs: assignedHandoffs.take(5).toList(),
          todayHandoffs: todayHandoffs,
          patientDiscussions: patientDiscussions.take(5).toList(),
          recentDms: recentDms.take(5).toList(),
          hospitalAnnouncements: hospitalAnnouncements.take(5).toList(),
          departmentAnnouncements: departmentAnnouncements.take(5).toList(),
          widgetPreferences: widgetPreferences,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (_) {
      emit(state.copyWith(isLoading: false, error: 'Could not load workspace'));
    }
  }

  Future<void> saveWidgetPreferences(
    List<DashboardWidgetPreference> preferences,
  ) async {
    await _dashboardPreferencesService.save(preferences);
    emit(state.copyWith(widgetPreferences: List.of(preferences)));
  }

  Future<void> resetWidgetPreferences() async {
    await _dashboardPreferencesService.reset();
    emit(
      state.copyWith(
        widgetPreferences: List.of(
          DashboardPreferencesService.defaultPreferences,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _ackSub?.cancel();
    return super.close();
  }
}
