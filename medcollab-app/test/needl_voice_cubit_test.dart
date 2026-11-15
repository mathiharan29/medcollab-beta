// Issue 13 (beta 11-14): Needl Voice — voice-only chat with on-device
// transcripts and walkie-talkie auto-play.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/media/data/models/media_upload_result.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';
import 'package:medcollab_app/features/needl_voice/presentation/needl_voice_cubit.dart';

import 'functional_regression/fakes/chat_fakes.dart';

MessageModel _audio(String id, String sender, {String? transcript}) => MessageModel(
      id: id,
      channelId: 'c1',
      type: MessageType.audio,
      sender: UserModel(id: sender, name: sender == 'me' ? 'Meera' : 'Arjun'),
      content: MessageContent(mediaUrl: 'https://x/$id.wav', durationMs: 2000, transcript: transcript),
    );

class _Messages extends FakeMessageRepository {
  final transcripts = <String, String?>{};
  bool failSend = false;
  int sends = 0;
  @override
  Future<MessagesPage> getMessages(String channelId, {String? before, int limit = 30}) async =>
      MessagesPage(messages: [
        _audio('a1', 'arjun'),
        MessageModel(id: 't1', channelId: 'c1', sender: const UserModel(id: 'arjun'), content: const MessageContent(text: 'text msg')),
      ], hasMore: false);
  @override
  Future<MessageModel> sendVoiceMessage({
    required String channelId,
    required MediaUploadResult upload,
    required int durationMs,
    List<int> waveform = const [],
  }) async {
    sends++;
    if (failSend) throw Exception('offline');
    return _audio('srv-${sends}', 'me');
  }

  @override
  Future<MessageModel> setTranscript({required String channelId, required String messageId, String? transcript}) async {
    transcripts[messageId] = transcript;
    return _audio(messageId, 'me', transcript: transcript).copyWith(
      content: MessageContent(
        mediaUrl: 'https://x/$messageId.wav',
        durationMs: 2000,
        transcript: transcript,
        transcriptStatus: transcript == null ? 'unavailable' : 'done',
      ),
    );
  }
}

class _Socket extends FakeSocketClient {
  final typing = <String?>[];
  @override
  bool get isConnected => false;
  @override
  void emitTypingStart(String channelId, {String? kind}) => typing.add(kind);
  @override
  void emitTypingStop(String channelId) => typing.add('stop');
}

class _Speech implements SpeechService {
  String? answer = 'Bed seven needs a repeat haemoglobin';
  final files = <String>[];
  @override
  Future<String?> transcribeFile(String wavPath, {String language = 'en-IN'}) async {
    files.add(wavPath);
    expect(File(wavPath).existsSync(), isTrue, reason: 'clip on disk while transcribing');
    return answer;
  }

  @override
  Future<SpeechCapabilities> capabilities() async => const SpeechCapabilities();
  @override
  Stream<SpeechEvent> listen({String language = 'en-IN'}) => const Stream.empty();
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> cancelListening() async {}
  @override
  Future<void> speak(String text, {String language = 'en-IN'}) async {}
  @override
  Future<void> stopSpeaking() async {}
}

class _Player implements VoicePlayerEngine {
  final loaded = <String>[];
  final pos = StreamController<Duration>.broadcast();
  final play$ = StreamController<bool>.broadcast();
  final done = StreamController<bool>.broadcast();
  @override
  Future<Duration?> load(String url) async {
    loaded.add(url);
    return const Duration(seconds: 2);
  }

  @override
  Future<void> play() async => play$.add(true);
  @override
  Future<void> pause() async => play$.add(false);
  @override
  Future<void> seek(Duration p) async => pos.add(p);
  @override
  Future<void> setSpeed(double s) async {}
  @override
  Stream<Duration> get positions => pos.stream;
  @override
  Stream<bool> get playing => play$.stream;
  @override
  Stream<bool> get completed => done.stream;
  @override
  Future<void> stop() async => play$.add(false);
}

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late _Messages messages;
  late FakeMediaRepository media;
  late _Socket socket;
  late _Speech speech;
  late _Player player;
  late VoiceNotePlayback playback;
  late Directory tmp;

  setUp(() async {
    messages = _Messages();
    media = FakeMediaRepository()
      ..onUpload = () async => const MediaUploadResult(
            url: 'https://x/up.wav', publicId: 'p', fileName: 'v.wav', fileSize: 10, mimeType: 'audio/wav');
    socket = _Socket();
    speech = _Speech();
    player = _Player();
    playback = VoiceNotePlayback(engineFactory: () => player);
    tmp = await Directory.systemTemp.createTemp('needl_voice');
  });
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  NeedlVoiceCubit make() => NeedlVoiceCubit(
        channelId: 'c1',
        currentUserId: 'me',
        messages: messages,
        media: media,
        socket: socket,
        speech: speech,
        playback: playback,
        tempDir: () async => tmp.path,
      );

  const rec = VoiceNoteRecording(bytes: [1, 2, 3], duration: Duration(seconds: 2), waveform: [10, 50],
      fileName: 'v.wav', mimeType: 'audio/wav');

  test('shows only voice messages of this chat', () async {
    final c = make();
    await _settle();
    expect(c.state.clips.map((m) => m.id), ['a1']);
    await c.close();
  });

  test('send: instant card → uploaded → on-device transcript attached for everyone', () async {
    final c = make();
    await _settle();
    c.recordingStarted();
    expect(socket.typing, ['voice'], reason: 'peers see "is recording…"');
    final sending = c.send(rec);
    await Future<void>.delayed(Duration.zero);
    expect(c.state.clips.last.localOnly, isTrue, reason: 'shows immediately');
    await sending;
    expect(socket.typing.last, 'stop');
    final sent = c.state.clips.last;
    expect(sent.id, 'srv-1');
    expect(sent.content.transcript, 'Bed seven needs a repeat haemoglobin');
    expect(messages.transcripts['srv-1'], 'Bed seven needs a repeat haemoglobin');
    expect(File(speech.files.single).existsSync(), isFalse, reason: 'temp clip deleted');
    await c.close();
  });

  test('no speech recognised → marked unavailable (clip still delivered)', () async {
    speech.answer = null;
    final c = make();
    await _settle();
    await c.send(rec);
    expect(messages.transcripts.containsKey('srv-1'), isTrue);
    expect(messages.transcripts['srv-1'], isNull);
    expect(c.state.clips.last.content.transcriptStatus, 'unavailable');
    await c.close();
  });

  test('send failure: card removed, clear error, nothing transcribed', () async {
    messages.failSend = true;
    final c = make();
    await _settle();
    await c.send(rec);
    expect(c.state.clips.map((m) => m.id), ['a1']);
    expect(c.state.error, contains('not sent'));
    expect(speech.files, isEmpty);
    await c.close();
  });

  test('peer recording indicator and live transcript arrival', () async {
    final c = make();
    await _settle();
    socket.emitEvent(SocketEvents.userTyping, {'channelId': 'c1', 'userId': 'arjun', 'userName': 'Dr Arjun', 'kind': 'voice'});
    socket.emitEvent(SocketEvents.userTyping, {'channelId': 'c1', 'userId': 'bala', 'userName': 'Dr Bala'}); // typing, not voice
    await _settle();
    expect(c.state.recordingPeers, ['Dr Arjun']);
    socket.emitEvent(SocketEvents.userStoppedTyping, {'channelId': 'c1', 'userId': 'arjun'});
    await _settle();
    expect(c.state.recordingPeers, isEmpty);

    socket.emitEvent(SocketEvents.messageUpdated, {
      'messageId': 'a1',
      'content': {'mediaUrl': 'https://x/a1.wav', 'transcript': 'Shifting bed 4 to ICU', 'transcriptStatus': 'done'},
    });
    await _settle();
    expect(c.state.clips.single.content.transcript, 'Shifting bed 4 to ICU');
    await c.close();
  });

  test('incoming clips auto-play in order; not while I am talking; can be turned off', () async {
    final c = make();
    await _settle();
    Map<String, dynamic> incoming(String id) => {
          '_id': id,
          'channelId': 'c1',
          'type': 'audio',
          'senderId': {'_id': 'arjun', 'name': 'Arjun'},
          'content': {'mediaUrl': 'https://x/$id.wav', 'durationMs': 1000},
        };
    socket.emitEvent(SocketEvents.newMessage, incoming('n1'));
    socket.emitEvent(SocketEvents.newMessage, incoming('n2'));
    await _settle();
    expect(player.loaded, ['https://x/n1.wav'], reason: 'first one plays at once');
    player.done.add(true); // n1 finished
    await _settle();
    expect(player.loaded, ['https://x/n1.wav', 'https://x/n2.wav'], reason: 'then the next');

    c.recordingStarted();
    socket.emitEvent(SocketEvents.newMessage, incoming('n3'));
    await _settle();
    expect(player.loaded, hasLength(2), reason: 'never plays over my recording');
    c.recordingCancelled();

    c.setAutoplay(false);
    socket.emitEvent(SocketEvents.newMessage, incoming('n4'));
    await _settle();
    expect(player.loaded, hasLength(2));
    expect(c.state.clips.map((m) => m.id), containsAll(['n3', 'n4']), reason: 'still listed');
    await c.close();
  });
}
