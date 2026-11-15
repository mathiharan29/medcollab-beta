import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_action_executor.dart';
import 'package:medcollab_app/features/voice_bot/data/voice_bot_repository.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_cubit.dart';
import 'package:medcollab_app/features/voice_bot/presentation/voice_bot_sheet.dart';

/// Opens the voice assistant with the app's real services (issue 14).
Future<void> openVoiceBot(BuildContext context, {bool listen = true}) {
  final deps = AppDependencies.instance;
  final selfId = context.read<AuthBloc>().state.user?.id ?? '';
  final directory = VoiceDirectoryLoader(
    channels: deps.channelRepository,
    spaces: deps.spaceRepository,
    members: deps.memberRepository,
  );
  return showVoiceBotSheet(
    context,
    listenImmediately: listen,
    create: () => VoiceBotCubit(
      speech: deps.speechService,
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
      interpretWithAi: deps.assistantRepository.interpret,
    ),
  );
}

/// Mic button that opens the assistant (Home header).
class VoiceBotButton extends StatelessWidget {
  const VoiceBotButton({this.color, super.key});
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
        key: const Key('open-voice-bot'),
        tooltip: 'Voice assistant',
        onPressed: () => openVoiceBot(context),
        icon: Icon(Icons.mic_rounded, color: color ?? Colors.white),
      );
}
