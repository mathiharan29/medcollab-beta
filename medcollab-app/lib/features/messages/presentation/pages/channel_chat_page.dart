import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/media/data/services/media_picker_service.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/pages/thread_page.dart';
import 'package:medcollab_app/features/messages/presentation/utils/message_list_utils.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
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
  final _mediaPicker = MediaPickerService();
  int _lastMessageCount = 0;
  bool _userNearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    _userNearBottom = max - offset < 120;
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && !_userNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _openThread(BuildContext context, MessageModel message) {
    context.push(
      AppRoutes.threadPath(
        widget.spaceId,
        widget.channelId,
        message.id,
      ),
      extra: ThreadRouteArgs(
        rootMessage: message,
        channel: widget.channel,
      ),
    );
  }

  Future<void> _sendAttachment(
    BuildContext context,
    Future<PickedAttachment?> Function() pick,
  ) async {
    final picked = await pick();
    if (picked == null || !context.mounted) return;
    await context.read<ChannelChatCubit>().sendAttachment(
          bytes: picked.bytes,
          fileName: picked.fileName,
          mimeType: picked.mimeType,
        );
    _scrollToBottom(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return BlocProvider(
      create: (_) => ChannelChatCubit(
        messageRepository: deps.messageRepository,
        mediaRepository: deps.mediaRepository,
        socketClient: deps.socketClient,
        channelId: widget.channelId,
        currentUserId: currentUserId,
      ),
      child: Builder(
        builder: (context) {
          final channel = widget.channel;
          final title = channel?.displayName ?? 'Channel';
          final subtitle = channel?.description;

          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: BlocConsumer<ChannelChatCubit, ChannelChatState>(
                    listenWhen: (prev, next) =>
                        prev.messages.length != next.messages.length,
                    listener: (_, state) {
                      final grew = state.messages.length > _lastMessageCount;
                      _lastMessageCount = state.messages.length;
                      if (grew) _scrollToBottom();
                    },
                    builder: (context, state) {
                      if (state.isLoading && state.messages.isEmpty) {
                        return const AppMessageSkeleton();
                      }

                      final listItems = buildMessageListItems(
                        messages: state.messages,
                        currentUserId: currentUserId,
                      );

                      return Column(
                        children: [
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ErrorBanner(message: state.error!),
                            ),
                          Expanded(
                            child: state.messages.isEmpty
                                ? _EmptyChatState()
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    itemCount: listItems.length,
                                    itemBuilder: (context, index) {
                                      final item = listItems[index];
                                      return switch (item) {
                                        DateSeparatorItem(:final label) =>
                                          DateSeparatorChip(label: label),
                                        ChatMessageItem(
                                          :final message,
                                          :final showSender,
                                          :final isMine,
                                        ) =>
                                          MessageBubble(
                                            message: message,
                                            isMine: isMine,
                                            showSender: showSender,
                                            onOpenThread: () =>
                                                _openThread(context, message),
                                          ),
                                      };
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                BlocBuilder<ChannelChatCubit, ChannelChatState>(
                  buildWhen: (p, n) =>
                      p.isSending != n.isSending || p.isUploading != n.isUploading,
                  builder: (context, state) {
                    return MessageComposer(
                      controller: _textController,
                      isBusy: state.isSending || state.isUploading,
                      onSend: (text) {
                        context.read<ChannelChatCubit>().sendMessage(text);
                        _textController.clear();
                        _scrollToBottom(force: true);
                      },
                      onPickGallery: () => _sendAttachment(
                        context,
                        _mediaPicker.pickFromGallery,
                      ),
                      onPickCamera: () => _sendAttachment(
                        context,
                        _mediaPicker.captureFromCamera,
                      ),
                      onPickDocument: () => _sendAttachment(
                        context,
                        _mediaPicker.pickDocument,
                      ),
                    );
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

class _EmptyChatState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      subtitle:
          'Start a topic — share images, PDFs, or text.\nUse threads to discuss each patient.',
    );
  }
}
