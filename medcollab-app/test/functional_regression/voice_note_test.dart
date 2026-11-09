// REQ 12: voice notes — record, send, play; composer mic; emoji picker.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/emoji_picker.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecorder implements VoiceRecorderEngine {
  _FakeRecorder({this.permission = true});
  final bool permission;
  final amps = StreamController<double>.broadcast();
  String? path;
  bool cancelled = false;

  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start(String p) async {
    path = p;
    await File(p).writeAsBytes(List<int>.filled(512, 7));
  }

  @override
  Stream<double> amplitudeDbfs() => amps.stream;
  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async => cancelled = true;
  @override
  Future<void> dispose() async {}
}

class _FakePlayer implements VoicePlayerEngine {
  final pos = StreamController<Duration>.broadcast();
  final play$ = StreamController<bool>.broadcast();
  final done = StreamController<bool>.broadcast();
  final loaded = <String>[];
  double speed = 1;

  @override
  Future<Duration?> load(String url) async {
    loaded.add(url);
    return const Duration(seconds: 12);
  }

  @override
  Future<void> play() async => play$.add(true);
  @override
  Future<void> pause() async => play$.add(false);
  @override
  Future<void> seek(Duration p) async => pos.add(p);
  @override
  Future<void> setSpeed(double s) async => speed = s;
  @override
  Stream<Duration> get positions => pos.stream;
  @override
  Stream<bool> get playing => play$.stream;
  @override
  Stream<bool> get completed => done.stream;
  @override
  Future<void> stop() async => play$.add(false);
}

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('vocle_voice');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('helpers: duration label, dBFS → level, waveform downsampling', () {
    expect(formatVoiceDuration(const Duration(seconds: 65)), '1:05');
    expect(levelFromDbfs(-160), 0);
    expect(levelFromDbfs(0), 100);
    expect(levelFromDbfs(-25), 50);
    final w = downsampleWaveform(List<int>.generate(400, (i) => i % 101));
    expect(w, hasLength(40));
    expect(w.every((v) => v >= 0 && v <= 100), isTrue);
    expect(downsampleWaveform(const [1, 2]), [1, 2]);
  });

  test('record → stop gives bytes, duration and a waveform; file removed',
      () async {
    final engine = _FakeRecorder();
    final c = VoiceRecorderController(engine: engine, tempDir: () async => tmp.path);
    expect(await c.start(), isTrue);
    expect(c.isRecording, isTrue);
    for (final db in [-40.0, -10.0, -5.0, -30.0]) {
      engine.amps.add(db);
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final rec = await c.stop();
    expect(rec, isNotNull);
    expect(rec!.bytes, hasLength(512));
    expect(rec.duration.inMilliseconds, greaterThanOrEqualTo(700));
    expect(rec.waveform, isNotEmpty);
    expect(rec.mimeType, 'audio/mp4');
    expect(File(engine.path!).existsSync(), isFalse,
        reason: 'temp recording must not linger on the phone');
    c.dispose();
  });

  test('a tap-and-stop under 0.7 s is discarded, not sent', () async {
    final c = VoiceRecorderController(
        engine: _FakeRecorder(), tempDir: () async => tmp.path);
    await c.start();
    expect(await c.stop(), isNull);
    c.dispose();
  });

  test('no microphone permission → denied, nothing recorded', () async {
    final engine = _FakeRecorder(permission: false);
    final c = VoiceRecorderController(engine: engine, tempDir: () async => tmp.path);
    expect(await c.start(), isFalse);
    expect(c.status, VoiceRecorderStatus.denied);
    expect(engine.path, isNull);
    c.dispose();
  });

  test('cancel discards the recording', () async {
    final engine = _FakeRecorder();
    final c = VoiceRecorderController(engine: engine, tempDir: () async => tmp.path);
    await c.start();
    await c.cancel();
    expect(engine.cancelled, isTrue);
    expect(c.isRecording, isFalse);
    c.dispose();
  });

  test('player: one note at a time; speed cycles 1× → 1.5× → 2× → 1×',
      () async {
    final engine = _FakePlayer();
    final p = VoiceNotePlayback(engineFactory: () => engine);
    await p.toggle('m1', 'https://x/a.m4a');
    expect(p.currentId, 'm1');
    expect(p.duration, const Duration(seconds: 12));
    await p.toggle('m2', 'https://x/b.m4a');
    expect(p.currentId, 'm2');
    expect(engine.loaded, ['https://x/a.m4a', 'https://x/b.m4a']);
    await p.cycleSpeed();
    expect(engine.speed, 1.5);
    await p.cycleSpeed();
    expect(engine.speed, 2);
    await p.cycleSpeed();
    expect(engine.speed, 1);
  });

  testWidgets('voice bubble shows length and a play button', (tester) async {
    VoiceNotePlayback.instance =
        VoiceNotePlayback(engineFactory: _FakePlayer.new);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageBubbleContent(
          message: const MessageModel(
            id: 'v1',
            channelId: 'c',
            sender: UserModel(id: 'u2', name: 'Peer'),
            type: MessageType.audio,
            content: MessageContent(
              mediaUrl: 'https://res.cloudinary.com/x/v.m4a',
              durationMs: 12400,
              waveform: [10, 50, 90, 40],
            ),
          ),
          isMine: false,
          showSender: false,
          showTimestamp: false,
          onImageTap: (_) {},
          onDocumentTap: (_) {},
        ),
      ),
    ));
    expect(find.text('0:12'), findsOneWidget);
    expect(find.bySemanticsLabel('Play voice message'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(VoiceNotePlayback.instance.currentId, 'v1');
  });

  testWidgets('composer: empty → mic; typing → send', (tester) async {
    final controller = TextEditingController();
    var mic = 0;
    String? sent;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageComposer(
          controller: controller,
          onSend: (t) => sent = t,
          onRecordVoice: () => mic++,
        ),
      ),
    ));
    expect(find.bySemanticsLabel('Record voice message'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    expect(mic, 1);

    await tester.enterText(find.byType(TextField), 'K+ 6.1');
    await tester.pump();
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send_rounded));
    expect(sent, 'K+ 6.1');
  });

  testWidgets('emoji picker inserts at the cursor and remembers recents',
      (tester) async {
    final controller = TextEditingController(text: 'ok ');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MessageComposer(controller: controller, onSend: (_) {}),
      ),
    ));
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🩺').first);
    await tester.pumpAndSettle();
    expect(controller.text, contains('🩺'));
    expect(await EmojiCatalog.recent(), contains('🩺'));
  });
}
