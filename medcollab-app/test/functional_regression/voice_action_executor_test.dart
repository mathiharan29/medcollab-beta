import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
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

import 'fakes/chat_fakes.dart';

const _peer = VoiceTarget(id: 'p:b', name: 'Dr Bala');
const _group = VoiceTarget(id: 'c:needl', name: 'Ward Team', kind: 'needl');

class _Channels extends ChannelRepository {
  _Channels() : super(apiClient: isolatedApiClient());

  final lookups = <String>[];
  bool denyDm = false;

  @override
  Future<ChannelModel> createOrGetDM(String userId) async {
    lookups.add(userId);
    if (denyDm) throw const ForbiddenException('Consent required');
    return ChannelModel.fromJson({'_id': 'dm-b', 'name': 'Dr Bala'});
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

  setUp(() {
    final api = isolatedApiClient();
    final socket = FakeSocketClient();
    channels = _Channels();
    handoffs = _Handoffs();
    messages = FakeMessageRepository()
      ..onSendText = (text, _) async => MessageModel.fromJson({
            '_id': 'message',
            'content': {'text': text}
          });
    final notifications = NotificationRepository(apiClient: api);
    final badge =
        NotificationBadgeCubit(repository: notifications, socketClient: socket);
    directory = VoiceDirectoryLoader(
      channels: channels,
      spaces: SpaceRepository(apiClient: api),
      members: MemberRepository(apiClient: api),
    );
    router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: '/spaces/:spaceId/handoffs/:handoffId/edit',
        builder: (_, state) =>
            Text('Edit ${state.pathParameters['handoffId']}'),
      ),
    ]);
    bot = VoiceBotCubit(
      speech: PlatformSpeechService(),
      loadDirectory: () async =>
          const VoiceDirectory(people: [_peer], chats: [_group]),
      executor: AppVoiceActionExecutor(
        router: router,
        channels: channels,
        handoffs: handoffs,
        messages: messages,
        notifications: notifications,
        badge: badge,
        users: UserRepository(apiClient: api),
        directory: directory,
      ),
    );
    addTearDown(() async {
      await bot.close();
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
    await bot.handleText(command);
    expect(handoffs.drafts, isEmpty);
    await bot.confirm(bot.state.proposals.single);
    expect(handoffs.drafts, isEmpty);
    expect(bot.state.message, contains('not in a group together'));

    directory.sharedGroups['b'] = [
      (spaceId: 'ward', channelId: 'general', name: 'Synthetic Ward')
    ];
    await bot.handleText(command);
    expect(handoffs.drafts, isEmpty);
    await bot.confirm(bot.state.proposals.single);
    await tester.pumpAndSettle();
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
}
