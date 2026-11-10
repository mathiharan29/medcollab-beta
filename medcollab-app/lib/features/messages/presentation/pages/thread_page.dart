import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/media/data/services/media_picker_service.dart';
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
    required this.channelId,
    required this.rootMessageId,
    this.spaceId,
    this.channel,
    this.initialRoot,
    super.key,
  });

  final String? spaceId;
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
  final _mediaPicker = MediaPickerService();
  Timer? _draftDebounce;
  Timer? _typingStopDebounce;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onDraftChanged);
    _loadDraft();
  }

  void _onDraftChanged() {
    final text = _textController.text;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), () {
      AppDependencies.instance.draftMessageService.saveDraft(
        widget.channelId,
        text,
        threadId: widget.rootMessageId,
      );
    });
  }

  Future<void> _loadDraft() async {
    final draft = await AppDependencies.instance.draftMessageService.getDraft(
      widget.channelId,
      threadId: widget.rootMessageId,
    );
    if (!mounted || draft == null || draft.isEmpty) return;
    _textController.text = draft;
    _textController.selection = TextSelection.collapsed(offset: draft.length);
  }

  void _handleTyping(ThreadCubit cubit) {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      if (_isTyping) {
        _isTyping = false;
        cubit.emitTypingStop();
      }
      _typingStopDebounce?.cancel();
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      cubit.emitTypingStart();
    }
    _typingStopDebounce?.cancel();
    _typingStopDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      _isTyping = false;
      cubit.emitTypingStop();
    });
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _typingStopDebounce?.cancel();
    _textController.removeListener(_onDraftChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Pins the thread to its latest reply. Re-checks for a few frames because
  /// images/attachments finishing layout after the first jump grow the
  /// content and would otherwise leave the view mid-thread (REQ 2).
  void _scrollToBottom({int settleFrames = 6}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels < position.maxScrollExtent) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
      if (settleFrames > 0) _scrollToBottom(settleFrames: settleFrames - 1);
    });
  }

  Future<void> _sendAttachment(
    BuildContext context,
    Future<PickedAttachment?> Function() pick,
  ) async {
    final picked = await pick();
    if (picked == null || !context.mounted) return;
    unawaited(context.read<ThreadCubit>().sendAttachment(
          bytes: picked.bytes,
          fileName: picked.fileName,
          mimeType: picked.mimeType,
        ));
    _scrollToBottom();
  }

  Future<void> _clearDraft() async {
    await AppDependencies.instance.draftMessageService.clearDraft(
      widget.channelId,
      threadId: widget.rootMessageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return BlocProvider(
      create: (_) => ThreadCubit(
        threadRepository: deps.threadRepository,
        mediaRepository: deps.mediaRepository,
        socketClient: deps.socketClient,
        channelId: widget.channelId,
        rootMessageId: widget.rootMessageId,
        currentUserId: currentUserId,
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

                      return ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 8),
                        children: [
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: ErrorBanner(message: state.error!),
                            ),
                          ParentMessagePreview(
                            message: root,
                            isMine: root.sender.id == currentUserId,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              state.replies.isEmpty
                                  ? 'Replies'
                                  : '${state.replies.length} ${state.replies.length == 1 ? 'reply' : 'replies'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (state.replies.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No replies yet. Start the discussion.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            )
                          else
                            ...state.replies.map(
                              (reply) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: ThreadReplyBubble(
                                  message: reply,
                                  isMine: reply.sender.id == currentUserId,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                BlocBuilder<ThreadCubit, ThreadState>(
                  buildWhen: (p, n) =>
                      p.isSending != n.isSending ||
                      p.isUploading != n.isUploading ||
                      p.typingUserNames != n.typingUserNames,
                  builder: (context, state) {
                    final cubit = context.read<ThreadCubit>();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.typingLabel.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xxs,
                            ),
                            color: AppColors.surfaceMuted,
                            child: Text(
                              state.typingLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        _ThreadTypingBinder(
                          controller: _textController,
                          cubit: cubit,
                          onTyping: _handleTyping,
                          child: MessageComposer(
                            controller: _textController,
                            hintText: 'Reply in thread…',
                            // Never block typing while something sends/uploads (beta feedback).
                            isBusy: false,
                            onSend: (text) async {
                              // Clear first: the reply shows instantly.
                              _textController.clear();
                              unawaited(cubit.sendReply(text));
                              await _clearDraft();
                              _isTyping = false;
                              cubit.emitTypingStop();
                              _scrollToBottom();
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
                          ),
                        ),
                      ],
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

class _ThreadTypingBinder extends StatefulWidget {
  const _ThreadTypingBinder({
    required this.controller,
    required this.cubit,
    required this.onTyping,
    required this.child,
  });

  final TextEditingController controller;
  final ThreadCubit cubit;
  final void Function(ThreadCubit cubit) onTyping;
  final Widget child;

  @override
  State<_ThreadTypingBinder> createState() => _ThreadTypingBinderState();
}

class _ThreadTypingBinderState extends State<_ThreadTypingBinder> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => widget.onTyping(widget.cubit);

  @override
  Widget build(BuildContext context) => widget.child;
}
