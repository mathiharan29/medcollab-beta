import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/speech/speech_service.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_bot_repository.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';

/// The conversation survives closing and reopening the panel for a while,
/// so "and send it to Bala too" still works a minute later.
List<VoiceTurn> _lastTurns = const [];
DateTime? _lastAt;
const _keepConversation = Duration(minutes: 10);

/// Opens the voice assistant with the app's real services (issue 14).
Future<void> openVoiceBot(BuildContext context, {bool listen = true}) {
  final deps = AppDependencies.instance;
  final selfId = context.read<AuthBloc>().state.user?.id ?? '';
  final directory = VoiceDirectoryLoader(
    channels: deps.channelRepository,
    spaces: deps.spaceRepository,
    members: deps.memberRepository,
  );
  final speech = deps.speechService;
  final platform = speech is PlatformSpeechService ? speech : null;
  final screen = _screenContext(deps);
  final keep = _lastAt != null && DateTime.now().difference(_lastAt!) < _keepConversation;

  return showVoiceBotSheet(
    context,
    listenImmediately: listen,
    initialTurns: keep ? _lastTurns : const [],
    onClosed: (turns) {
      _lastTurns = turns;
      _lastAt = DateTime.now();
    },
    openSettings: platform?.openAppSettings,
    create: () => VoiceBotCubit(
      speech: speech,
      loadDirectory: () => directory.load(selfId),
      executor: AppVoiceActionExecutor(
        router: deps.appRouter.router,
        channels: deps.channelRepository,
        messages: deps.messageRepository,
        handoffs: deps.handoffRepository,
        notifications: deps.notificationRepository,
        badge: deps.notificationBadgeCubit,
        users: deps.userRepository,
        directory: directory,
      ),
      aiAvailable: deps.assistantRepository.llmAvailable,
      interpretInConversation: (text, history) => deps.assistantRepository.interpret(
        text,
        history: [for (final t in history) (fromUser: t.fromUser, text: t.text)],
        context: screen,
      ),
      ensureMic: platform == null
          ? null
          : () async => switch (await platform.micPermission()) {
                'granted' => MicAccess.granted,
                'blocked' => MicAccess.blocked,
                _ => MicAccess.denied,
              },
      biasRecognizer: platform == null ? null : (hints) => platform.hints = hints,
    ),
  );
}

/// Which screen the doctor is on, for "this chat" in requests.
Map<String, String> _screenContext(AppDependencies deps) {
  try {
    final uri = deps.appRouter.router.routerDelegate.currentConfiguration.uri;
    final path = uri.path;
    final chat = RegExp(r'/(?:dm|channels?|voice)/([a-f0-9]{24})').firstMatch(path)?.group(1);
    final screen = switch (path) {
      '/home' || '/' => 'home',
      _ when path.startsWith('/messages') => 'messages',
      _ when path.startsWith('/handoffs') || path.contains('/handoffs') => 'handoffs',
      _ when path.startsWith('/notifications') => 'alerts',
      _ when path.startsWith('/profile') => 'profile',
      _ when chat != null => 'chat',
      _ => path.split('/').where((s) => s.isNotEmpty).firstOrNull ?? 'home',
    };
    return {'screen': screen, if (chat != null) 'chatId': 'c:$chat'};
  } catch (_) {
    return const {};
  }
}

/// The assistant's floating button, bottom-right on the main tabs (above
/// the tab's own action button when it has one).
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Vocle assistant',
      child: Tooltip(
        message: 'Vocle assistant',
        child: Material(
          key: const Key('open-voice-bot'),
          color: AppColors.surfaceCard,
          elevation: 6,
          shadowColor: Colors.black38,
          shape: const CircleBorder(side: BorderSide(color: AppColors.tealPrimary, width: 1.5)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => unawaited(openVoiceBot(context)),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.graphic_eq_rounded, color: AppColors.tealPrimary, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kept for callers that want an inline icon (e.g. a header).
class VoiceBotButton extends StatelessWidget {
  const VoiceBotButton({this.color, super.key});
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Voice assistant',
        onPressed: () => openVoiceBot(context),
        icon: Icon(Icons.graphic_eq_rounded, color: color ?? Colors.white),
      );
}
