import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_decorations.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/features/messages/data/models/message_delivery_state.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/data/models/thread_reply_preview.dart';
import 'package:medcollab_app/features/messages/presentation/utils/message_list_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Text input bar with attach menu — gallery, camera, document.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    required this.controller,
    required this.onSend,
    this.onPickGallery,
    this.onPickCamera,
    this.onPickDocument,
    this.hintText = 'Message…',
    this.isBusy = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickDocument;
  final String hintText;
  final bool isBusy;

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
              title: const Text('Gallery'),
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
              leading: const Icon(Icons.attach_file_outlined),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onPickGallery != null || onPickDocument != null)
                IconButton(
                  onPressed: isBusy ? null : () => _showAttachMenu(context),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.textSecondary,
                  tooltip: 'Attach',
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !isBusy,
                  decoration: InputDecoration(
                    hintText: hintText,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onSubmitted: isBusy ? null : onSend,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.surfaceVariant,
                ),
                onPressed: isBusy ? null : () => onSend(controller.text),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 20),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

/// Root message pinned at the top of a thread screen.
class ParentMessagePreview extends StatelessWidget {
  const ParentMessagePreview({required this.message, super.key});

  final MessageModel message;

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
              'Thread',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            MessageBubbleContent(
              message: message,
              isMine: false,
              showSender: true,
              showTimestamp: true,
              onImageTap: (url) => _openImage(context, url, message),
              onDocumentTap: (url) => _openUrl(url),
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
    this.onOpenThread,
    this.onImageTap,
    super.key,
  });

  final MessageModel message;
  final bool isMine;
  final bool showSender;
  final bool showTimestamp;
  final VoidCallback? onOpenThread;
  final void Function(String url)? onImageTap;

  @override
  Widget build(BuildContext context) {
    return Align(
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
            MessageBubbleContent(
              message: message,
              isMine: isMine,
              showSender: showSender,
              showTimestamp: showTimestamp,
              onImageTap: onImageTap ?? (url) => _openImage(context, url, message),
              onDocumentTap: (url) => _openUrl(url),
            ),
            if (message.hasThread) ...[
              const SizedBox(height: 4),
              ThreadCountBadge(
                replyCount: message.replyCount,
                lastReply: message.lastReply,
                onTap: onOpenThread,
              ),
            ],
            if (onOpenThread != null)
              TextButton(
                onPressed: onOpenThread,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  message.hasThread ? 'View thread' : 'Reply in thread',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ),
          ],
        ),
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
    super.key,
  });

  final MessageModel message;
  final bool isMine;
  final bool showSender;
  final bool showTimestamp;
  final void Function(String url) onImageTap;
  final void Function(String url) onDocumentTap;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? DateFormat.jm().format(message.createdAt!.toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: AppDecorations.bubble(isMine: isMine),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !isMine)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.sender.displayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          _MessageBody(
            message: message,
            onImageTap: onImageTap,
            onDocumentTap: onDocumentTap,
          ),
          if (showTimestamp || (isMine && message.deliveryState != null))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  if (isMine && message.deliveryState != null) ...[
                    const SizedBox(width: 6),
                    _DeliveryIndicator(state: message.deliveryState!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.message,
    required this.onImageTap,
    required this.onDocumentTap,
  });

  final MessageModel message;
  final void Function(String url) onImageTap;
  final void Function(String url) onDocumentTap;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
      );
    }

    if (message.type == MessageType.image && message.content.hasMedia) {
      final url = message.content.mediaUrl!;
      final thumb = message.content.thumbnailUrl ?? url;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: message.localOnly ? null : () => onImageTap(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: message.localOnly
                  ? Container(
                      width: 200,
                      height: 140,
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: thumb,
                      width: 220,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 200,
                        height: 140,
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
            ),
          ),
          if (message.content.text != null &&
              message.content.text!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              message.content.text!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
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

    return Text(
      message.displayText,
      style: Theme.of(context).textTheme.bodyMedium,
      softWrap: true,
    );
  }
}

class _DeliveryIndicator extends StatelessWidget {
  const _DeliveryIndicator({required this.state});

  final MessageDeliveryState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      MessageDeliveryState.sending => (
          Icons.schedule,
          AppColors.textSecondary,
        ),
      MessageDeliveryState.sent => (Icons.check, AppColors.success),
      MessageDeliveryState.failed => (Icons.error_outline, AppColors.error),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          state.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Reply count + last-reply preview under a channel message.
class ThreadCountBadge extends StatelessWidget {
  const ThreadCountBadge({
    required this.replyCount,
    this.lastReply,
    this.onTap,
    super.key,
  });

  final int replyCount;
  final ThreadReplyPreview? lastReply;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = replyCount == 1 ? '1 reply' : '$replyCount replies';
    final preview = lastReply?.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          color: AppColors.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (preview != null && preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
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
          onDocumentTap: (url) => _openUrl(url),
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
    this.onImageTap,
    super.key,
  });

  final List<MessageListItem> items;
  final String currentUserId;
  final void Function(MessageModel message) onOpenThread;
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

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        title: title != null ? Text(title!) : null,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white54,
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
