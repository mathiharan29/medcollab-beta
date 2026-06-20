import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/thread_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

/// Navigation payload for [ThreadPage].
class ThreadRouteArgs {
  const ThreadRouteArgs({required this.rootMessage, this.channel});

  final MessageModel rootMessage;
  final ChannelModel? channel;
}

/// Focused thread view — parent message + replies for one discussion topic.
class ThreadPage extends StatefulWidget {
  const ThreadPage({
    required this.spaceId,
    required this.channelId,
    required this.rootMessageId,
    this.channel,
    this.initialRoot,
    super.key,
  });

  final String spaceId;
  final String channelId;
  final String rootMessageId;
  final ChannelModel? channel;
  final MessageModel? initialRoot;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
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
      create: (_) => ThreadCubit(
        threadRepository: deps.threadRepository,
        socketClient: deps.socketClient,
        channelId: widget.channelId,
        rootMessageId: widget.rootMessageId,
        initialRoot: widget.initialRoot,
      ),
      child: Builder(
        builder: (context) {
          final channelName = widget.channel?.displayName ?? 'Channel';
          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thread'),
                  Text(
                    channelName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: BlocConsumer<ThreadCubit, ThreadState>(
                    listenWhen: (prev, next) =>
                        prev.replies.length != next.replies.length,
                    listener: (_, __) => _scrollToBottom(),
                    builder: (context, state) {
                      if (state.isLoading && state.rootMessage == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final root = state.rootMessage ?? widget.initialRoot;
                      if (root == null) {
                        return const Center(child: Text('Thread not found'));
                      }

                      return Column(
                        children: [
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ErrorBanner(message: state.error!),
                            ),
                          ParentMessagePreview(message: root),
                          const Divider(height: 1),
                          Expanded(
                            child: state.replies.isEmpty
                                ? Center(
                                    child: Text(
                                      'No replies yet.\nStart the discussion.',
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
                                    itemCount: state.replies.length,
                                    itemBuilder: (context, index) {
                                      final reply = state.replies[index];
                                      return ThreadReplyBubble(
                                        message: reply,
                                        isMine:
                                            reply.sender.id == currentUserId,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                MessageComposer(
                  controller: _textController,
                  hintText: 'Reply in thread…',
                  onSend: (text) {
                    context.read<ThreadCubit>().sendReply(text);
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
