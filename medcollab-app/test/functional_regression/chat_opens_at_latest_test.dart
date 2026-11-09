// REQ 2: a chat must open at its latest message — not mid-history — on
// first open and when reopened, regardless of message heights.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/messages/presentation/pages/channel_chat_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channelId = 'chan-ward';
const _messageCount = 60;

String _textFor(int i) {
  // Mix short and tall rows so estimated extents are wrong, as in real
  // chats with long clinical notes.
  if (i % 7 == 0) {
    return 'Note $i: ${List.filled(12, 'patient stable, vitals reviewed').join(', ')}';
  }
  return 'Message $i';
}

Map<String, dynamic> _message(int i) => {
      '_id': 'm$i',
      'channelId': _channelId,
      'senderId': {'_id': i.isEven ? 'u-a' : 'u-b', 'name': i.isEven ? 'Dr A' : 'Dr B'},
      'type': 'text',
      'content': {'text': _textFor(i)},
      'createdAt': DateTime.utc(2026, 11, 8, 8).add(Duration(minutes: i)).toIso8601String(),
    };

class _ChatAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    Object data;
    if (options.method == 'GET' && path.endsWith('/$_channelId/messages')) {
      data = {
        'messages': [for (var i = 0; i < _messageCount; i++) _message(i)],
        'hasMore': false,
      };
    } else if (options.method == 'GET' && path.endsWith('/channels/$_channelId')) {
      data = {
        'channel': {'_id': _channelId, 'name': 'ward', 'type': 'general', 'spaceId': 's1'},
      };
    } else {
      data = {
        'channel': null, 'channels': [], 'members': [], 'messages': [],
        'notifications': [], 'pins': [], 'count': 0, 'unreadCount': 0,
      };
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data}),
      200,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _openChat(WidgetTester tester) async {
  final deps = AppDependencies.instance;
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: deps.authBloc),
      BlocProvider<PresenceCubit>.value(value: deps.presenceCubit),
    ],
    child: const MaterialApp(
      home: ChannelChatPage(channelId: _channelId, spaceId: 's1'),
    ),
  ));
  // Let load → first paint → post-frame scroll settle.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AppDependencies.instance.init();
    AppDependencies.instance.apiClient.dio.httpClientAdapter = _ChatAdapter();
  });

  testWidgets('chat opens at the latest message, not mid-history',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await _openChat(tester);

    expect(find.text('Message ${_messageCount - 1}'), findsOneWidget,
        reason: 'newest message must be on screen when the chat opens');
    expect(find.text('Message 1'), findsNothing,
        reason: 'oldest messages must be scrolled off, not shown first');

    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect(list.reverse, isTrue);
    expect(list.controller!.offset, 0,
        reason: 'reversed list: offset 0 is the newest message');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening a chat after scrolling up still opens at latest',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await _openChat(tester);
    // Scroll up into history (drag content downwards).
    await tester.drag(find.byType(ListView).first, const Offset(0, 2500));
    await tester.pumpAndSettle();
    expect(find.text('Message ${_messageCount - 1}'), findsNothing);

    // Leave and reopen the same chat.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _openChat(tester);

    expect(find.text('Message ${_messageCount - 1}'), findsOneWidget,
        reason: 'old scroll position must not be restored on reopen');
    expect(tester.takeException(), isNull);
  });
}
