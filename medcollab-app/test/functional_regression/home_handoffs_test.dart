import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/home/data/dashboard_preferences_service.dart';
import 'package:medcollab_app/features/home/presentation/cubit/home_dashboard_cubit.dart';
import 'package:medcollab_app/features/home/presentation/widgets/doctor_workspace_widgets.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/last_message_preview.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/chat_fakes.dart';

const _doctorA = UserModel(id: 'doctor-a', name: 'Doctor A');
const _doctorB = UserModel(id: 'doctor-b', name: 'Doctor B');
const _doctorC = UserModel(id: 'doctor-c', name: 'Doctor C');

class _Spaces extends SpaceRepository {
  _Spaces() : super(apiClient: isolatedApiClient());
  List<SpaceModel> server = const [];
  bool fail = false;
  @override
  Future<List<SpaceModel>> getMySpaces() async {
    if (fail) throw const ServerException('Synthetic workspace failure');
    return server;
  }
}

class _Channels extends ChannelRepository {
  _Channels() : super(apiClient: isolatedApiClient());
  bool fail = false;
  @override
  Future<List<ChannelModel>> getMyDMs() async {
    if (fail) throw const ServerException('Synthetic DM failure');
    return const [];
  }
}

class _Notifications extends NotificationRepository {
  _Notifications() : super(apiClient: isolatedApiClient());
  @override
  Future<NotificationsPageResult> getNotifications({
    bool unreadOnly = false, String? before, String? type, int limit = 30,
  }) async => const NotificationsPageResult(notifications: [], hasMore: false, unreadCount: 0);
}

class _Handoffs extends HandoffRepository {
  _Handoffs() : super(apiClient: isolatedApiClient());
  List<HandoffModel> server = [];
  int reads = 0;
  @override
  Future<List<HandoffModel>> getMyHandoffs({
    String? spaceId, String type = 'all', HandoffStatus? status,
  }) async {
    reads++;
    return List.of(server);
  }
}

HandoffModel _handoff(String id, UserModel assignee, HandoffStatus status,
    DateTime shiftDate) => HandoffModel(
  id: id,
  spaceId: 'space-synthetic-1',
  channelId: 'channel-synthetic-1',
  fromUser: _doctorA,
  toUser: assignee,
  shiftDate: shiftDate,
  shiftType: ShiftType.morning,
  shiftSummary: 'Synthetic shift $id',
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FR-HOME-02: assigned, shift and task cards follow refreshed handoffs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final handoffs = _Handoffs();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    handoffs.server = [
      _handoff('assigned', _doctorB, HandoffStatus.submitted, today),
      _handoff('other-doctor', _doctorC, HandoffStatus.submitted, today),
      _handoff('draft', _doctorB, HandoffStatus.draft, today),
    ];
    final dashboard = HomeDashboardCubit(
      spaceRepository: _Spaces(),
      handoffRepository: handoffs,
      channelRepository: _Channels(),
      notificationRepository: _Notifications(),
      recentItemsService: RecentItemsService(prefs: storage),
      bookmarkService: BookmarkService(prefs: storage),
      dashboardPreferencesService: DashboardPreferencesService(preferences: storage),
      currentUserId: _doctorB.id,
    );
    addTearDown(dashboard.close);
    await dashboard.load();
    expect(dashboard.state.isLoading, isFalse);
    expect(dashboard.state.error, isNull);
    expect(dashboard.state.assignedHandoffs.map((h) => h.id), ['assigned']);
    expect(dashboard.state.todayHandoffs.map((h) => h.id), ['assigned']);
    expect(dashboard.state.pendingHandoffs, 1);
    expect(dashboard.state.pendingTaskCount, 1);
    Future<void> renderCards() async {
      // Flutter 3.29.3's diagnostic-tree renderer can itself throw while
      // formatting a failed paint. Capture the original exception before that
      // formatting step, then explicitly fail; never suppress a render defect.
      final previousHandler = FlutterError.onError;
      final renderErrors = <String>[];
      FlutterError.onError = (details) {
        renderErrors.add('${details.exception}\n${details.stack}');
      };
      try {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
          child: Column(children: [
            TodayShiftWidget(handoffs: dashboard.state.todayHandoffs, onOpenHandoffs: () {}),
            AssignedHandoffsWidget(handoffs: dashboard.state.assignedHandoffs),
            PendingTasksWidget(state: dashboard.state),
          ]),
        ))));
      } finally {
        FlutterError.onError = previousHandler;
      }
      if (renderErrors.isNotEmpty) {
        throw TestFailure('Application card rendering failed:\n${renderErrors.join('\n')}');
      }
    }
    await renderCards();
    expect(find.text('Synthetic shift assigned'), findsOneWidget);
    expect(find.text('Handoffs awaiting action'), findsOneWidget);
    expect(find.text('No pending handoffs'), findsNothing);

    handoffs.server = [
      _handoff('assigned', _doctorB, HandoffStatus.acknowledged, today),
      _handoff('other-doctor', _doctorC, HandoffStatus.submitted, today),
    ];
    await dashboard.load(silent: true);
    expect(dashboard.state.assignedHandoffs, isEmpty);
    expect(dashboard.state.todayHandoffs, isEmpty);
    expect(dashboard.state.pendingHandoffs, 0);
    expect(dashboard.state.pendingTaskCount, 0);
    await renderCards();
    expect(find.text('No shift assignment for today'), findsOneWidget);
    expect(find.text('No pending handoffs'), findsOneWidget);
    expect(find.text('All caught up'), findsOneWidget);

    handoffs.server = [
      _handoff('assigned', _doctorC, HandoffStatus.submitted, today),
    ];
    await dashboard.load(silent: true);
    expect(dashboard.state.assignedHandoffs, isEmpty,
        reason: 'Reassigned handoff belongs to the new assignee');
    expect(dashboard.state.todayHandoffs, isEmpty);
    expect(dashboard.state.pendingTaskCount, 0);
    expect(handoffs.reads, greaterThanOrEqualTo(3));
  }, timeout: const Timeout(Duration(seconds: 45)));

  testWidgets('FR-HOME-03: announcements, emergency, partial failure and retry',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final spaces = _Spaces();
    final channels = _Channels();
    final dashboard = HomeDashboardCubit(
      spaceRepository: spaces,
      handoffRepository: _Handoffs(),
      channelRepository: channels,
      notificationRepository: _Notifications(),
      recentItemsService: RecentItemsService(prefs: prefs),
      bookmarkService: BookmarkService(prefs: prefs),
      dashboardPreferencesService:
          DashboardPreferencesService(preferences: prefs),
      currentUserId: _doctorB.id,
    );
    addTearDown(dashboard.close);
    await dashboard.load();
    expect(dashboard.state.error, isNull);
    expect(dashboard.state.spaces, isEmpty);
    expect(dashboard.state.hospitalAnnouncements, isEmpty);
    expect(dashboard.state.departmentAnnouncements, isEmpty);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: WorkspaceAnnouncementsWidget(
        title: 'Hospital announcements', announcements: [],
        emptyMessage: 'Announcements will appear here.',
      ),
    )));
    expect(find.text('No announcements'), findsOneWidget);

    spaces.server = const [
      SpaceModel(id: 'hospital-synthetic', name: 'Synthetic Hospital',
        type: SpaceType.hospital, channels: [
          ChannelModel(id: 'hospital-news', name: 'News',
            type: ChannelType.announcements,
            lastMessage: LastMessagePreview(text: 'Hospital announcement')),
          ChannelModel(id: 'hospital-emergency', name: 'Emergency',
            type: ChannelType.emergency,
            lastMessage: LastMessagePreview(text: 'Emergency discussion')),
        ]),
      SpaceModel(id: 'department-synthetic', name: 'Synthetic Department',
        type: SpaceType.department, channels: [
          ChannelModel(id: 'department-news', name: 'Department news',
            type: ChannelType.announcements,
            lastMessage: LastMessagePreview(text: 'Department announcement')),
        ]),
    ];
    channels.fail = true;
    await dashboard.load();
    expect(dashboard.state.error, isNull,
        reason: 'DM-only failure must not hide available workspace data');
    expect(dashboard.state.recentDms, isEmpty);
    expect(dashboard.state.hospitalAnnouncements.map((a) => a.channelId),
        ['hospital-news']);
    expect(dashboard.state.departmentAnnouncements.map((a) => a.channelId),
        ['department-news']);
    expect(dashboard.state.patientDiscussions.map((d) => d.channelId),
        ['hospital-emergency']);

    final router = GoRouter(initialLocation: '/home-test', routes: [
      GoRoute(path: '/home-test', builder: (_, __) => Scaffold(body: ListView(
        children: [
          WorkspaceAnnouncementsWidget(title: 'Hospital announcements',
            announcements: dashboard.state.hospitalAnnouncements,
            emptyMessage: 'None'),
          WorkspaceAnnouncementsWidget(title: 'Department announcements',
            announcements: dashboard.state.departmentAnnouncements,
            emptyMessage: 'None'),
          PatientDiscussionsWidget(
            discussions: dashboard.state.patientDiscussions),
        ],
      ))),
      GoRoute(path: '/spaces/:spaceId/channels/:channelId',
        builder: (_, state) => Scaffold(body: Text(
          'Opened ${state.pathParameters['spaceId']}/${state.pathParameters['channelId']}',
        ))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Hospital announcement'), findsOneWidget);
    expect(find.text('Department announcement'), findsOneWidget);
    await tester.tap(find.text('Hospital announcement'));
    await tester.pumpAndSettle();
    expect(find.text('Opened hospital-synthetic/hospital-news'), findsOneWidget);
    router.go('/home-test');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Emergency discussion'));
    await tester.tap(find.text('Emergency discussion'));
    await tester.pumpAndSettle();
    expect(find.text('Opened hospital-synthetic/hospital-emergency'),
        findsOneWidget);

    spaces.fail = true;
    await dashboard.load();
    expect(dashboard.state.isLoading, isFalse);
    expect(dashboard.state.error, 'Synthetic workspace failure');
    spaces.fail = false;
    await dashboard.load();
    expect(dashboard.state.isLoading, isFalse);
    expect(dashboard.state.error, isNull);
    expect(dashboard.state.hospitalAnnouncements.single.channelId,
        'hospital-news');
    expect(dashboard.state.departmentAnnouncements.single.channelId,
        'department-news');
  });
}
