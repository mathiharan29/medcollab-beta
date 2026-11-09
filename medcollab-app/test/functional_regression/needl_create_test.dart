// Needl: pick 2+ people → create; if someone has not accepted a request,
// offer to send requests instead of a dead-end error.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_request_model.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_request_repository.dart';
import 'package:medcollab_app/features/messages/presentation/pages/start_dm_page.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

import 'fakes/chat_fakes.dart';

const _bala = UserModel(id: 'u-bala', name: 'Bala', displayTitle: 'Dr');
const _chitra = UserModel(id: 'u-chitra', name: 'Chitra', displayTitle: 'Dr');
const _dev = UserModel(id: 'u-dev', name: 'Dev', displayTitle: 'Dr');

class _Channels extends ChannelRepository {
  _Channels() : super(apiClient: isolatedApiClient());

  bool refuse = false;
  List<String>? lastGroup;

  @override
  Future<List<ChannelModel>> getMyDMs() async => const [
        ChannelModel(id: 'dm1', name: '', type: ChannelType.direct, peer: _bala),
        ChannelModel(id: 'dm2', name: '', type: ChannelType.direct, peer: _chitra),
        ChannelModel(id: 'dm3', name: '', type: ChannelType.direct, peer: _dev),
      ];

  @override
  Future<ChannelModel> createGroupDm(List<String> userIds) async {
    lastGroup = userIds;
    if (refuse) {
      throw const ForbiddenException(
          'Dr Dev needs to accept a message request from you before joining a Needl');
    }
    return ChannelModel(
      id: 'needl-1',
      name: 'Dr Bala, Dr Chitra',
      type: ChannelType.direct,
      isNeedl: true,
      members: const [_bala, _chitra, UserModel(id: 'me', name: 'Me')],
    );
  }
}

class _Users extends UserRepository {
  _Users() : super(apiClient: isolatedApiClient());

  @override
  Future<UserLookupResult> getRelationship(String userId) async {
    final user = [_bala, _chitra, _dev].firstWhere((u) => u.id == userId);
    // Bala: chats with me. Chitra: request pending. Dev: never asked.
    return UserLookupResult(
      user: user,
      relationship: 'stranger',
      canMessage: userId == _bala.id,
      canRequest: userId == _dev.id,
      pendingRequest: userId == _chitra.id
          ? const PendingRequestHint(id: 'r1', direction: 'sent')
          : null,
    );
  }
}

class _Requests extends MessageRequestRepository {
  _Requests() : super(apiClient: isolatedApiClient());
  final sentTo = <String>[];

  @override
  Future<MessageRequestModel> sendRequest({
    required String toUserId,
    String? introMessage,
  }) async {
    sentTo.add(toUserId);
    return const MessageRequestModel(
      id: 'r2', status: 'pending', direction: 'sent', peer: _dev,
    );
  }
}

void main() {
  late _Channels channels;
  late _Requests requests;
  late AuthBloc auth;
  late FakeSocketClient socket;

  setUpAll(() {
    channels = _Channels();
    requests = _Requests();
    final deps = AppDependencies.instance;
    deps.channelRepository = channels;
    deps.userRepository = _Users();
    deps.messageRequestRepository = requests;
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    socket = FakeSocketClient();
    auth = AuthBloc(
      authRepository: AuthRepository(
        apiClient: isolatedApiClient(),
        storage: SecureStorageService(),
        socketClient: socket,
      ),
      userRepository: _Users(),
    );
    addTearDown(() async {
      await auth.close();
      await socket.disposeFake();
    });
    final router = GoRouter(initialLocation: AppRoutes.startDm, routes: [
      GoRoute(path: AppRoutes.startDm, builder: (_, __) => const StartDmPage()),
      GoRoute(
        path: AppRoutes.dm,
        builder: (_, s) => Scaffold(body: Text('Opened ${s.pathParameters['channelId']}')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String name) async {
    final tile = find.ancestor(
      of: find.text(name),
      matching: find.byType(Row),
    ).first;
    await tester.tap(find.descendant(of: tile, matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
  }

  testWidgets('pick two people → "Create Needl" opens the new Needl',
      (tester) async {
    channels.refuse = false;
    await pumpPage(tester);
    await select(tester, 'Dr Bala');
    await select(tester, 'Dr Chitra');
    expect(find.text('Create Needl'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'Create Needl'));
    await tester.pumpAndSettle();
    expect(channels.lastGroup, unorderedEquals([_bala.id, _chitra.id]));
    expect(find.text('Opened needl-1'), findsOneWidget);
  });

  testWidgets('someone not connected → offer requests; pending ones listed',
      (tester) async {
    channels.refuse = true;
    requests.sentTo.clear();
    await pumpPage(tester);
    await select(tester, 'Dr Bala');
    await select(tester, 'Dr Chitra');
    await select(tester, 'Dr Dev');
    await tester.tap(find.widgetWithText(TextButton, 'Create Needl'));
    await tester.pumpAndSettle();

    expect(find.text('Send message requests?'), findsOneWidget);
    expect(find.textContaining('Dr Dev needs to accept'), findsOneWidget);
    expect(find.textContaining('Already waiting: Dr Chitra'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(requests.sentTo, [_dev.id],
        reason: 'only the person never asked gets a request');
    expect(find.textContaining('Requests sent'), findsOneWidget);
    expect(find.textContaining('Could not'), findsNothing);
  });
}
