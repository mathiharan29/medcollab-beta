import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/core/storage/draft_message_service.dart';
import 'package:medcollab_app/core/storage/bookmark_service.dart';
import 'package:medcollab_app/core/storage/recent_items_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_request_repository.dart';
import 'package:medcollab_app/features/messages/presentation/pages/start_dm_page.dart';
import 'package:medcollab_app/features/messages/presentation/pages/channel_chat_page.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/needl_manage_sheets.dart';
import 'package:medcollab_app/features/messages_hub/presentation/pages/messages_hub_page.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/dm_row.dart';
import 'fakes/chat_fakes.dart';

Map<String, dynamic> user(String id) =>
    {'_id': id, 'name': 'Doctor $id', 'role': 'intern'};
Map<String, dynamic> group(
        [String id = 'g1', List<String> ids = const ['A', 'B', 'C']]) =>
    {
      '_id': id,
      'name': 'Night Team',
      'type': 'direct',
      'spaceId': null,
      'isNeedl': true,
      'members': ids.map(user).toList(),
      'peer': user('B')
    };
ResponseBody reply(Map<String, dynamic> data, {int status = 200}) =>
    ResponseBody.fromString(
        jsonEncode({
          'success': status < 400,
          'message': status < 400 ? 'Synthetic success' : 'Synthetic failure',
          'data': data
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

class _MemoryStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
}

class _Transport implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  FutureOr<ResponseBody?> Function(RequestOptions)? handler;
  List<Map<String, dynamic>> dms = [
    group('g1', ['A', 'B', 'C', 'D'])
  ];
  List<Map<String, dynamic>> searchUsers = [user('B'), user('C')];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancel) async {
    calls.add(options);
    final controlled = await handler?.call(options);
    if (controlled != null) return controlled;
    final p = options.path;
    if (p.endsWith('/channels/dm') && options.method == 'GET')
      return reply({'channels': dms});
    if (p.endsWith('/dm/group') ||
        p.endsWith('/group-dm') ||
        p.endsWith('/expand')) return reply({'channel': group('created')});
    if (p.endsWith('/users/search')) return reply({'users': searchUsers});
    if (p.contains('lookup'))
      return reply({
        'user': user('E'),
        'relationship': 'stranger',
        'canMessage': false,
        'canRequest': true
      });
    if (p.endsWith('/members'))
      return reply({
        'members': ['A', 'B', 'C'].map(user).toList()
      });
    if (RegExp(r'/channels/[^/]+$').hasMatch(p))
      return reply({
        'channel': {
          ...group(),
          if (options.method == 'PUT') 'name': (options.data as Map)['name'],
          'pinnedMessages': []
        }
      });
    if (p.endsWith('/messages'))
      return reply({
        'messages': [
          {
            '_id': 'm1',
            'channelId': 'g1',
            'senderId': user('B'),
            'type': 'text',
            'content': {'text': 'Synthetic group message'},
            'createdAt': '2026-11-01T00:00:00Z'
          }
        ],
        'hasMore': false
      });
    if (p.contains('/messages/')) return reply({'count': 0});
    if (p.contains('/notifications'))
      return reply({
        'notifications': [],
        'count': 0,
        'unreadCount': 0,
        'hasMore': false
      });
    if (p.contains('/message-requests'))
      return reply({'requests': [], 'hasMore': false});
    if (p.contains('/spaces')) return reply({'spaces': []});
    if (p.contains('/handoffs'))
      return reply({'handoffs': [], 'hasMore': false});
    throw StateError('Unexpected isolated Needl request ${options.method} $p');
  }

  @override
  void close({bool force = false}) {}
}

class _SignedIn extends AuthBloc {
  _SignedIn(ApiClient api, FakeSocketClient socket)
      : super(
            authRepository: AuthRepository(
                apiClient: api,
                storage: _MemoryStorage(),
                socketClient: socket),
            userRepository: UserRepository(apiClient: api));
  @override
  AuthState get state => const AuthState(
      user: UserModel(id: 'A', name: 'Doctor A', isOnboarded: true));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final transport = _Transport(), socket = FakeSocketClient();
  late ApiClient api;
  late ChannelRepository channels;
  late _SignedIn auth;
  late PresenceCubit presence;
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'http://synthetic.invalid'));
    dio.httpClientAdapter = transport;
    api = ApiClient(storage: _MemoryStorage(), dio: dio);
    channels = ChannelRepository(apiClient: api);
    auth = _SignedIn(api, socket);
    presence = PresenceCubit(socketClient: socket);
    final d = AppDependencies.instance;
    d.apiClient = api;
    d.channelRepository = channels;
    d.userRepository = UserRepository(apiClient: api);
    d.memberRepository = MemberRepository(apiClient: api);
    d.authBloc = auth;
    d.socketClient = socket;
    d.presenceCubit = presence;
    d.spaceRepository = SpaceRepository(apiClient: api);
    d.messageRequestRepository = MessageRequestRepository(apiClient: api);
    d.notificationRepository = NotificationRepository(apiClient: api);
    d.handoffRepository = HandoffRepository(apiClient: api);
    d.draftMessageService = DraftMessageService();
    d.bookmarkService = BookmarkService();
    d.recentItemsService = RecentItemsService();
    d.messageRepository = MessageRepository(apiClient: api);
    d.mediaRepository = MediaRepository(apiClient: api);
    d.notificationBadgeCubit = NotificationBadgeCubit(
        repository: d.notificationRepository, socketClient: socket);
    d.navBadgesCubit = NavBadgesCubit(
        notificationRepository: d.notificationRepository,
        handoffRepository: d.handoffRepository,
        notificationBadgeCubit: d.notificationBadgeCubit,
        socketClient: socket);
  });
  setUp(() {
    transport.calls.clear();
    transport.handler = null;
    transport.dms = [
      group('g1', ['A', 'B', 'C', 'D'])
    ];
    transport.searchUsers = [user('B'), user('C')];
    SharedPreferences.setMockInitialValues({});
  });
  tearDownAll(() async {
    await AppDependencies.instance.navBadgesCubit.close();
    await AppDependencies.instance.notificationBadgeCubit.close();
    await presence.close();
    await auth.close();
    await socket.disposeFake();
  });
  Future<GoRouter> mount(WidgetTester t, Widget page) async {
    await t.pumpWidget(const SizedBox.shrink());
    t.view.physicalSize = const Size(1200, 1800);
    t.view.devicePixelRatio = 1;
    final router = GoRouter(initialLocation: '/subject', routes: [
      GoRoute(path: '/subject', builder: (_, __) => page),
      GoRoute(path: AppRoutes.startDm, builder: (_, __) => const StartDmPage()),
      GoRoute(
          path: AppRoutes.dm,
          builder: (_, s) =>
              Scaffold(body: Text('Opened ${s.pathParameters['channelId']}')))
    ]);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      router.dispose();
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    await t.pumpWidget(MultiBlocProvider(providers: [
      BlocProvider<AuthBloc>.value(value: auth),
      BlocProvider<PresenceCubit>.value(value: presence)
    ], child: MaterialApp.router(routerConfig: router)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    return router;
  }

  Widget launcher() => Scaffold(
      body: Builder(
          builder: (context) => Column(children: [
                TextButton(
                    onPressed: () => showAddNeedlPeopleSheet(context,
                        channel: ChannelModel.fromJson(group()),
                        existingMembers: ['A', 'B', 'C']
                            .map((id) => UserModel.fromJson(user(id)))
                            .toList()),
                    child: const Text('Add people')),
                TextButton(
                    onPressed: () => showRenameNeedlDialog(context,
                        channelId: 'g1', currentName: 'Night Team'),
                    child: const Text('Rename')),
                TextButton(
                    onPressed: () => showNeedlMembersSheet(context,
                        members: ['C', 'A', 'B']
                            .map((id) => UserModel.fromJson(user(id)))
                            .toList(),
                        title: 'Night Team'),
                    child: const Text('Members'))
              ])));
  Future<void> openAdd(WidgetTester t) async {
    await mount(t, launcher());
    await t.tap(find.text('Add people'));
    await t.pumpAndSettle();
  }

  Future<void> chooseTwo(WidgetTester t) async {
    await t.tap(find.byType(Checkbox).at(0));
    await t.pump();
    await t.tap(find.byType(Checkbox).at(1));
    await t.pump();
  }

  List<RequestOptions> creates() => transport.calls
      .where(
          (r) => r.path.endsWith('/dm/group') || r.path.endsWith('/group-dm'))
      .toList();
  List<RequestOptions> expands() =>
      transport.calls.where((r) => r.path.endsWith('/expand')).toList();

  test('FR-NDL-31 classify and label actual Needl models', () {
    for (final n in [1, 2])
      expect(
          ChannelModel.fromJson({
            ...group(),
            'isNeedl': false,
            'members': List.generate(n, (i) => user('$i'))
          }).isGroupDm,
          false);
    expect(ChannelModel.fromJson({...group(), 'spaceId': 'space'}).isGroupDm,
        false);
    expect(ChannelModel.fromJson({...group(), 'members': []}).isGroupDm, true);
    expect(ChannelModel.fromJson(group()).displayName, 'Night Team');
    final stale = ChannelModel.fromJson({...group(), 'name': 'Doctor B'});
    expect(stale.displayName, contains('Doctor C'));
    expect(stale.displayName, isNot('Doctor B'));
    expect(
        ChannelModel.fromJson({...group(), 'name': 'channel', 'members': []})
            .displayName,
        'Needl');
    expect(stale.copyWith(name: 'Custom').displayName, 'Custom');
    expect(stale.copyWith(name: 'Custom').members, stale.members);
  });
  test('FR-NDL-32 create group repository contract', () async {
    final result = await channels.createGroupDm(['B', 'C']);
    expect(result.id, 'created');
    expect(result.isGroupDm, true);
    expect(creates().single.data, {
      'userIds': ['B', 'C']
    });
    expect(result.members.map((u) => u.id), ['A', 'B', 'C']);
  });
  test('FR-NDL-33 alias only on 404, no retry for other failures', () async {
    transport.handler =
        (r) => r.path.endsWith('/dm/group') ? reply({}, status: 404) : null;
    expect((await channels.createGroupDm(['B', 'C'])).id, 'created');
    expect(creates().map((r) => r.path.split('/').last), ['group', 'group-dm']);
    for (final status in [400, 403, 500]) {
      transport.calls.clear();
      transport.handler = (r) => reply({}, status: status);
      await expectLater(
          channels.createGroupDm(['B', 'C']), throwsA(isA<AppException>()));
      expect(creates().length, 1);
    }
  });
  test('FR-NDL-34 serialize history and phone midnight', () async {
    for (final mode in ['all', 'today', 'none']) {
      final before = DateTime.now();
      final result = await channels.expandDm(
          channelId: 'g1', userIds: ['D'], history: mode);
      final after = DateTime.now();
      final payload = expands().last.data as Map;
      expect(payload['userIds'], ['D']);
      expect(payload['history'], mode);
      expect(result.id, 'created');
      if (mode == 'today') {
        final start = DateTime.parse(payload['todayStart'] as String);
        expect(start.isUtc, true);
        expect([
          DateTime(before.year, before.month, before.day).toUtc(),
          DateTime(after.year, after.month, after.day).toUtc()
        ], contains(start));
      } else
        expect(payload.containsKey('todayStart'), false);
    }
  });
  test('FR-NDL-35 list detail members rename and malformed response', () async {
    expect((await channels.getMyDMs()).single.id, 'g1');
    expect((await channels.getChannelMembers('g1')).map((u) => u.id),
        ['A', 'B', 'C']);
    expect((await channels.renameChannel('g1', 'Renamed')).name, 'Renamed');
    expect(transport.calls.last.method, 'PUT');
    expect(transport.calls.last.data, {'name': 'Renamed'});
    await channels.getChannelById('g1');
    transport.handler = (r) => reply({'channel': null});
    await expectLater(
        channels.getChannelById('g1'), throwsA(isA<AppException>()));
  });
  testWidgets('FR-NDL-36 Needl tab excludes pair notes and space channels',
      (t) async {
    transport.dms = [
      group(),
      {
        ...group('pair', ['A', 'B']),
        'isNeedl': false,
        'name': 'Pair only'
      },
      {
        ...group('notes', ['A']),
        'isNeedl': false,
        'name': 'Personal notes'
      },
      {...group('space'), 'spaceId': 's', 'name': 'Space channel'}
    ];
    transport.handler = (r) => r.path.endsWith('/notifications')
        ? reply({
            'notifications': [
              for (var i = 0; i < 2; i++)
                {
                  '_id': 'needl-notification-$i',
                  'type': 'new_message',
                  'read': false,
                  'metadata': {'channelId': 'g1'}
                },
              {
                '_id': 'other-chat',
                'type': 'new_message',
                'read': false,
                'metadata': {'channelId': 'pair'}
              }
            ],
            'hasMore': false,
            'unreadCount': 3
          })
        : null;
    await AppDependencies.instance.draftMessageService
        .saveDraft('g1', 'Synthetic draft');
    await mount(t, const MessagesHubPage());
    await t.tap(find.text('Needl'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('needl-g1')), findsOneWidget);
    for (final id in ['pair', 'notes', 'space'])
      expect(find.byKey(ValueKey('needl-$id')), findsNothing);
    expect(find.textContaining('3 people'), findsOneWidget);
    expect(find.textContaining('Draft'), findsWidgets);
    expect(
        t.widget<DMRow>(find.byKey(const ValueKey('needl-g1'))).unreadCount, 2);
  });
  testWidgets('FR-NDL-37 empty Needl create and failed load recovery',
      (t) async {
    transport.dms = [];
    await mount(t, const MessagesHubPage());
    await t.tap(find.text('Needl'));
    await t.pumpAndSettle();
    expect(find.text('No Needls yet'), findsOneWidget);
    await t.tap(find.text('Start a Needl'));
    await t.pumpAndSettle();
    expect(find.byType(StartDmPage), findsOneWidget);
    transport.handler =
        (r) => r.path.endsWith('/channels/dm') ? reply({}, status: 500) : null;
    await mount(t, const MessagesHubPage());
    await t.tap(find.text('Needl'));
    await t.pumpAndSettle();
    expect(find.text('Could not load Needls'), findsOneWidget);
    transport.handler = null;
    transport.dms = [group()];
    await mount(t, const MessagesHubPage());
    await t.tap(find.text('Needl'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('needl-g1')), findsOneWidget);
  });
  testWidgets('FR-NDL-38 colleague preload excludes self and duplicates',
      (t) async {
    transport.dms = [
      group('g1', ['A', 'B', 'B', 'C']),
      group('g2', ['A', 'C', 'D'])
    ];
    await mount(t, const StartDmPage());
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('Doctor A'), findsNothing);
    expect(find.text('Doctor B'), findsOneWidget);
    expect(find.text('Doctor C'), findsOneWidget);
    expect(transport.calls.any((r) => r.path.contains('contacts')), false);
  });
  testWidgets('FR-NDL-39 Start DM debounce and stale response ordering',
      (t) async {
    final old = Completer<ResponseBody>();
    transport.handler = (r) {
      if (r.path.endsWith('/users/search'))
        return r.queryParameters['q'] == 'Be'
            ? old.future
            : reply({
                'users': [user('Z')]
              });
      return null;
    };
    await mount(t, const StartDmPage());
    final input = find.byType(TextField).first;
    await t.enterText(input, 'Be');
    await t.pump(const Duration(milliseconds: 199));
    expect(transport.calls.where((r) => r.path.endsWith('/users/search')),
        isEmpty);
    await t.pump(const Duration(milliseconds: 2));
    await t.enterText(input, 'Ze');
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.text('Doctor Z'), findsOneWidget,
        reason:
            'New query must already be displayed before completing the older response');
    old.complete(reply({
      'users': [user('B')]
    }));
    await t.pumpAndSettle();
    expect(find.text('Doctor Z'), findsOneWidget);
    expect(find.text('Doctor B'), findsNothing);
  });
  testWidgets('FR-NDL-40 name search error and clear restore colleagues',
      (t) async {
    transport.handler =
        (r) => r.path.endsWith('/users/search') ? reply({}, status: 500) : null;
    await mount(t, const StartDmPage());
    await t.enterText(find.byType(TextField).first, 'failed');
    await t.pump(const Duration(milliseconds: 250));
    await t.pumpAndSettle();
    expect(find.text('Could not search colleagues'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '');
    await t.pumpAndSettle();
    expect(find.text('Your Vocle colleagues'), findsOneWidget);
    expect(find.text('Could not search colleagues'), findsNothing);
  });
  testWidgets('FR-NDL-41 exact selection and stale pair navigation guard',
      (t) async {
    await mount(t, const StartDmPage());
    await chooseTwo(t);
    transport.handler = (r) => r.path.endsWith('/dm/group')
        ? reply({
            'channel': {
              ...group('stale', ['A', 'B']),
              'isNeedl': false
            }
          })
        : null;
    await t.tap(find.text('Create Needl').last);
    await t.pumpAndSettle();
    expect(creates().single.data, {
      'userIds': ['B', 'C']
    });
    expect(find.textContaining('at least 2 other people'), findsOneWidget);
    expect(find.text('Opened stale'), findsNothing);
    transport.handler = null;
    await t.tap(find.text('Create Needl').last);
    await t.pumpAndSettle();
    expect(find.text('Opened created'), findsOneWidget);
  });
  testWidgets('FR-NDL-42 create failure retains selection then retry once',
      (t) async {
    var fail = true;
    transport.handler = (r) =>
        r.path.endsWith('/dm/group') && fail ? reply({}, status: 500) : null;
    await mount(t, const StartDmPage());
    await chooseTwo(t);
    await t.tap(find.text('Create Needl').last);
    await t.pumpAndSettle();
    expect(
        find
            .byType(Checkbox)
            .evaluate()
            .where((e) => (e.widget as Checkbox).value == true)
            .length,
        2);
    fail = false;
    await t.tap(find.text('Create Needl').last);
    await t.pumpAndSettle();
    expect(creates().length, 2);
    expect(find.text('Opened created'), findsOneWidget);
  });
  testWidgets('FR-NDL-43 second creation has fresh selection', (t) async {
    var creation = 0;
    transport.handler = (r) => r.path.endsWith('/dm/group')
        ? reply({'channel': group(++creation == 1 ? 'first' : 'second')})
        : null;
    final router = await mount(t, const StartDmPage());
    await chooseTwo(t);
    await t.tap(find.text('Create Needl').last);
    await t.pumpAndSettle();
    expect(find.text('Opened first'), findsOneWidget);
    router.go(AppRoutes.startDm);
    await t.pumpAndSettle();
    expect(
        find
            .byType(Checkbox)
            .evaluate()
            .every((e) => (e.widget as Checkbox).value == false),
        true);
    await t.tap(find.byType(Checkbox).at(1));
    await t.pump();
    await t.tap(find.byType(Checkbox).at(2));
    await t.pump();
    await t.tap(find.text('Create Needl').last);
    await t.pumpAndSettle();
    expect(creates().last.data, {
      'userIds': ['C', 'D']
    });
    expect(creates().first.data, {
      'userIds': ['B', 'C']
    });
    expect(find.text('Opened second'), findsOneWidget);
  });
  testWidgets('FR-NDL-44 add people preload sorted distinct eligible only',
      (t) async {
    transport.dms = [
      group('s', ['E', 'D', 'D', 'A', 'B'])
    ];
    await openAdd(t);
    expect(find.widgetWithText(CheckboxListTile, 'Doctor D'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Doctor E'), findsOneWidget);
    for (final id in ['A', 'B', 'C'])
      expect(find.widgetWithText(CheckboxListTile, 'Doctor $id'), findsNothing);
    expect(t.getTopLeft(find.text('Doctor D')).dy,
        lessThan(t.getTopLeft(find.text('Doctor E')).dy));
  });
  testWidgets('FR-NDL-45 add people one-character debounce and latest search',
      (t) async {
    final old = Completer<ResponseBody>();
    transport.handler = (r) => r.path.endsWith('/users/search')
        ? (r.queryParameters['q'] == 'd'
            ? old.future
            : reply({
                'users': [user('E')]
              }))
        : null;
    await openAdd(t);
    final input = find.byType(TextField).first;
    await t.enterText(input, 'd');
    await t.pump(const Duration(milliseconds: 201));
    await t.enterText(input, 'e');
    await t.pump(const Duration(milliseconds: 201));
    await t.pump();
    old.complete(reply({
      'users': [user('D')]
    }));
    await t.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Doctor E'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Doctor D'), findsNothing);
  });
  testWidgets('FR-NDL-46 add people phone normalization and existing exclusion',
      (t) async {
    await openAdd(t);
    await t.enterText(find.byType(TextField).first, '9000000001');
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    final lookup =
        transport.calls.singleWhere((r) => r.path.contains('lookup'));
    expect(jsonEncode(lookup.queryParameters) + jsonEncode(lookup.data),
        contains('+919000000001'));
    expect(find.widgetWithText(CheckboxListTile, 'Doctor E'), findsOneWidget);
    transport.handler = (r) => r.path.contains('lookup')
        ? reply({
            'user': user('B'),
            'canMessage': true,
            'canRequest': false,
            'relationship': 'connected'
          })
        : null;
    await t.enterText(find.byType(TextField).first, '9000000002');
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
  });
  testWidgets('FR-NDL-47 add people search failure is not empty success',
      (t) async {
    var fail = true;
    transport.handler = (r) => r.path.endsWith('/users/search')
        ? (fail
            ? reply({}, status: 500)
            : reply({
                'users': [user('E')]
              }))
        : null;
    await openAdd(t);
    await t.enterText(find.byType(TextField).first, 'e');
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.text('Synthetic failure'), findsOneWidget);
    expect(find.text('No colleagues found'), findsNothing);
    fail = false;
    await t.enterText(find.byType(TextField).first, 'el');
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Doctor E'), findsOneWidget);
  });
  testWidgets('FR-NDL-48 selected chips persist and delete disables submit',
      (t) async {
    await openAdd(t);
    await t.tap(find.widgetWithText(CheckboxListTile, 'Doctor D'));
    await t.pump();
    expect(find.byType(InputChip), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'unknown');
    await t.pump(const Duration(milliseconds: 210));
    await t.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
    final chip = t.widget<InputChip>(find.byType(InputChip));
    chip.onDeleted!();
    await t.pump();
    expect(find.byType(InputChip), findsNothing);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Add to Needl'))
            .onPressed,
        isNull);
  });
  testWidgets('FR-NDL-49 history selection and cancellation never submit',
      (t) async {
    await openAdd(t);
    expect(
        t
            .widget<RadioListTile<String>>(
                find.widgetWithText(RadioListTile<String>, 'Entire history'))
            .groupValue,
        'all');
    await t.tap(find.text('No history'));
    await t.pump();
    expect(
        t
            .widget<RadioListTile<String>>(
                find.widgetWithText(RadioListTile<String>, 'No history'))
            .groupValue,
        'none');
    await t.tap(find.text('From today'));
    await t.pump();
    expect(
        t
            .widget<RadioListTile<String>>(
                find.widgetWithText(RadioListTile<String>, 'From today'))
            .groupValue,
        'today');
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(expands(), isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets('FR-NDL-50 expansion pending duplicate taps failure and retry',
      (t) async {
    final pending = Completer<ResponseBody>();
    var first = true;
    transport.handler =
        (r) => r.path.endsWith('/expand') && first ? pending.future : null;
    await openAdd(t);
    await t.tap(find.widgetWithText(CheckboxListTile, 'Doctor D'));
    await t.pump();
    await t.tap(find.text('No history'));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Add to Needl'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(expands().length, 1);
    expect(t.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    pending.complete(reply({}, status: 500));
    await t.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
    expect(find.text('Synthetic failure'), findsOneWidget);
    first = false;
    await t.tap(find.widgetWithText(FilledButton, 'Add to Needl'));
    await t.pumpAndSettle();
    expect(expands().length, 2);
    expect((expands().last.data as Map)['history'], 'none');
    expect(t.takeException(), isNull,
        reason:
            'Successful expansion must navigate using a valid route context');
    expect(find.text('Opened created'), findsOneWidget);
  });
  testWidgets('FR-NDL-51 rename cancel trimming and 80 character bound',
      (t) async {
    await mount(t, launcher());
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(transport.calls.where((r) => r.method == 'PUT'), isEmpty);
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'N' * 81);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text.length,
        80);
    await t.enterText(find.byType(TextField), '  Updated team  ');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(transport.calls.singleWhere((r) => r.method == 'PUT').data,
        {'name': 'Updated team'});
    expect(find.text('Needl renamed'), findsOneWidget);
  });
  testWidgets('FR-NDL-52 rename error never shows success', (t) async {
    transport.handler =
        (r) => r.method == 'PUT' ? reply({}, status: 500) : null;
    await mount(t, launcher());
    await t.tap(find.text('Rename'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Failed name');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Synthetic failure'), findsOneWidget);
    expect(find.text('Needl renamed'), findsNothing);
    expect(transport.calls.singleWhere((r) => r.method == 'PUT').path,
        endsWith('/g1'));
  });
  testWidgets('FR-NDL-53 self-first members count roles and presence',
      (t) async {
    presence.mergeApiSnapshot({'B': const PresenceInfo(isOnline: true)});
    await mount(t, launcher());
    await t.tap(find.text('Members'));
    await t.pumpAndSettle();
    expect(find.text('Night Team · 3 people'), findsOneWidget);
    expect(t.getTopLeft(find.text('Doctor A (you)')).dy,
        lessThan(t.getTopLeft(find.text('Doctor B')).dy));
    expect(t.getTopLeft(find.text('Doctor B')).dy,
        lessThan(t.getTopLeft(find.text('Doctor C')).dy));
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(
        t
            .widget<ListTile>(find.widgetWithText(ListTile, 'Doctor A (you)'))
            .onTap,
        isNull);
    expect(
        find
            .byType(AppAvatar)
            .evaluate()
            .map((e) => e.widget as AppAvatar)
            .any((a) => a.isOnline),
        true);
  });
  testWidgets('FR-NDL-54 chat retains group identity and Needl menu',
      (t) async {
    await mount(
        t,
        ChannelChatPage(
            channelId: 'g1', channel: ChannelModel.fromJson(group())));
    await t.pumpAndSettle();
    expect(find.text('Night Team'), findsWidgets);
    expect(find.text('Synthetic group message'), findsOneWidget);
    expect(find.textContaining('Doctor B'), findsWidgets);
    await t.tap(find.byType(PopupMenuButton<String>).first);
    await t.pumpAndSettle();
    expect(find.text('Rename Needl'), findsOneWidget);
    expect(find.text('People in this Needl'), findsOneWidget);
  });
}
