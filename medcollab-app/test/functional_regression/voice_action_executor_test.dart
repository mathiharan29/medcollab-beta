import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/features/auth/data/models/availability_model.dart';
import 'package:medcollab_app/features/channels/data/repositories/channel_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_voice_note.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/notifications/data/repositories/notification_repository.dart';
import 'package:medcollab_app/features/notifications/presentation/cubit/notification_badge_cubit.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/repositories/space_repository.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_bot_repository.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';

import 'fakes/chat_fakes.dart';

const _peer = VoiceTarget(id: 'p:b', name: 'Dr Bala');
const _namesakes = [
  VoiceTarget(id: 'p:c', name: 'Dr Asha Rao', speciality: 'Cardiology'),
  VoiceTarget(id: 'p:d', name: 'Dr Asha Rao', speciality: 'Nephrology'),
];
const _group = VoiceTarget(id: 'c:needl', name: 'Ward Team', kind: 'needl');
const _channel = VoiceTarget(
    id: 'c:general', name: 'Ward General', kind: 'group', spaceId: 'ward');
final _confirm = find.byKey(const Key('voicebot-confirm'));

class _Speech implements SpeechService {
  final _sessions = <StreamController<SpeechEvent>>[];
  StreamController<SpeechEvent> get events => _sessions.last;
  bool stopped = false;
  @override
  Future<SpeechCapabilities> capabilities() async =>
      const SpeechCapabilities(available: true);
  @override
  Stream<SpeechEvent> listen({String language = 'en-IN'}) {
    final session = StreamController<SpeechEvent>(onCancel: () async {});
    _sessions.add(session);
    return session.stream;
  }

  Future<void> close() async {
    for (final session in _sessions) {
      await session.close();
    }
  }

  @override
  Future<void> stopListening() async => stopped = true;
  @override
  Future<void> cancelListening() async {}
  @override
  Future<void> speak(String text, {String language = 'en-IN'}) async {}
  @override
  Future<void> stopSpeaking() async {}
  @override
  Future<String?> transcribeFile(String path,
          {String language = 'en-IN'}) async =>
      null;
}

class _Alerts extends NotificationRepository {
  _Alerts() : super(apiClient: isolatedApiClient());
  int unread = 3;
  @override
  Future<void> markAllAsRead() async => unread = 0;
}

class _Users extends UserRepository {
  _Users() : super(apiClient: isolatedApiClient());
  AvailabilityStatus status = AvailabilityStatus.available;
  @override
  Future<AvailabilityModel> updateAvailability({
    required AvailabilityStatus status,
    DateTime? until,
    String? note,
  }) async {
    this.status = status;
    return AvailabilityModel.fromJson({'status': status.value});
  }
}

class _Channels extends ChannelRepository {
  _Channels() : super(apiClient: isolatedApiClient());

  final lookups = <String>[];
  bool denyDm = false;
  bool expired = false;

  @override
  Future<ChannelModel> createOrGetDM(String userId) async {
    lookups.add(userId);
    if (expired) throw const UnauthorizedException('Session expired');
    if (denyDm) throw const ForbiddenException('Consent required');
    return ChannelModel.fromJson({'_id': 'dm-$userId', 'name': 'Synthetic DM'});
  }
}

class _Handoffs extends HandoffRepository {
  _Handoffs() : super(apiClient: isolatedApiClient());

  final drafts = <Map<String, Object?>>[];

  @override
  Future<HandoffModel> createHandoff({
    required String spaceId,
    required String channelId,
    required String toUserId,
    required DateTime shiftDate,
    required ShiftType shiftType,
    List<HandoffPatientModel> patients = const [],
    String shiftSummary = '',
    HandoffVoiceNote? voiceNote,
  }) async {
    drafts.add({
      'spaceId': spaceId,
      'channelId': channelId,
      'toUserId': toUserId,
      'beds': patients.map((patient) => patient.bedNumber).toList(),
      'voiceNote': voiceNote,
    });
    return HandoffModel.fromJson({'_id': 'draft-1', 'status': 'draft'});
  }

  @override
  Future<HandoffModel> submitHandoff(String handoffId) async {
    throw TestFailure('Voice confirmation must only create a draft');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Channels channels;
  late _Handoffs handoffs;
  late FakeMessageRepository messages;
  late VoiceDirectoryLoader directory;
  late VoiceBotCubit bot;
  late GoRouter router;
  late _Speech speech;
  late _Alerts alerts;
  late _Users users;
  late NotificationBadgeCubit badge;

  Future<void> say(WidgetTester tester, String text) async {
    await bot.startListening();
    speech.events.add(SpeechFinal(text));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    expect(_confirm, findsOneWidget);
    await tester.ensureVisible(_confirm);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
  }

  Future<void> home(WidgetTester tester) async {
    router.go('/');
    await tester.pumpAndSettle();
  }

  setUp(() {
    final api = isolatedApiClient();
    final socket = FakeSocketClient();
    channels = _Channels();
    handoffs = _Handoffs();
    speech = _Speech();
    alerts = _Alerts();
    users = _Users();
    messages = FakeMessageRepository()
      ..onSendText = (text, _) async => MessageModel.fromJson({
            '_id': 'message',
            'content': {'text': text}
          });
    badge = NotificationBadgeCubit(repository: alerts, socketClient: socket);
    badge.setCount(alerts.unread);
    directory = VoiceDirectoryLoader(
      channels: channels,
      spaces: SpaceRepository(apiClient: api),
      members: MemberRepository(apiClient: api),
    );
    router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: BlocProvider.value(value: bot, child: const VoiceBotPanel()),
        ),
      ),
      GoRoute(
          path: AppRoutes.dm,
          builder: (_, state) =>
              Text('Conversation ${state.pathParameters['channelId']}')),
      GoRoute(
          path: AppRoutes.channel,
          builder: (_, state) => Text(
              'Group ${state.pathParameters['spaceId']}/${state.pathParameters['channelId']}')),
      for (final route in [
        AppRoutes.search,
        AppRoutes.notifications,
        AppRoutes.messages,
        AppRoutes.handoffs,
        AppRoutes.profile,
        AppRoutes.home
      ])
        GoRoute(path: route, builder: (_, __) => Text('Page $route')),
      GoRoute(
        path: '/spaces/:spaceId/handoffs/:handoffId/edit',
        builder: (_, state) =>
            Text('Edit ${state.pathParameters['handoffId']}'),
      ),
    ]);
    bot = VoiceBotCubit(
      speech: speech,
      loadDirectory: () async => const VoiceDirectory(
          people: [_peer, ..._namesakes], chats: [_group, _channel]),
      executor: AppVoiceActionExecutor(
        router: router,
        channels: channels,
        handoffs: handoffs,
        messages: messages,
        notifications: alerts,
        badge: badge,
        users: users,
        directory: directory,
      ),
    );
    addTearDown(() async {
      await bot.close();
      await speech.close();
      await badge.close();
      await socket.disposeFake();
      router.dispose();
    });
  });

  test(
      'FR-AST-23 confirmed DM and Needl commands use the correct message path and honor consent',
      () async {
    final sentText = <String>[];
    messages.onSendText = (text, _) async {
      sentText.add(text);
      return MessageModel.fromJson({
        '_id': 'synthetic',
        'content': {'text': text}
      });
    };

    channels.denyDm = true;
    await bot.handleText('tell Bala the check is complete');
    expect(channels.lookups, isEmpty);
    expect(messages.textSendCount, 0);
    await bot.confirm(bot.state.proposals.single);
    expect(bot.state.message, contains('accepted message request'));
    expect(messages.textSendCount, 0);
    expect(channels.lookups, ['b']);

    channels.denyDm = false;
    await bot.handleText('tell Bala the check is complete');
    await bot.confirm(bot.state.proposals.single);
    await bot.handleText('tell Ward Team that rounds start at eight');
    expect(messages.sentChannelIds, ['dm-b']);
    await bot.confirm(bot.state.proposals.single);
    expect(messages.sentChannelIds, ['dm-b', 'needl']);
    expect(sentText, ['The check is complete', 'Rounds start at eight']);
    expect(channels.lookups, ['b', 'b'],
        reason: 'A Needl command uses the existing group ID');
    expect(handoffs.drafts, isEmpty);
  });

  testWidgets(
      'FR-AST-24 a confirmed handoff opens a reviewable draft and requires a shared group',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    const command = 'handoff beds 7 and 12 to Bala';
    await say(tester, command);
    expect(handoffs.drafts, isEmpty);
    await bot.confirm(bot.state.proposals.single);
    expect(handoffs.drafts, isEmpty);
    expect(bot.state.message, contains('not in a group together'));

    directory.sharedGroups['b'] = [
      (spaceId: 'ward', channelId: 'general', name: 'Synthetic Ward')
    ];
    await say(tester, command);
    expect(handoffs.drafts, isEmpty);
    await confirm(tester);
    expect(handoffs.drafts.single, {
      'spaceId': 'ward',
      'channelId': 'general',
      'toUserId': 'b',
      'beds': ['7', '12'],
      'voiceNote': null,
    });
    expect(find.text('Edit draft-1'), findsOneWidget);
    expect(bot.state.message, contains('review it and tap Submit'));
    expect(messages.textSendCount, 0);
  });

  testWidgets(
      'FR-AST-26 final speech opens the exact person, Needl and space chat routes',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    const commands = {
      'Open Bala chat': 'Conversation dm-b',
      '  oPEN   CHAT with Dr. BALA?!  ': 'Conversation dm-b',
      'Open chat with Bal': 'Conversation dm-b',
      'Open Ward Team chat': 'Conversation needl',
      'Show conversation with Ward General.': 'Group ward/general',
    };
    for (final entry in commands.entries) {
      final before = channels.lookups.length;
      await say(tester, entry.key);
      expect(channels.lookups, hasLength(before));
      expect(find.text(entry.value), findsNothing);
      await confirm(tester);
      expect(find.text(entry.value), findsOneWidget);
      await home(tester);
    }
    expect(channels.lookups, ['b', 'b', 'b']);
    expect(messages.textSendCount, 0);
    expect(handoffs.drafts, isEmpty);
  });

  testWidgets(
      'FR-AST-27 unknown and ambiguous chat targets require explicit resolution and approval',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await say(tester, 'Open Zelda chat');
    expect(find.textContaining('could not find'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
    expect(_confirm, findsNothing);
    await say(tester, 'Open Asha chat');
    expect(find.byType(ActionChip), findsNWidgets(2));
    expect(_confirm, findsNothing);
    final choice = find.byKey(const Key('voicebot-choice-p:d'));
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(channels.lookups, isEmpty);
    expect(_confirm, findsNothing);
    await say(tester, 'Open Asha chat');
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(find.text('Conversation dm-d'), findsOneWidget);
    expect(find.text('Conversation dm-c'), findsNothing);
    expect(channels.lookups, ['d']);
  });

  testWidgets(
      'FR-AST-28 stop, cancellation, duplicate finals and recognition failures recover safely',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final text in [
      '   ',
      'Open chat',
      'Create a handoff for Bala',
      'Start a handoff for Dr. Priya',
      'Show my conversation with Bala',
      "Can you open Bala's conversation?",
    ]) {
      await say(tester, text);
      expect(_confirm, findsNothing);
      expect(channels.lookups, isEmpty);
      expect(handoffs.drafts, isEmpty);
    }
    await bot.startListening();
    await bot.cancel();
    speech.events.add(const SpeechFinal('Open Asha chat'));
    await tester.pumpAndSettle();
    expect(bot.state.phase, VoiceBotPhase.idle);
    await bot.startListening();
    speech.events.add(const SpeechError('timeout', 'synthetic timeout'));
    await tester.pumpAndSettle();
    expect(find.textContaining("didn't catch that"), findsOneWidget);
    expect(_confirm, findsNothing);
    await bot.startListening();
    await bot.stopListening();
    expect(speech.stopped, isTrue);
    speech.events.add(const SpeechPartial('Open'));
    speech.events.add(const SpeechFinal('Open Bala chat'));
    speech.events.add(const SpeechFinal('Open Asha chat'));
    await tester.pumpAndSettle();
    expect(bot.state.heard, 'Open Bala chat');
    expect(bot.state.proposals, hasLength(1));
    expect(channels.lookups, isEmpty);
    await confirm(tester);
    expect(find.text('Conversation dm-b'), findsOneWidget);
    expect(channels.lookups, ['b']);
  });

  testWidgets(
      'FR-AST-29 confirmed tab, search, alerts and availability reach their app boundaries',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    const routes = {
      'Find rounds': AppRoutes.search,
      'Show my chats': AppRoutes.messages,
      'Open handoffs': AppRoutes.handoffs,
      'Open notifications': AppRoutes.notifications,
      'Open profile': AppRoutes.profile,
      'Open home': AppRoutes.home,
    };
    for (final entry in routes.entries) {
      await say(tester, entry.key);
      expect(find.text('Page ${entry.value}'), findsNothing);
      await confirm(tester);
      expect(find.text('Page ${entry.value}'), findsOneWidget);
      await home(tester);
    }
    await say(tester, "I'm in OT");
    expect(users.status.value, 'available');
    await confirm(tester);
    expect(users.status.value, 'in_ot');
    await say(tester, 'Mark all alerts as read');
    expect(alerts.unread, 3);
    expect(badge.state, 3);
    await confirm(tester);
    expect(alerts.unread, 0);
    expect(badge.state, 0);
    expect(channels.lookups, isEmpty);
    expect(messages.textSendCount, 0);
    expect(handoffs.drafts, isEmpty);
  });

  testWidgets(
      'FR-AST-30 an expired or denied DM lookup stays on Home and an authorized session recovers',
      (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    channels.expired = true;
    await say(tester, 'Open Bala chat');
    await confirm(tester);
    expect(find.textContaining('Session expired'), findsOneWidget);
    expect(find.text('Conversation dm-b'), findsNothing);
    channels.expired = false;
    channels.denyDm = true;
    await say(tester, 'Open Bala chat');
    await confirm(tester);
    expect(find.textContaining('accepted message request'), findsOneWidget);
    expect(find.text('Conversation dm-b'), findsNothing);
    channels.denyDm = false;
    await say(tester, 'Open Bala chat');
    await confirm(tester);
    expect(find.text('Conversation dm-b'), findsOneWidget);
    expect(channels.lookups, ['b', 'b', 'b']);
    expect(messages.textSendCount, 0);
    expect(handoffs.drafts, isEmpty);
  });
}
