import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class ChannelChatPage extends StatefulWidget {
  const ChannelChatPage({
    required this.spaceId,
    required this.channelId,
    this.channel,
    super.key,
  });

  final String spaceId;
  final String channelId;
  final ChannelModel? channel;

  @override
  State<ChannelChatPage> createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return BlocProvider(
      create: (_) => ChannelChatCubit(
        messageRepository: deps.messageRepository,
        socketClient: deps.socketClient,
        channelId: widget.channelId,
        currentUserId: currentUserId,
      ),
      child: Builder(
        builder: (context) {
          final title = widget.channel?.displayName ?? 'Channel';
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Column(
              children: [
                Expanded(
                  child: BlocConsumer<ChannelChatCubit, ChannelChatState>(
                    listenWhen: (prev, next) =>
                        prev.messages.length != next.messages.length,
                    listener: (_, __) => _scrollToBottom(),
                    builder: (context, state) {
                      if (state.isLoading && state.messages.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return Column(
                        children: [
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ErrorBanner(message: state.error!),
                            ),
                          Expanded(
                            child: state.messages.isEmpty
                                ? Center(
                                    child: Text(
                                      'No messages yet.\nSay hello to the team.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    itemCount: state.messages.length,
                                    itemBuilder: (context, index) {
                                      final message = state.messages[index];
                                      final isMine =
                                          message.sender.id == currentUserId;
                                      return _MessageBubble(
                                        message: message,
                                        isMine: isMine,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                _MessageComposer(
                  controller: _textController,
                  onSend: (text) {
                    context.read<ChannelChatCubit>().sendMessage(text);
                    _textController.clear();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? DateFormat.jm().format(message.createdAt!.toLocal())
        : '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                message.sender.displayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            Text(
              message.displayText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: message.isDeleted
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: message.isDeleted
                        ? AppColors.textSecondary
                        : null,
                  ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: onSend,
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: () => onSend(controller.text),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
