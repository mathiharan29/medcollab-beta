import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/messages/data/models/message_request_model.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_request_repository.dart';
import 'package:medcollab_app/features/messages/presentation/pages/start_dm_page.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

import 'fakes/chat_fakes.dart';

const _peer = UserModel(id: 'doctor-peer', name: 'Doctor Peer');
const _channel = ChannelModel(id: 'dm-accepted-synthetic', name: 'Doctor Peer');

class _Lookups extends UserRepository {
  _Lookups() : super(apiClient: isolatedApiClient());

  String phase = 'canRequest';
  final phones = <String>[];

  @override
  Future<UserLookupResult> lookupByPhone(String phoneE164) async {
    phones.add(phoneE164);
    return UserLookupResult(
      user: _peer,
      relationship: phase == 'canMessage' ? 'connected' : 'stranger',
      canMessage: phase == 'canMessage',
      canRequest: phase == 'canRequest',
      pendingRequest: phase == 'sent' || phase == 'received'
          ? PendingRequestHint(id: 'request-synthetic', direction: phase)
          : null,
    );
  }
}

class _Requests extends MessageRequestRepository {
  _Requests() : super(apiClient: isolatedApiClient());

  int sendCalls = 0;
  int acceptCalls = 0;
  final recipients = <String>[];
  final intros = <String?>[];

  @override
  Future<MessageRequestModel> sendRequest({
    required String toUserId, String? introMessage,
  }) async {
    sendCalls++;
    recipients.add(toUserId);
    intros.add(introMessage);
    if (sendCalls == 1) {
      throw const ServerException('Synthetic request failed');
    }
    return const MessageRequestModel(
      id: 'request-synthetic', status: 'pending', direction: 'sent', peer: _peer,
    );
  }

  @override
  Future<AcceptMessageRequestResult> acceptRequest(String id) async {
    acceptCalls++;
    expect(id, 'request-synthetic');
    if (acceptCalls == 1) {
      throw const ServerException('Synthetic accept failed');
    }
    return const AcceptMessageRequestResult(
      request: MessageRequestModel(
        id: 'request-synthetic', status: 'accepted',
        direction: 'received', peer: _peer,
      ),
      channel: _channel,
    );
  }
}

void main() {
  testWidgets('FR-REQ-06: lookup request states, retry and accepted chat route',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final lookups = _Lookups();
    final requests = _Requests();
    AppDependencies.instance.userRepository = lookups;
    AppDependencies.instance.messageRequestRepository = requests;
    final socket = FakeSocketClient();
    final auth = AuthBloc(
      authRepository: AuthRepository(
        apiClient: isolatedApiClient(), storage: SecureStorageService(),
        socketClient: socket,
      ),
      userRepository: lookups,
    );
    addTearDown(() async {
      await auth.close();
      await socket.disposeFake();
    });
    final router = GoRouter(initialLocation: AppRoutes.startDm, routes: [
      GoRoute(path: AppRoutes.startDm, builder: (_, __) => const StartDmPage()),
      GoRoute(path: AppRoutes.dm, builder: (_, state) => Scaffold(
        body: Text('Opened ${state.pathParameters['channelId']}'),
      )),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth, child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
    final search = find.byType(TextField).first;
    await tester.enterText(search, '9000000001');
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    await tester.pump();
    expect(lookups.phones, ['+919000000001']);
    final sendActionVisible = find.text('Send request').evaluate().isNotEmpty;
    expect(requests.sendCalls, 0);
    lookups.phase = 'sent';
    await tester.enterText(search, '9000000002');
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    await tester.pump();
    expect(find.text('Request pending'), findsOneWidget);
    expect(find.text('Accept & chat'), findsNothing);

    lookups.phase = 'received';
    await tester.enterText(search, '9000000003');
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pumpAndSettle();
    expect(find.text('Accept & chat'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    await tester.tap(find.text('Accept & chat'));
    await tester.pump();
    expect(requests.acceptCalls, 1);
    expect(find.text('Synthetic accept failed'), findsOneWidget);
    expect(find.text('Accept & chat'), findsOneWidget,
        reason: 'Failed acceptance must remain retryable');
    await tester.tap(find.text('Accept & chat'));
    await tester.pumpAndSettle();
    expect(requests.acceptCalls, 2);
    expect(find.text('Opened dm-accepted-synthetic'), findsOneWidget,
        reason: 'Acceptance must navigate to the returned channel ID');

    expect(sendActionVisible, isTrue,
        reason: 'A requestable lookup must show an enabled Send request CTA');
  });
}
