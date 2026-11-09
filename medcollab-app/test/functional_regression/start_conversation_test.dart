// REQ 11: every "Message" button goes through startConversation, which must
// never dead-end on "Could not start conversation" for someone you have not
// chatted with yet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:medcollab_app/features/messages/presentation/utils/start_conversation.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';

const _peer = UserModel(id: 'u2', name: 'Bala Rao', displayTitle: 'Dr');
const _dm = ChannelModel(id: 'dm1', name: '', type: ChannelType.direct);

UserLookupResult _relation({
  bool canMessage = false,
  bool canRequest = false,
  PendingRequestHint? pending,
}) =>
    UserLookupResult(
      user: _peer,
      relationship: 'stranger',
      canMessage: canMessage,
      canRequest: canRequest,
      acceptsMessageRequests: canRequest,
      pendingRequest: pending,
    );

Future<StartConversationOutcome?> _run(
  WidgetTester tester, {
  required OpenDm openDm,
  LoadRelationship? relation,
  AcceptRequest? accept,
  Future<void> Function(WidgetTester)? interact,
}) async {
  StartConversationOutcome? outcome;
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              outcome = await startConversation(
                context,
                userId: 'u2',
                peerName: 'Dr Bala Rao',
                openDm: openDm,
                loadRelationship: relation ?? (_) async => _relation(),
                acceptRequest: accept ?? (_) async => _dm,
              );
            },
            child: const Text('Message'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/dm/:channelId',
      builder: (_, s) =>
          Scaffold(body: Text('CHAT ${s.pathParameters['channelId']}')),
    ),
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('Message'));
  await tester.pumpAndSettle();
  if (interact != null) await interact(tester);
  return outcome;
}

void main() {
  testWidgets('existing chat opens directly', (tester) async {
    final outcome = await _run(tester, openDm: (_) async => _dm);
    expect(outcome, StartConversationOutcome.opened);
    expect(find.text('CHAT dm1'), findsOneWidget);
  });

  testWidgets('stranger: offers a message request instead of an error',
      (tester) async {
    await _run(
      tester,
      openDm: (_) async =>
          throw const ForbiddenException('Send a message request first'),
      relation: (_) async => _relation(canRequest: true),
    );
    expect(find.text('Message request to Dr Bala Rao'), findsOneWidget);
    expect(find.text('Send request'), findsOneWidget);
    expect(find.textContaining('Could not start'), findsNothing);
  });

  testWidgets('request already sent: says so', (tester) async {
    final outcome = await _run(
      tester,
      openDm: (_) async => throw const ForbiddenException('x'),
      relation: (_) async => _relation(
        canRequest: false,
        pending: const PendingRequestHint(id: 'r1', direction: 'sent'),
      ),
    );
    expect(outcome, StartConversationOutcome.requestPending);
    expect(find.textContaining('Request already sent'), findsOneWidget);
  });

  testWidgets('they sent me a request: Accept & chat opens the DM',
      (tester) async {
    String? accepted;
    final outcome = await _run(
      tester,
      openDm: (_) async => throw const ForbiddenException('x'),
      relation: (_) async => _relation(
        pending: const PendingRequestHint(
          id: 'r9',
          direction: 'received',
          introMessage: 'Need a consult',
        ),
      ),
      accept: (id) async {
        accepted = id;
        return _dm;
      },
      interact: (t) async {
        expect(find.textContaining('Need a consult'), findsOneWidget);
        await t.tap(find.text('Accept & chat'));
        await t.pumpAndSettle();
      },
    );
    expect(accepted, 'r9');
    expect(outcome, StartConversationOutcome.opened);
    expect(find.text('CHAT dm1'), findsOneWidget);
  });

  testWidgets('unexpected error shows a retry message, not a dead end',
      (tester) async {
    final outcome = await _run(
      tester,
      openDm: (_) async => throw TypeError(),
    );
    expect(outcome, StartConversationOutcome.failed);
    expect(find.text('Could not open the chat. Please try again.'),
        findsOneWidget);
  });

  testWidgets('server reason is shown for other API errors', (tester) async {
    await _run(
      tester,
      openDm: (_) async => throw const NotFoundException('User not found'),
    );
    expect(find.text('User not found'), findsOneWidget);
  });
}
