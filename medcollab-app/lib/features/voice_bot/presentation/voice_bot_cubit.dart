import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_command_parser.dart';

enum VoiceBotPhase { idle, listening, thinking, confirm, working, done, error }

class VoiceBotState extends Equatable {
  const VoiceBotState({
    this.phase = VoiceBotPhase.idle,
    this.heard = '',
    this.level = 0,
    this.proposals = const [],
    this.message = '',
    this.usedAi = false,
  });

  final VoiceBotPhase phase;

  /// Live / final transcript of what the doctor said.
  final String heard;
  final double level;

  /// Proposed actions awaiting the doctor's confirmation.
  final List<VoiceAction> proposals;

  /// Result / error / hint line (also spoken).
  final String message;

  /// The AI half (Claude via Vocle's server) interpreted this request.
  final bool usedAi;

  VoiceBotState copyWith({
    VoiceBotPhase? phase,
    String? heard,
    double? level,
    List<VoiceAction>? proposals,
    String? message,
    bool? usedAi,
  }) =>
      VoiceBotState(
        phase: phase ?? this.phase,
        heard: heard ?? this.heard,
        level: level ?? this.level,
        proposals: proposals ?? this.proposals,
        message: message ?? this.message,
        usedAi: usedAi ?? this.usedAi,
      );

  @override
  List<Object?> get props => [phase, heard, level, proposals, message, usedAi];
}

/// Hybrid voice bot (issue 14):
///   speech (on the phone) → built-in parser → [AI half only if needed and
///   configured] → confirm card → execute through normal APIs.
/// Nothing is ever sent or changed without the doctor's tap.
class VoiceBotCubit extends Cubit<VoiceBotState> with SafeEmit<VoiceBotState> {
  VoiceBotCubit({
    required SpeechService speech,
    required Future<VoiceDirectory> Function() loadDirectory,
    required VoiceActionExecutor executor,
    Future<bool> Function()? aiAvailable,
    Future<List<VoiceAction>> Function(String text)? interpretWithAi,
  })  : _speech = speech,
        _loadDirectory = loadDirectory,
        _executor = executor,
        _aiAvailable = aiAvailable,
        _interpretWithAi = interpretWithAi,
        super(const VoiceBotState());

  final SpeechService _speech;
  final Future<VoiceDirectory> Function() _loadDirectory;
  final VoiceActionExecutor _executor;
  final Future<bool> Function()? _aiAvailable;
  final Future<List<VoiceAction>> Function(String text)? _interpretWithAi;

  StreamSubscription<SpeechEvent>? _listen;
  VoiceDirectory? _directory;

  static const help =
      'Try: "Tell Arjun bed 7 is stable", "Open chat with Bala", '
      '"Hand off bed 12 to Meera", "I\'m in OT", "Mark alerts read".';

  Future<void> startListening() async {
    await _listen?.cancel();
    await _speech.stopSpeaking();
    emit(const VoiceBotState(phase: VoiceBotPhase.listening));
    unawaited(_ensureDirectory());
    _listen = _speech.listen().listen((e) {
      // Only the session that is still listening may change the sheet: a
      // late error from a recognizer being torn down (e.g. after the doctor
      // typed instead) used to replace the confirm card.
      if (state.phase != VoiceBotPhase.listening) return;
      switch (e) {
        case SpeechPartial(:final text):
          emit(state.copyWith(heard: text));
        case SpeechLevel(:final level):
          emit(state.copyWith(level: level));
        case SpeechFinal(:final text):
          unawaited(handleText(text));
        case SpeechError(:final code):
          emit(state.copyWith(
            phase: VoiceBotPhase.error,
            message: switch (code) {
              'no_match' || 'timeout' => "I didn't catch that. Tap the mic and try again.",
              'no_permission' => 'Allow microphone access to use voice commands.',
              'unavailable' => 'Speech recognition is not available on this phone. Type your request instead.',
              'language' => 'English speech pack is not installed on this phone yet. '
                  'Type your request, or try again once it downloads.',
              _ => 'Voice input stopped. Try again.',
            },
          ));
      }
    });
  }

  Future<void> _endListening() async {
    final sub = _listen;
    _listen = null;
    await sub?.cancel();
    await _speech.cancelListening();
  }

  Future<void> stopListening() => _speech.stopListening();

  Future<void> cancel() async {
    await _listen?.cancel();
    await _speech.cancelListening();
    emit(const VoiceBotState());
  }

  Future<VoiceDirectory> _ensureDirectory() async =>
      _directory ??= await _loadDirectory();

  /// Understand a request (spoken or typed).
  Future<void> handleText(String raw) async {
    // Typed while the mic was open, or the final result: either way this
    // listening session is over.
    if (_listen != null) unawaited(_endListening());
    final text = raw.trim();
    if (text.isEmpty) {
      emit(state.copyWith(phase: VoiceBotPhase.error, message: "I didn't catch that. $help"));
      return;
    }
    emit(state.copyWith(phase: VoiceBotPhase.thinking, heard: text, proposals: const [], message: ''));
    final directory = await _ensureDirectory();
    final local = VoiceCommandParser(directory).parse(text);
    if (local.understood) {
      _propose(local.actions, usedAi: false);
      return;
    }
    final ai = _interpretWithAi;
    if (ai != null && await (_aiAvailable?.call() ?? Future.value(false))) {
      try {
        final actions = await ai(text);
        _propose(actions, usedAi: true);
        return;
      } catch (_) {
        // fall through to the hint
      }
    }
    emit(state.copyWith(phase: VoiceBotPhase.error, message: "Sorry, I can't do that yet. $help"));
  }

  void _propose(List<VoiceAction> actions, {required bool usedAi}) {
    if (actions.isEmpty) {
      emit(state.copyWith(phase: VoiceBotPhase.error, message: "Sorry, I can't do that yet. $help", usedAi: usedAi));
      return;
    }
    emit(state.copyWith(phase: VoiceBotPhase.confirm, proposals: actions, usedAi: usedAi));
    final first = actions.first;
    unawaited(_speech.speak(first is ClarifyAction ? first.question : '${first.title}?'));
  }

  /// The doctor picked one of several matching people / chats.
  void choose(ClarifyAction question, VoiceTarget choice) {
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
  Future<void> confirm(VoiceAction action) async {
    emit(state.copyWith(phase: VoiceBotPhase.working));
    final result = await _executor.execute(action);
    final rest = [for (final p in state.proposals) if (p != action) p];
    emit(state.copyWith(
      phase: rest.isEmpty ? VoiceBotPhase.done : VoiceBotPhase.confirm,
      proposals: rest,
      message: result,
    ));
    unawaited(_speech.speak(result));
  }

  @override
  Future<void> close() async {
    await _listen?.cancel();
    await _speech.cancelListening();
    await _speech.stopSpeaking();
    return super.close();
  }
}
