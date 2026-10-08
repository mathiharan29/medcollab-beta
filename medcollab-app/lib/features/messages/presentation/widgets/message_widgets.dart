import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_decorations.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/media/data/services/document_open_service.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/message_reply_to.dart';
import 'package:medcollab_app/features/messages/presentation/utils/message_list_utils.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/read_receipt_footer.dart';
import 'package:medcollab_app/shared/presentation/widgets/chat_network_image.dart';
import 'package:medcollab_app/shared/presentation/widgets/mention_rich_text.dart';

/// Text input bar — attach button next to send for quick uploads.
/// Emoji uses the system keyboard (WhatsApp-style).
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.onPickGallery,
    this.onPickCamera,
    this.onPickDocument,
    this.hintText = 'Message…',
    this.isBusy = false,
    this.showTopBorder = true,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSend;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final String hintText;
  final bool isBusy;
  final bool showTopBorder;

  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photos & videos'),
              onTap: () {
                Navigator.pop(ctx);
                onPickGallery?.call();
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  onPickCamera?.call();
                },
              ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Document / PDF'),
              onTap: () {
                Navigator.pop(ctx);
                onPickDocument?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _insertAtCursor(String text) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final next = value.text.replaceRange(start, end, text);
    controller.value = value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    const emojis = [
      '👍', '🙏', '✅', '❌', '⚠️', '🚨',
      '💉', '🩺', '💊', '🏥', '📋', '📝',
      '😊', '😂', '😮', '😢', '🔥', '💯',
      '👀', '🤝', '⏰', '📌', '➡️', '⬅️',
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick emoji',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in emojis)
                    InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _insertAtCursor(emoji);
                        focusNode?.requestFocus();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAttach = onPickGallery != null ||
        onPickDocument != null ||
        onPickCamera != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: showTopBorder
            ? const Border(
                top: BorderSide(color: AppColors.borderDefault, width: 0.5),
              )
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (canAttach)
                IconButton(
                  tooltip: 'Attach',
                  onPressed: isBusy ? null : () => _showAttachMenu(context),
                  icon: const Icon(Icons.add_circle_outline, size: 26),
                  color: AppColors.tealDark,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInput,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.borderDefault,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          minLines: 1,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          enabled: !isBusy,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: AppTextStyles.body.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              12,
                              4,
                              12,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Emoji',
                        onPressed:
                            isBusy ? null : () => _showEmojiPicker(context),
                        icon: const Icon(Icons.emoji_emotions_outlined, size: 22),
                        color: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: isBusy
                      ? AppColors.navyPrimary.withValues(alpha: 0.5)
                      : AppColors.navyPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: isBusy ? null : () => onSend(controller.text),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: isBusy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date separator chip between message groups.
class DateSeparatorChip extends StatelessWidget {
  const DateSeparatorChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppGaps.cardV),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: const BoxDecoration(
            color: AppColors.borderDefault,
            borderRadius: AppRadius.pill,
          ),
          child: Text(label, style: AppTextStyles.timestamp),
        ),
      ),
    );
  }
}

/// Root message pinned at the top of a thread screen.
class ParentMessagePreview extends StatelessWidget {
  const ParentMessagePreview({
    required this.message,
    required this.isMine,
    super.key,
  });

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryMuted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original message',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            MessageBubbleContent(
              message: message,
              isMine: isMine,
              showSender: true,
              showTimestamp: true,
              onImageTap: (url) => _openImage(context, url, message),
              onDocumentTap: (url) => DocumentOpenService.open(
                context,
                url: url,
                fileName: message.content.fileName,
                mimeType: message.content.mimeType,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Channel message bubble with grouping, media, delivery state, threads.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    this.showSender = true,
    this.showTimestamp = true,
    this.onQuoteReply,
    this.onOpenThread,
    this.onJumpToQuoted,
    this.onImageTap,
    this.onEdit,
    this.onDelete,
    this.onBookmark,
    this.onPin,
    this.onUnpin,
    this.onReact,
    this.onForward,
    this.onCopy,
    this.currentUserId,
    this.nameByUserId = const {},
    this.showReadReceipts = true,
    this.isDm = false,
    this.isPinned = false,
    this.isHighlighted = false,
    this.localImageBytes,
    super.key,
  });

  final MessageModel message;
  final bool isMine;
  final bool showSender;
  final bool showTimestamp;
  /// WhatsApp-style quote reply (swipe / Reply action).
  final VoidCallback? onQuoteReply;
  /// Slack-style side thread (long-press menu).
  final VoidCallback? onOpenThread;
  final void Function(String url)? onImageTap;
  /// Jump to the quoted parent message in the timeline.
  final VoidCallback? onJumpToQuoted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBookmark;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final ValueChanged<String>? onReact;
  final VoidCallback? onForward;
  final VoidCallback? onCopy;
  final String? currentUserId;
  final Map<String, String> nameByUserId;
  final bool showReadReceipts;
  final bool isDm;
  final bool isPinned;
  final bool isHighlighted;
  final List<int>? localImageBytes;

  static const quickReactions = ['👍', '❤️', '😂', '🙏', '✅', '👏'];
  static const moreReactions = [
    '👍', '❤️', '😂', '😮', '😢', '🙏',
    '✅', '👏', '🔥', '💯', '👀', '🫡',
    '🩺', '💉', '🏥', '📋', '⚠️', '🚨',
  ];

  Future<void> _showActions(BuildContext context) async {
    if (message.isDeleted || message.localOnly) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onReact != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    ...quickReactions.map(
                      (e) => Expanded(
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx, 'react:$e'),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(e, style: const TextStyle(fontSize: 26)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'More reactions',
                      onPressed: () => Navigator.pop(ctx, 'more-react'),
                      icon: const Icon(Icons.add_reaction_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            if (onQuoteReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                subtitle: const Text('Quote in this chat'),
                onTap: () => Navigator.pop(ctx, 'quote'),
              ),
            if (onOpenThread != null)
              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reply in thread'),
                subtitle: const Text('Side discussion — keep main chat clean'),
                onTap: () => Navigator.pop(ctx, 'thread'),
              ),
            if (onCopy != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            if (onForward != null)
              ListTile(
                leading: const Icon(Icons.forward_outlined),
                title: const Text('Forward / share'),
                onTap: () => Navigator.pop(ctx, 'forward'),
              ),
            if (isMine &&
                message.type == MessageType.text &&
                onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            if (isMine && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete message'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            if (onBookmark != null)
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Bookmark'),
                onTap: () => Navigator.pop(ctx, 'bookmark'),
              ),
            if (isPinned && onUnpin != null)
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text('Unpin message'),
                onTap: () => Navigator.pop(ctx, 'unpin'),
              )
            else if (onPin != null)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin message'),
                onTap: () => Navigator.pop(ctx, 'pin'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'more-react') {
      final emoji = await _pickMoreReaction(context);
      if (emoji != null) onReact?.call(emoji);
      return;
    }
    if (action.startsWith('react:')) {
      onReact?.call(action.substring(6));
    } else if (action == 'quote') {
      onQuoteReply?.call();
    } else if (action == 'thread') {
      onOpenThread?.call();
    } else if (action == 'copy') {
      onCopy?.call();
    } else if (action == 'forward') {
      onForward?.call();
    } else if (action == 'edit') {
      onEdit?.call();
    } else if (action == 'delete') {
      onDelete?.call();
    } else if (action == 'bookmark') {
      onBookmark?.call();
    } else if (action == 'pin') {
      onPin?.call();
    } else if (action == 'unpin') {
      onUnpin?.call();
    }
  }

  Future<String?> _pickMoreReaction(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'React',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: moreReactions
                    .map(
                      (e) => InkWell(
                        onTap: () => Navigator.pop(ctx, e),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: showSender ? 8 : 2,
          bottom: 2,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSender && !isMine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  _senderLabel(message, nameByUserId),
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            MessageBubbleContent(
              message: message,
              isMine: isMine,
              showSender: false,
              showTimestamp: showTimestamp,
              currentUserId: currentUserId,
              isPinned: isPinned,
              isHighlighted: isHighlighted,
              localImageBytes: localImageBytes,
              onJumpToQuoted: onJumpToQuoted,
              onImageTap:
                  onImageTap ?? (url) => _openImage(context, url, message),
              onDocumentTap: (url) => DocumentOpenService.open(
                context,
                url: url,
                fileName: message.content.fileName,
                mimeType: message.content.mimeType,
              ),
            ),
            if (message.reactions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: message.reactions
                    .where((r) => r.emoji.isNotEmpty && r.count > 0)
                    .map(
                      (r) {
                        final mine = currentUserId != null &&
                            r.reactedBy(currentUserId!);
                        return InkWell(
                          onTap: () {
                            if (mine && onReact != null) {
                              onReact!(r.emoji);
                              return;
                            }
                            _showReactionPeople(
                              context,
                              emoji: r.emoji,
                              userIds: r.userIds,
                              nameByUserId: nameByUserId,
                            );
                          },
                          onLongPress: () => _showReactionPeople(
                            context,
                            emoji: r.emoji,
                            userIds: r.userIds,
                            nameByUserId: nameByUserId,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.tealPrimary
                                      .withValues(alpha: 0.15)
                                  : AppColors.surfaceInput,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: mine
                                    ? AppColors.tealPrimary
                                    : AppColors.borderDefault,
                              ),
                            ),
                            child: Text(
                              '${r.emoji} ${r.count}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    )
                    .toList(),
              ),
            ],
            if (onOpenThread != null && !message.localOnly) ...[
              const SizedBox(height: 4),
              ThreadCountBadge(
                replyCount: message.replyCount,
                onTap: onOpenThread,
                alwaysShow: message.replyCount > 0,
              ),
            ],
            if (isMine &&
                isDm &&
                showReadReceipts &&
                !message.localOnly &&
                message.readBy.isNotEmpty)
              ReadReceiptFooter(
                message: message,
                nameByUserId: nameByUserId,
              ),
          ],
        ),
      ),
    );

    // Swipe follows the finger, then snaps back. A short drag quotes the message.
    final canSwipe = onQuoteReply != null && !message.localOnly;
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: !canSwipe
          ? bubble
          : _FingerSwipeReply(
              fromLeft: !isMine,
              onReply: () => onQuoteReply?.call(),
              child: bubble,
            ),
    );
  }

  static String _senderLabel(
    MessageModel message,
    Map<String, String> nameByUserId,
  ) {
    final fromSender = message.sender.displayName.trim();
    if (fromSender.isNotEmpty) return fromSender;
    final mapped = nameByUserId[message.sender.id]?.trim() ?? '';
    return mapped.isNotEmpty ? mapped : 'Colleague';
  }
}

void _showReactionPeople(
  BuildContext context, {
  required String emoji,
  required List<String> userIds,
  required Map<String, String> nameByUserId,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceCard,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  '$emoji reacted',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final id in userIds)
                ListTile(
                  dense: true,
                  title: Text(
                    nameByUserId[id]?.trim().isNotEmpty == true
                        ? nameByUserId[id]!.trim()
                        : 'Colleague',
                  ),
                ),
              if (userIds.isEmpty)
                const ListTile(
                  dense: true,
                  title: Text('No one yet'),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Horizontal drag stays 1:1 with the finger and never travels the screen width.
class _FingerSwipeReply extends StatefulWidget {
  const _FingerSwipeReply({
    required this.child,
    required this.fromLeft,
    required this.onReply,
  });

  final Widget child;
  final bool fromLeft;
  final VoidCallback onReply;

  @override
  State<_FingerSwipeReply> createState() => _FingerSwipeReplyState();
}

class _FingerSwipeReplyState extends State<_FingerSwipeReply> {
  static const double _maxTravel = 64;
  static const double _trigger = 36;
  double _dx = 0;

  void _onUpdate(DragUpdateDetails details) {
    final next = widget.fromLeft
        ? (_dx + details.delta.dx).clamp(0.0, _maxTravel)
        : (_dx + details.delta.dx).clamp(-_maxTravel, 0.0);
    if (next == _dx) return;
    setState(() => _dx = next);
  }

  void _onEnd(DragEndDetails _) {
    final fired = widget.fromLeft ? _dx >= _trigger : _dx <= -_trigger;
    setState(() => _dx = 0);
    if (fired) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    final showIcon = _dx.abs() > 8;
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      child: Stack(
        alignment: widget.fromLeft ? Alignment.centerLeft : Alignment.centerRight,
        children: [
          if (showIcon)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.reply,
                color: AppColors.tealDark.withValues(
                  alpha: (_dx.abs() / _maxTravel).clamp(0.35, 1),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    required this.message,
    required this.isMine,
    required this.showSender,
    required this.showTimestamp,
    required this.onImageTap,
    required this.onDocumentTap,
    this.currentUserId,
    this.isPinned = false,
    this.isHighlighted = false,
    this.localImageBytes,
    this.onJumpToQuoted,
    super.key,
  });

  final MessageModel message;
  final bool isMine;
  final bool showSender;
  final bool showTimestamp;
  final void Function(String url) onImageTap;
  final void Function(String url) onDocumentTap;
  final String? currentUserId;
  final bool isPinned;
  final bool isHighlighted;
  final List<int>? localImageBytes;
  final VoidCallback? onJumpToQuoted;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? DateFormat.jm().format(message.createdAt!.toLocal())
        : '';
    final textColor =
        isMine ? AppColors.textOnDark : AppColors.textPrimary;
    final timestampColor =
        isMine ? AppColors.textOnDarkMuted : AppColors.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppDecorations.bubble(isMine: isMine).copyWith(
        border: isHighlighted
            ? Border.all(color: AppColors.tealPrimary, width: 2)
            : (isPinned && !isMine
                ? Border.all(
                    color: AppColors.tealPrimary.withValues(alpha: 0.55),
                  )
                : null),
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin,
                    size: 12,
                    color: isMine
                        ? AppColors.textOnDarkMuted
                        : AppColors.tealDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pinned',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isMine
                          ? AppColors.textOnDarkMuted
                          : AppColors.tealDark,
                    ),
                  ),
                ],
              ),
            ),
          if (showSender && !isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.sender.displayName,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealDark,
                ),
              ),
            ),
          if (message.hasQuoteReply)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _QuotedReplyPreview(
                replyTo: message.replyTo!,
                isMine: isMine,
                onTap: onJumpToQuoted,
              ),
            ),
          _MessageBody(
            message: message,
            isMine: isMine,
            textColor: textColor,
            currentUserId: currentUserId,
            localImageBytes: localImageBytes,
            onImageTap: onImageTap,
            onDocumentTap: onDocumentTap,
          ),
          if (showTimestamp ||
              (isMine &&
                  message.deliveryState == MessageDeliveryState.failed))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      message.isEdited ? '$time · edited' : time,
                      style: AppTextStyles.timestamp.copyWith(
                        color: timestampColor,
                      ),
                    ),
                  if (isMine &&
                      message.deliveryState ==
                          MessageDeliveryState.failed) ...[
                    if (time.isNotEmpty) const SizedBox(width: 6),
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: AppColors.statusError,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Failed to send',
                      style: AppTextStyles.timestamp.copyWith(
                        color: AppColors.statusError,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// WhatsApp-style quote strip inside a bubble.
class _QuotedReplyPreview extends StatelessWidget {
  const _QuotedReplyPreview({
    required this.replyTo,
    required this.isMine,
    this.onTap,
  });

  final MessageReplyTo replyTo;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isMine ? AppColors.textOnDark : AppColors.tealPrimary;
    final nameColor = isMine ? AppColors.textOnDark : AppColors.tealDark;
    final bodyColor =
        isMine ? AppColors.textOnDarkMuted : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chipValue),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: isMine
                ? Colors.black.withValues(alpha: 0.18)
                : AppColors.surfaceInput,
            borderRadius: BorderRadius.circular(AppRadius.chipValue),
            border: Border(
              left: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyTo.senderName?.trim().isNotEmpty == true
                    ? replyTo.senderName!
                    : 'Message',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: nameColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                replyTo.previewLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: bodyColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Composer bar: “Replying to …” with clear (WhatsApp-style).
class ReplyQuoteBar extends StatelessWidget {
  const ReplyQuoteBar({
    required this.message,
    required this.onCancel,
    super.key,
  });

  final MessageModel message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderDefault),
            left: BorderSide(color: AppColors.tealPrimary, width: 3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.reply, size: 18, color: AppColors.tealDark),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to ${message.sender.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.tealDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cancel reply',
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 20),
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.onImageTap,
    required this.onDocumentTap,
    this.currentUserId,
    this.localImageBytes,
  });

  final MessageModel message;
  final bool isMine;
  final Color textColor;
  final void Function(String url) onImageTap;
  final void Function(String url) onDocumentTap;
  final String? currentUserId;
  final List<int>? localImageBytes;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: (isMine ? AppTextStyles.bubbleMine : AppTextStyles.bubbleTheirs)
            .copyWith(
          fontStyle: FontStyle.italic,
          color: isMine
              ? AppColors.textOnDarkMuted
              : AppColors.textSecondary,
        ),
      );
    }

    if (message.type == MessageType.image) {
      final url = message.content.mediaUrl ?? message.content.thumbnailUrl ?? '';
      final bytes = localImageBytes != null
          ? Uint8List.fromList(localImageBytes!)
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatNetworkImage(
            imageUrl: url,
            localBytes: bytes,
            onTap: message.localOnly || url.isEmpty
                ? null
                : () => onImageTap(url),
          ),
          if (message.localOnly) ...[
            const SizedBox(height: 4),
            Text(
              'Uploading…',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isMine
                        ? AppColors.textOnDarkMuted
                        : AppColors.textSecondary,
                  ),
            ),
          ],
          if (message.content.text != null &&
              message.content.text!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            MentionRichText(
              text: message.content.text!,
              mentionIds: message.mentions,
              currentUserId: currentUserId,
              style: (isMine
                      ? AppTextStyles.bubbleMine
                      : AppTextStyles.bubbleTheirs)
                  .copyWith(color: textColor),
            ),
          ],
        ],
      );
    }

    if (message.type == MessageType.video) {
      final name = message.content.fileName ?? 'Video';
      final url = message.content.mediaUrl;
      return InkWell(
        onTap: url != null && !message.localOnly ? () => onDocumentTap(url) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      message.deliveryState == MessageDeliveryState.failed
                          ? 'Failed — tap attach to retry'
                          : message.localOnly
                              ? 'Uploading…'
                              : 'Tap to play',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: message.deliveryState ==
                                    MessageDeliveryState.failed
                                ? AppColors.statusError
                                : AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.type == MessageType.document) {
      final name = message.content.fileName ?? 'Document';
      final url = message.content.mediaUrl;
      return InkWell(
        onTap: url != null && !message.localOnly ? () => onDocumentTap(url) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                name.toLowerCase().endsWith('.pdf')
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.localOnly)
                      Text(
                        'Uploading…',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      )
                    else
                      Text(
                        'Tap to open',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MentionRichText(
      text: message.displayText,
      mentionIds: message.mentions,
      currentUserId: currentUserId,
      style: (isMine ? AppTextStyles.bubbleMine : AppTextStyles.bubbleTheirs)
          .copyWith(color: textColor),
    );
  }
}

/// Compact reply control under a channel message — opens the thread.
/// When [alwaysShow] is true, shows “Reply in thread” even with 0 replies
/// (needed so DMs can start a thread like space chats).
class ThreadCountBadge extends StatelessWidget {
  const ThreadCountBadge({
    required this.replyCount,
    this.onTap,
    this.alwaysShow = false,
    super.key,
  });

  final int replyCount;
  final VoidCallback? onTap;
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    if (replyCount <= 0 && !alwaysShow) return const SizedBox.shrink();
    final label = replyCount <= 0
        ? 'Reply in thread →'
        : replyCount == 1
            ? '1 reply →'
            : '$replyCount replies →';

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.button,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.tealDark,
          ),
        ),
      ),
    );
  }
}

/// Compact bubble for replies inside a thread screen.
class ThreadReplyBubble extends StatelessWidget {
  const ThreadReplyBubble({
    required this.message,
    required this.isMine,
    super.key,
  });

  final MessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: MessageBubbleContent(
          message: message,
          isMine: isMine,
          showSender: !isMine,
          showTimestamp: true,
          onImageTap: (url) => _openImage(context, url, message),
          onDocumentTap: (url) => DocumentOpenService.open(
            context,
            url: url,
            fileName: message.content.fileName,
            mimeType: message.content.mimeType,
          ),
        ),
      ),
    );
  }
}

/// Builds list items with date separators and grouped senders.
class MessageListView extends StatelessWidget {
  const MessageListView({
    required this.items,
    required this.currentUserId,
    required this.onOpenThread,
    this.onQuoteReply,
    this.onImageTap,
    super.key,
  });

  final List<MessageListItem> items;
  final String currentUserId;
  final void Function(MessageModel message) onOpenThread;
  final void Function(MessageModel message)? onQuoteReply;
  final void Function(String url, MessageModel message)? onImageTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          DateSeparatorItem(:final label) => DateSeparatorChip(label: label),
          ChatMessageItem(:final message, :final showSender, :final isMine) =>
            MessageBubble(
              message: message,
              isMine: isMine,
              showSender: showSender,
              onQuoteReply: onQuoteReply == null || message.localOnly
                  ? null
                  : () => onQuoteReply!(message),
              onOpenThread: () => onOpenThread(message),
              onImageTap: onImageTap != null
                  ? (url) => onImageTap!(url, message)
                  : null,
            ),
        };
      },
    );
  }
}

void _openImage(BuildContext context, String url, MessageModel message) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _ImagePreviewRoute(
        imageUrl: url,
        title: message.sender.displayName,
      ),
    ),
  );
}

class _ImagePreviewRoute extends StatelessWidget {
  const _ImagePreviewRoute({required this.imageUrl, this.title});

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: ChatNetworkImage(
            imageUrl: imageUrl,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height * 0.75,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    );
  }
}
