import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/media/data/repositories/media_repository.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/repositories/message_repository.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/voice_note.dart';

class NeedlVoiceState extends Equatable {
  const NeedlVoiceState({
    this.loading = true,
    this.clips = const [],
    this.autoplay = true,
    this.recordingPeers = const [],
    this.error,
  });

  final bool loading;

  /// Voice messages of this chat, oldest first.
  final List<MessageModel> clips;

  /// Play new voice messages from others as they arrive (walkie-talkie).
  final bool autoplay;

  /// Names of people recording right now ("Dr Arjun is recording…").
  final List<String> recordingPeers;
  final String? error;

  NeedlVoiceState copyWith({
    bool? loading,
    List<MessageModel>? clips,
    bool? autoplay,
    List<String>? recordingPeers,
    String? error,
  }) =>
      NeedlVoiceState(
        loading: loading ?? this.loading,
        clips: clips ?? this.clips,
        autoplay: autoplay ?? this.autoplay,
        recordingPeers: recordingPeers ?? this.recordingPeers,
        error: error,
      );

  @override
  List<Object?> get props => [loading, clips, autoplay, recordingPeers, error];
}

/// Needl Voice (issue 13): a voice-first view of a chat.
///
/// - Same chat, same messages: voice clips sent here appear in the normal
///   chat too (with a mic badge) and vice versa.
/// - Each clip is recorded once (16 kHz WAV), sent immediately, then
///   transcribed ON THE PHONE and the transcript attached for everyone
///   (PATCH …/transcript → live `message_updated`).
/// - Incoming clips auto-play one after another while the screen is open.
class NeedlVoiceCubit extends Cubit<NeedlVoiceState> with SafeEmit<NeedlVoiceState> {
  NeedlVoiceCubit({
    required this.channelId,
    required this.currentUserId,
    required MessageRepository messages,
    required MediaRepository media,
    required SocketClient socket,
    required SpeechService speech,
    VoiceNotePlayback? playback,
    Future<String> Function()? tempDir,
  })  : _messages = messages,
        _media = media,
        _socket = socket,
        _speech = speech,
        _playback = playback ?? VoiceNotePlayback.instance,
        _tempDir = tempDir ?? (() async => Directory.systemTemp.path),
        super(const NeedlVoiceState()) {
    _subs
      ..add(_socket.onMapEvent(SocketEvents.newMessage).listen(_onNew))
      ..add(_socket.onMapEvent(SocketEvents.messageUpdated).listen(_onUpdated))
      ..add(_socket.onMapEvent(SocketEvents.userTyping).listen(_onTyping))
      ..add(_socket.onMapEvent(SocketEvents.userStoppedTyping).listen(_onStopped));
    _playback.addListener(_onPlayback);
    if (_socket.isConnected) _socket.joinChannel(channelId);
    unawaited(load());
  }

  final String channelId;
  final String currentUserId;
  final MessageRepository _messages;
  final MediaRepository _media;
  final SocketClient _socket;
  final SpeechService _speech;
  final VoiceNotePlayback _playback;
  final Future<String> Function() _tempDir;
  final List<StreamSubscription<Object?>> _subs = [];
  final Map<String, String> _recording = {};
  final Map<String, Timer> _recordingExpiry = {};

  /// Clip ids waiting to auto-play, oldest first.
  final List<String> _queue = [];
  bool _recordingNow = false;
  int _seq = 0;

  static String playbackId(String messageId) => 'needl-voice:$messageId';

  Future<void> load() async {
    try {
      final page = await _messages.getVoiceMessages(channelId, limit: 50);
      final fetched = page.messages.where(_isVoiceClip).toList();
      // FR-VCE-12: clips (and transcripts) that arrived live while the
      // history was loading are newer than this snapshot — keep them.
      final live = {for (final c in state.clips) c.id: c};
      emit(state.copyWith(
        loading: false,
        clips: [
          for (final m in fetched) live.remove(m.id) ?? m,
          ...live.values,
        ],
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: 'Could not load voice messages'));
    }
  }

  void setAutoplay(bool on) {
    if (!on) _queue.clear();
    emit(state.copyWith(autoplay: on));
  }

  // ── recording / sending ─────────────────────────────────────────────────
  void recordingStarted() {
    _recordingNow = true;
    _queue.clear();
    unawaited(_playback.stopAll());
    _socket.emitTypingStart(channelId, kind: 'voice');
  }

  void recordingCancelled() {
    _recordingNow = false;
    _socket.emitTypingStop(channelId);
  }

  /// Send a finished clip; transcribe it on the phone afterwards.
  Future<void> send(VoiceNoteRecording rec) async {
    _recordingNow = false;
    _socket.emitTypingStop(channelId);
    final tempId = 'local-voice-${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final local = MessageModel(
      id: tempId,
      channelId: channelId,
      type: MessageType.audio,
      sender: UserModel(id: currentUserId),
      content: MessageContent(
        durationMs: rec.duration.inMilliseconds,
        waveform: rec.waveform,
        transcriptStatus: 'pending',
        voiceMode: true,
      ),
      createdAt: DateTime.now(),
      localOnly: true,
    );
    emit(state.copyWith(clips: [...state.clips, local]));

    // Keep a copy for the on-device transcription.
    final path = '${await _tempDir()}${Platform.pathSeparator}$tempId.wav';
    final file = File(path);
    await file.writeAsBytes(rec.bytes, flush: true);

    MessageModel sent;
    try {
      final upload = await _media.uploadFile(
        bytes: rec.bytes,
        fileName: rec.fileName,
        mimeType: rec.mimeType,
        context: 'message',
      );
      sent = await _messages.sendVoiceMessage(
        channelId: channelId,
        upload: upload,
        durationMs: rec.duration.inMilliseconds,
        waveform: rec.waveform,
      );
    } catch (_) {
      _replace(tempId, null);
      emit(state.copyWith(error: 'Voice message not sent. Check the connection and try again.'));
      await _deleteQuietly(file);
      return;
    }
    _replace(tempId, sent);

    // Transcript: made on this phone, then shared.
    final text = await _speech.transcribeFile(path);
    // Patient audio must not linger on the phone after transcription.
    await _deleteQuietly(file);
    try {
      final updated = await _messages.setTranscript(
        channelId: channelId,
        messageId: sent.id,
        transcript: text,
      );
      _merge(updated.id, updated.content);
    } catch (_) {
      // The clip itself was delivered; a missing transcript is not fatal.
    }
  }

  // ── realtime ────────────────────────────────────────────────────────────
  void _onNew(Map<String, dynamic> raw) {
    final m = MessageModel.fromJson(raw);
    if (m.channelId != channelId || !_isVoiceClip(m) || m.threadId != null) return;
    if (state.clips.any((c) => c.id == m.id)) return;
    // My own clip is already shown (optimistic) — replaced on send.
    if (m.sender.id == currentUserId) return;
    emit(state.copyWith(clips: [...state.clips, m]));
    _clearRecording(m.sender.id);
    if (state.autoplay && !_recordingNow) {
      _queue.add(m.id);
      if (!_playerBusy) unawaited(_playNext());
    }
  }

  /// Needl Voice is its own space: only clips recorded in voice mode
  /// (normal chat voice notes stay in the chat). Messages from an older
  /// server without the flag are still audio-only.
  static bool _isVoiceClip(MessageModel m) =>
      m.type == MessageType.audio && m.content.voiceMode != false;

  /// Playing, loading, or PAUSED part-way (FR-VCE-15): a new arrival waits
  /// in the queue instead of taking the player away from the paused clip.
  bool get _playerBusy =>
      _playback.isPlaying ||
      _playback.isLoading ||
      (_playback.currentId != null && _playback.position > Duration.zero);

  void _onUpdated(Map<String, dynamic> raw) {
    final id = raw['messageId']?.toString() ?? '';
    final content = asJsonMap(raw['content']);
    if (id.isEmpty || content == null) return;
    _merge(id, MessageContent.fromJson(content));
  }

  void _onTyping(Map<String, dynamic> e) {
    if (e['channelId']?.toString() != channelId || e['kind'] != 'voice') return;
    final uid = e['userId']?.toString() ?? '';
    if (uid.isEmpty || uid == currentUserId) return;
    _recording[uid] = (e['userName']?.toString() ?? 'Someone').trim();
    _recordingExpiry[uid]?.cancel();
    // Recording can't silently last forever (dropped connection etc.).
    _recordingExpiry[uid] = Timer(const Duration(minutes: 2), () => _clearRecording(uid));
    emit(state.copyWith(recordingPeers: _recording.values.toList()));
  }

  void _onStopped(Map<String, dynamic> e) {
    if (e['channelId']?.toString() != channelId) return;
    _clearRecording(e['userId']?.toString() ?? '');
  }

  void _clearRecording(String uid) {
    _recordingExpiry.remove(uid)?.cancel();
    if (_recording.remove(uid) != null) {
      emit(state.copyWith(recordingPeers: _recording.values.toList()));
    }
  }

  // ── auto-play queue ─────────────────────────────────────────────────────
  String? _lastPlaying;

  void _onPlayback() {
    final current = _playback.currentId;
    final ended = _lastPlaying != null &&
        current == _lastPlaying &&
        !_playback.isPlaying &&
        !_playback.isLoading &&
        _playback.position == Duration.zero;
    if (_playback.isPlaying) _lastPlaying = current;
    if (ended) {
      _lastPlaying = null;
      if (_queue.isNotEmpty && !_recordingNow) unawaited(_playNext());
    }
  }

  bool _advancing = false;

  /// Play the oldest queued clip. FR-VCE-16: a clip that fails to load stays
  /// listed (it can be retried by tapping it) and the queue moves on.
  Future<void> _playNext() async {
    if (_advancing) return;
    _advancing = true;
    try {
      while (_queue.isNotEmpty && !_recordingNow && !isClosed) {
        final id = _queue.removeAt(0);
        final clip = state.clips.where((c) => c.id == id).firstOrNull;
        final url = clip?.content.mediaUrl;
        if (clip == null || url == null || url.isEmpty) continue;
        final pid = playbackId(id);
        await _playback.toggle(
          pid,
          url,
          knownDuration: Duration(milliseconds: clip.content.durationMs ?? 0),
        );
        final failed = _playback.currentId == null && _playback.error != null;
        if (!failed) return;
      }
    } finally {
      _advancing = false;
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────
  void _replace(String tempId, MessageModel? sent) {
    emit(state.copyWith(clips: [
      for (final c in state.clips)
        if (c.id != tempId) c else if (sent != null) sent,
    ]));
  }

  void _merge(String id, MessageContent content) {
    if (!state.clips.any((c) => c.id == id)) return;
    emit(state.copyWith(clips: [
      for (final c in state.clips) c.id == id ? c.copyWith(content: content) : c,
    ]));
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    for (final t in _recordingExpiry.values) {
      t.cancel();
    }
    _playback.removeListener(_onPlayback);
    if (_recordingNow) _socket.emitTypingStop(channelId);
    unawaited(_playback.stopAll());
    return super.close();
  }
}
