import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_command_parser.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_help.dart';

enum VoiceBotPhase { idle, listening, thinking, confirm, working, done, error }

/// One line of the assistant conversation (shown in the panel and, for the
/// AI half, sent back as context so "that" / "him" / follow-ups work).
class VoiceTurn extends Equatable {
  const VoiceTurn.user(this.text) : fromUser = true;
  const VoiceTurn.assistant(this.text) : fromUser = false;
  final String text;
  final bool fromUser;
  @override
  List<Object?> get props => [text, fromUser];
}

/// Microphone access as the panel needs to show it.
enum MicAccess { unknown, granted, denied, blocked }

class VoiceBotState extends Equatable {
  const VoiceBotState({
    this.phase = VoiceBotPhase.idle,
    this.heard = '',
    this.level = 0,
    this.proposals = const [],
    this.message = '',
    this.usedAi = false,
    this.turns = const [],
    this.mic = MicAccess.unknown,
    this.notes = const [],
  });

  final VoiceBotPhase phase;

  /// Live / final transcript of what the doctor said.
  final String heard;
  final double level;

  /// Proposed actions awaiting the doctor's confirmation.
  final List<VoiceAction> proposals;

  /// Result / answer / error / hint line (also spoken).
  final String message;

  /// The AI half (Claude via Vocle's server) interpreted this request.
  final bool usedAi;

  /// The conversation so far, oldest first.
  final List<VoiceTurn> turns;
  final MicAccess mic;

  /// Things the doctor should double-check about what was heard
  /// (low recogniser confidence, an alternative hypothesis was used…).
  final List<String> notes;

  VoiceBotState copyWith({
    VoiceBotPhase? phase,
    String? heard,
    double? level,
    List<VoiceAction>? proposals,
    String? message,
    bool? usedAi,
    List<VoiceTurn>? turns,
    MicAccess? mic,
    List<String>? notes,
  }) =>
      VoiceBotState(
        phase: phase ?? this.phase,
        heard: heard ?? this.heard,
        level: level ?? this.level,
        proposals: proposals ?? this.proposals,
        message: message ?? this.message,
        usedAi: usedAi ?? this.usedAi,
        turns: turns ?? this.turns,
        mic: mic ?? this.mic,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props => [phase, heard, level, proposals, message, usedAi, turns, mic, notes];
}

/// Hybrid voice assistant (issue 14):
///   speech (on the phone) → built-in parser / built-in answers → [AI half
///   only if needed and configured, with the conversation so far] → confirm
///   card → execute through normal APIs.
/// Nothing is ever sent or changed without the doctor's tap.
class VoiceBotCubit extends Cubit<VoiceBotState> with SafeEmit<VoiceBotState> {
  VoiceBotCubit({
    required SpeechService speech,
    required Future<VoiceDirectory> Function() loadDirectory,
    required VoiceActionExecutor executor,
    Future<bool> Function()? aiAvailable,
    Future<List<VoiceAction>> Function(String text)? interpretWithAi,
    Future<List<VoiceAction>> Function(String text, List<VoiceTurn> history)? interpretInConversation,
    Future<MicAccess> Function()? ensureMic,
    void Function(List<String> hints)? biasRecognizer,
    Duration noResultTimeout = const Duration(seconds: 30),
    DateTime Function()? clock,
  })  : _speech = speech,
        _loadDirectory = loadDirectory,
        _executor = executor,
        _aiAvailable = aiAvailable,
        _interpretWithAi = interpretWithAi,
        _interpretInConversation = interpretInConversation,
        _ensureMic = ensureMic,
        _bias = biasRecognizer,
        _noResultTimeout = noResultTimeout,
        _clock = clock ?? DateTime.now,
        super(const VoiceBotState());

  final SpeechService _speech;
  final Future<VoiceDirectory> Function() _loadDirectory;
  final VoiceActionExecutor _executor;
  final Future<bool> Function()? _aiAvailable;
  final Future<List<VoiceAction>> Function(String text)? _interpretWithAi;
  final Future<List<VoiceAction>> Function(String text, List<VoiceTurn> history)? _interpretInConversation;
  final Future<MicAccess> Function()? _ensureMic;
  final void Function(List<String> hints)? _bias;
  final Duration _noResultTimeout;
  final DateTime Function() _clock;

  StreamSubscription<SpeechEvent>? _listen;
  VoiceDirectory? _directory;
  bool _running = false;
  Timer? _watchdog;

  /// Each listening session gets a number; events and results of an older
  /// session (after a timeout, cancel or retry) are ignored, so a stale
  /// command can never surface late (field finding 8).
  int _session = 0;

  static const help =
      'Try: "Tell Arjun bed 7 is stable", "Open chat with Bala", '
      '"Hand off bed 12 to Meera", "I\'m in OT", "Mark alerts read".';

  /// Recogniser confidence below this is flagged on the card.
  static const lowConfidence = 0.5;

  Future<void> startListening() async {
    await _endListening();
    await _speech.stopSpeaking();
    final session = ++_session;

    final ensure = _ensureMic;
    if (ensure != null) {
      final mic = await ensure();
      if (session != _session || isClosed) return;
      if (mic != MicAccess.granted) {
        emit(state.copyWith(
          phase: VoiceBotPhase.error,
          mic: mic,
          proposals: const [],
          notes: const [],
          message: mic == MicAccess.blocked
              ? 'Microphone access is turned off for Vocle. Open Settings → Permissions → Microphone and allow it, or type your request below.'
              : 'Vocle needs the microphone to hear you. Tap the mic and choose Allow, or type your request below.',
        ));
        return;
      }
    }

    emit(state.copyWith(
      phase: VoiceBotPhase.listening,
      heard: '',
      level: 0,
      proposals: const [],
      message: '',
      notes: const [],
      usedAi: false,
      mic: MicAccess.granted,
    ));
    // Names first, so the recogniser leans towards the doctor's colleagues.
    unawaited(_ensureDirectory().then((d) {
      if (session == _session) _bias?.call(_hints(d));
    }).catchError((_) {}));
    _armWatchdog(session);
    _listen = _speech.listen().listen((e) {
      // Only the session that is still listening may change the panel: a
      // late error from a recognizer being torn down (e.g. after the doctor
      // typed instead) used to replace the confirm card.
      if (session != _session || state.phase != VoiceBotPhase.listening) return;
      switch (e) {
        case SpeechPartial(:final text):
          _armWatchdog(session);
          emit(state.copyWith(heard: text));
        case SpeechLevel(:final level):
          emit(state.copyWith(level: level));
        case SpeechFinal():
          _watchdog?.cancel();
          unawaited(_handleSpeech(e));
        case SpeechError(:final code):
          _watchdog?.cancel();
          emit(state.copyWith(
            phase: VoiceBotPhase.error,
            mic: code == 'no_permission' ? MicAccess.denied : null,
            message: _errorMessage(code),
          ));
      }
    });
  }

  static String _errorMessage(String code) => switch (code) {
        'no_match' || 'timeout' => "I didn't catch that. Tap the mic and try again.",
        'stalled' => "I didn't get a result from the phone's speech service. Nothing was done — tap the mic to try again.",
        'no_permission' => 'Vocle needs the microphone to hear you. Tap the mic and choose Allow, or type your request.',
        'unavailable' => 'Speech recognition is not available on this phone. Type your request instead.',
        'network' => 'The phone could not reach its speech service (no connection). Type your request, or try again.',
        'language' => 'English speech pack is not installed on this phone yet. '
            'Type your request, or try again once it downloads.',
        'busy' => 'The phone\'s speech service is busy. Try again in a moment.',
        _ => 'Voice input stopped. Try again.',
      };

  /// No result for too long → end this session visibly (and ignore it).
  void _armWatchdog(int session) {
    _watchdog?.cancel();
    _watchdog = Timer(_noResultTimeout, () {
      if (session != _session || state.phase != VoiceBotPhase.listening) return;
      _session++; // anything this session still says is now stale
      unawaited(_endListening());
      emit(state.copyWith(phase: VoiceBotPhase.error, message: _errorMessage('stalled')));
    });
  }

  Future<void> _endListening() async {
    _watchdog?.cancel();
    final sub = _listen;
    _listen = null;
    await sub?.cancel();
    if (sub != null) await _speech.cancelListening();
  }

  Future<void> stopListening() => _speech.stopListening();

  Future<void> cancel() async {
    _session++;
    await _endListening();
    emit(VoiceBotState(turns: state.turns, mic: state.mic));
  }

  /// Continue an earlier conversation (panel closed and reopened).
  void restoreConversation(List<VoiceTurn> turns) => emit(state.copyWith(turns: turns));

  /// Start over: forget the conversation.
  void newConversation() {
    _session++;
    unawaited(_endListening());
    emit(VoiceBotState(mic: state.mic));
  }

  Future<VoiceDirectory> _ensureDirectory() async => _directory ??= await _loadDirectory();

  static List<String> _hints(VoiceDirectory d) => {
        for (final t in [...d.people, ...d.chats]) ...[
          t.name.replaceAll(RegExp(r'^(dr\.?|doctor)\s+', caseSensitive: false), ''),
          if (t.username != null) t.username!,
        ],
        'handoff', 'bed', 'Needl', 'alerts', 'on rounds', 'in OT', 'on call',
      }.where((s) => s.trim().isNotEmpty).take(100).toList();

  /// A spoken result: the best hypothesis, or — when it does not make a
  /// command but another hypothesis does — that one, said out loud on the
  /// card so the doctor sees the switch.
  Future<void> _handleSpeech(SpeechFinal e) async {
    final notes = <String>[];
    final c = e.confidence;
    if (c != null && c < lowConfidence) {
      notes.add('I may have misheard (low confidence). Check the details before confirming.');
    }
    var text = e.text;
    if (e.alternatives.isNotEmpty && text.trim().isNotEmpty) {
      final directory = await _ensureDirectory();
      final parser = VoiceCommandParser(directory);
      if (!_resolves(parser.parse(text))) {
        for (final alt in e.alternatives) {
          if (_resolves(parser.parse(alt))) {
            notes.add('Heard “${e.text}” — using the closer match “$alt”.');
            text = alt;
            break;
          }
        }
      }
    }
    await handleText(text, notes: notes, spoken: true);
  }

  static bool _resolves(ParseResult r) =>
      r.understood && r.actions.isNotEmpty && r.actions.every((a) => a is! ClarifyAction || !a.unmatched);

  /// Words that point back at the conversation ("send that to Bala too").
  static final _refersBack =
      RegExp(r"\b(that|it|this|same|again|also|too|him|her|them|they|previous|last one|earlier)\b", caseSensitive: false);

  /// Understand a request (spoken or typed).
  Future<void> handleText(String raw, {List<String> notes = const [], bool spoken = false}) async {
    // Typed while the mic was open, or the final result: either way this
    // listening session is over.
    if (_listen != null) {
      _session++;
      unawaited(_endListening());
    }
    final session = _session;
    final text = raw.trim();
    if (text.isEmpty) {
      emit(state.copyWith(phase: VoiceBotPhase.error, message: "I didn't catch that. $help"));
      return;
    }
    final history = state.turns;
    emit(state.copyWith(
      phase: VoiceBotPhase.thinking,
      heard: text,
      proposals: const [],
      message: '',
      notes: notes,
      turns: [...history, VoiceTurn.user(text)],
    ));
    final directory = await _ensureDirectory();
    if (session != _session) return;
    final local = VoiceCommandParser(directory).parse(text);
    final ai = _interpretInConversation ?? (_interpretWithAi == null ? null : (String t, List<VoiceTurn> _) => _interpretWithAi(t));
    final contextual = history.isNotEmpty && _refersBack.hasMatch(text);
    // A clear local command wins at once, unless it leans on the
    // conversation and the AI half can read that conversation.
    if (local.understood && !contextual) {
      _propose(local.actions, usedAi: false);
      return;
    }
    final aiOn = ai != null && await (_aiAvailable?.call() ?? Future.value(false));
    if (session != _session) return;
    if (local.understood && !aiOn) {
      _propose(local.actions, usedAi: false);
      return;
    }
    if (aiOn) {
      try {
        final actions = await ai(text, history);
        if (session != _session) return;
        _propose(actions, usedAi: true);
        return;
      } catch (_) {
        // fall through to the built-in answers / hint
      }
    }
    if (session != _session) return;
    if (local.understood) {
      _propose(local.actions, usedAi: false);
      return;
    }
    final answer = VoiceHelp.answer(text, now: _clock());
    if (answer != null) {
      _propose([ReplyAction(answer)], usedAi: false);
      return;
    }
    _fail(aiOn
        ? "Sorry, I can't do that yet. $help"
        : "I can do app actions — messages, chats, handoffs, alerts and your status. "
            "General questions need Vocle's AI, which isn't switched on for your hospital yet. $help");
  }

  void _fail(String message, {bool usedAi = false}) {
    emit(state.copyWith(
      phase: VoiceBotPhase.error,
      message: message,
      usedAi: usedAi,
      turns: [...state.turns, VoiceTurn.assistant(message)],
    ));
  }

  void _propose(List<VoiceAction> actions, {required bool usedAi}) {
    final replies = actions.whereType<ReplyAction>().map((r) => r.text).toList();
    final rest = actions.where((a) => a is! ReplyAction).toList();
    if (rest.isEmpty && replies.isEmpty) {
      _fail("Sorry, I can't do that yet. $help", usedAi: usedAi);
      return;
    }
    final said = replies.join(' ');
    final turns = [
      ...state.turns,
      if (said.isNotEmpty) VoiceTurn.assistant(said),
      for (final a in rest) VoiceTurn.assistant(a is ClarifyAction ? a.question : '${a.title}?'),
    ];
    if (rest.isEmpty) {
      emit(state.copyWith(phase: VoiceBotPhase.done, proposals: const [], message: said, usedAi: usedAi, turns: turns));
      unawaited(_speech.speak(said));
      return;
    }
    emit(state.copyWith(phase: VoiceBotPhase.confirm, proposals: rest, message: said, usedAi: usedAi, turns: turns));
    final first = rest.first;
    unawaited(_speech.speak(
      [if (said.isNotEmpty) said, first is ClarifyAction ? first.question : '${first.title}?'].join(' '),
    ));
  }

  /// Everyone (and every chat) the doctor may pick from explicitly.
  Future<List<VoiceTarget>> pickable({bool peopleOnly = false}) async {
    final d = await _ensureDirectory();
    return [...d.people, if (!peopleOnly) ...d.chats];
  }

  /// The doctor picked one of several matching people / chats.
  void choose(ClarifyAction question, VoiceTarget choice) {
    final rebuild = question.rebuild;
    if (rebuild != null) {
      final rebuilt = rebuild(choice);
      _propose([rebuilt], usedAi: state.usedAi);
      return;
    }
    final heard = state.heard;
    final directory = VoiceDirectory(
      people: [if (choice.isPerson) choice],
      chats: [if (!choice.isPerson) choice],
    );
    // Re-read the same request with only the chosen target in reach.
    final parsed = VoiceCommandParser(directory).parse(heard);
    if (parsed.understood && parsed.actions.first is! ClarifyAction) {
      _propose(parsed.actions, usedAi: state.usedAi);
    } else {
      _propose([OpenChatAction(choice)], usedAi: state.usedAi);
    }
  }

  /// Edit the message text on a send card before confirming.
  void editText(SendMessageAction action, String text) {
    emit(state.copyWith(proposals: [
      for (final p in state.proposals) p == action ? SendMessageAction(to: action.to, text: text) : p,
    ]));
  }

  void dismiss(VoiceAction action) {
    final rest = [for (final p in state.proposals) if (p != action) p];
    emit(state.copyWith(
      proposals: rest,
      phase: rest.isEmpty ? VoiceBotPhase.idle : VoiceBotPhase.confirm,
    ));
  }

  /// Run one confirmed action.
  ///
  /// FR-AST-25: a second tap (or a stale card) while one action is running,
  /// or for a proposal that is no longer on screen, does nothing — one
  /// confirmed proposal runs at most one write.
  Future<void> confirm(VoiceAction action) async {
    if (state.phase == VoiceBotPhase.working || _running) return;
    if (!state.proposals.contains(action)) return;
    _running = true;
    emit(state.copyWith(phase: VoiceBotPhase.working));
    final String result;
    try {
      result = await _executor.execute(action);
    } finally {
      _running = false;
    }
    final rest = [for (final p in state.proposals) if (p != action) p];
    emit(state.copyWith(
      phase: rest.isEmpty ? VoiceBotPhase.done : VoiceBotPhase.confirm,
      proposals: rest,
      message: result,
      turns: [...state.turns, VoiceTurn.assistant(result)],
    ));
    unawaited(_speech.speak(result));
  }

  @override
  Future<void> close() async {
    _session++;
    _watchdog?.cancel();
    await _listen?.cancel();
    await _speech.cancelListening();
    await _speech.stopSpeaking();
    return super.close();
  }
}
