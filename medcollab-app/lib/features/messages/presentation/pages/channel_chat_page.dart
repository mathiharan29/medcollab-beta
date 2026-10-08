import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/core/utils/clinical_formatters.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/bookmarks/presentation/pages/bookmarks_page.dart';
import 'package:medcollab_app/features/channels/data/models/channel_detail_model.dart';
import 'package:medcollab_app/features/media/data/services/media_picker_service.dart';
import 'package:medcollab_app/features/messages/data/models/message_model.dart';
import 'package:medcollab_app/features/messages/presentation/cubit/channel_chat_cubit.dart';
import 'package:medcollab_app/features/messages/presentation/pages/thread_page.dart';
import 'package:medcollab_app/features/messages/presentation/utils/message_list_utils.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/mention_composer.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_widgets.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/peer_profile_card.dart';
import 'package:medcollab_app/features/media/data/services/document_open_service.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/needl_manage_sheets.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/forward_message_sheet.dart';
import 'package:medcollab_app/shared/presentation/widgets/chat_network_image.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/typing_bubble.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';
import 'package:url_launcher/url_launcher.dart';

class ChannelChatPage extends StatefulWidget {
  const ChannelChatPage({
    required this.channelId,
    this.spaceId,
    this.channel,
    super.key,
  });

  /// Null or empty means a direct message channel.
  final String? spaceId;
  final String channelId;
  final ChannelModel? channel;

  bool get isDm => spaceId == null || spaceId!.isEmpty;

  @override
  State<ChannelChatPage> createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage> {
  final _textController = TextEditingController();
  final _composerFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _mediaPicker = MediaPickerService();
  int _lastMessageCount = 0;
  bool _userNearBottom = true;
  List<UserModel> _mentionCandidates = const [];
  List<UserModel> _spaceMembers = const [];
  List<PinnedMessageEntry> _pinnedMessages = const [];
  ChannelModel? _resolvedChannel;
  Timer? _draftDebounce;
  Timer? _typingStopDebounce;
  Timer? _highlightClearTimer;
  bool _isTyping = false;
  String? _highlightMessageId;

  bool get _isDm => widget.isDm;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onDraftChanged);
    _loadChannelContext();
    _loadDraft();
  }

  void _onDraftChanged() {
    final text = _textController.text;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), () {
      AppDependencies.instance.draftMessageService.saveDraft(
        widget.channelId,
        text,
      );
    });
  }

  Future<void> _loadDraft() async {
    final draft = await AppDependencies.instance.draftMessageService
        .getDraft(widget.channelId);
    if (!mounted || draft == null || draft.isEmpty) return;
    _textController.text = draft;
    _textController.selection = TextSelection.collapsed(
      offset: draft.length,
    );
  }

  void _handleTyping(ChannelChatCubit cubit) {
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

  Future<void> _loadChannelContext() async {
    final deps = AppDependencies.instance;
    final selfId = context.read<AuthBloc>().state.user?.id ?? '';

    // Load members and channel detail in parallel.
    final membersFuture = _isDm
        ? deps.channelRepository.getChannelMembers(widget.channelId)
        : deps.memberRepository
            .getSpaceMembers(widget.spaceId!)
            .then((list) => list.map((m) => m.user).toList());
    final detailFuture =
        deps.channelRepository.getChannelById(widget.channelId);

    try {
      final members = await membersFuture;
      if (_isDm) {
        if (mounted) {
          UserModel? peer = widget.channel?.peer;
          peer ??= members.where((m) => m.id != selfId).firstOrNull;
          final isNeedl = members.length > 2 ||
              (widget.channel?.isGroupDm ?? false) ||
              (_resolvedChannel?.isGroupDm ?? false);
          setState(() {
            _mentionCandidates = members;
            _spaceMembers = members;
            if (peer != null) {
              final base = widget.channel ??
                  _resolvedChannel ??
                  ChannelModel(
                    id: widget.channelId,
                    name: isNeedl ? '' : peer.displayName,
                    type: ChannelType.direct,
                    members: members,
                  );
              _resolvedChannel = base.copyWith(
                peer: peer,
                members: members,
                // Never overwrite Needl multi-name title with first peer.
                name: isNeedl
                    ? (base.name.isNotEmpty ? base.name : base.displayName)
                    : peer.displayName,
              );
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _mentionCandidates = members;
            _spaceMembers = _mentionCandidates;
          });
        }
      }
    } catch (_) {}

    try {
      final detail = await detailFuture;
      final fetched = detail.channel;
      if (!_isDm) {
        final spaces = await deps.spaceRepository.getMySpaces();
        final space =
            spaces.where((s) => s.id == widget.spaceId).firstOrNull;
        final spaceName = space?.name ?? '';
        if (spaceName.isNotEmpty) {
          await deps.recentItemsService.recordChannelVisit(
            spaceId: widget.spaceId!,
            channelId: widget.channelId,
            channelName: widget.channel?.name ?? fetched.name,
            spaceName: spaceName,
          );
        }
        if (mounted) {
          setState(() {
            _pinnedMessages = detail.pinnedMessages;
            _resolvedChannel = widget.channel ?? fetched;
          });
        }
      } else if (mounted) {
        UserModel? peer = fetched.peer;
        peer ??= fetched.members.where((m) => m.id != selfId).firstOrNull;
        peer ??= _spaceMembers.where((m) => m.id != selfId).firstOrNull;
        final members = fetched.members.isNotEmpty
            ? fetched.members
            : _spaceMembers;
        final isNeedl = members.length > 2 || fetched.isGroupDm;
        setState(() {
          _pinnedMessages = detail.pinnedMessages;
          _resolvedChannel = fetched.copyWith(
            peer: peer,
            members: members,
            name: isNeedl
                ? fetched.name
                : (peer?.displayName ?? fetched.name),
          );
        });
      }
    } catch (_) {
      if (mounted && widget.channel != null) {
        setState(() => _resolvedChannel = widget.channel);
      }
    }
  }

  Future<void> _refreshPinnedMessages() async {
    try {
      final detail = await AppDependencies.instance.channelRepository
          .getChannelById(widget.channelId);
      if (!mounted) return;
      setState(() => _pinnedMessages = detail.pinnedMessages);
    } catch (_) {
      /* keep current pins */
    }
  }

  bool _isMessagePinned(MessageModel message) {
    if (message.localOnly || message.id.isEmpty) return false;
    final id = message.id.trim();
    return _pinnedMessages.any((p) {
      final pid = (p.messageId.isNotEmpty ? p.messageId : p.message.id).trim();
      return pid.isNotEmpty && pid == id;
    });
  }

  void _applyPinnedMessages(List<PinnedMessageEntry> entries) {
    if (!mounted) return;
    setState(() => _pinnedMessages = entries);
  }

  Future<void> _showPinnedMessagesSheet() async {
    if (_pinnedMessages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pinned messages yet')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          itemCount: _pinnedMessages.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = _pinnedMessages[index];
            final text = entry.message.displayText.trim();
            return ListTile(
              leading: const Icon(Icons.push_pin, color: AppColors.tealDark),
              title: Text(
                text.isEmpty ? 'Pinned message' : text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(entry.message.sender.displayName),
              onTap: () {
                Navigator.pop(ctx);
                _scrollToMessage(entry.message.id);
              },
            );
          },
        ),
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final id = messageId.trim();
    if (id.isEmpty || !_scrollController.hasClients) return;

    final currentUserId = context.read<AuthBloc>().state.user?.id ?? '';
    final messages = context.read<ChannelChatCubit>().state.messages;
    final listItems = buildMessageListItems(
      messages: messages,
      currentUserId: currentUserId,
    );
    final itemIndex = listItems.indexWhere(
      (item) =>
          item is ChatMessageItem &&
          item.message.id.trim() == id &&
          !item.message.localOnly,
    );
    if (itemIndex < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Load older messages to jump to that pin'),
          ),
        );
      }
      return;
    }

    const estimatedItemHeight = 72.0;
    final target = (itemIndex * estimatedItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _typingStopDebounce?.cancel();
    _highlightClearTimer?.cancel();
    // Flush latest draft before leaving so the parent list sees it immediately.
    unawaited(
      AppDependencies.instance.draftMessageService.saveDraft(
        widget.channelId,
        _textController.text,
      ),
    );
    _scrollController.removeListener(_onScroll);
    _textController.removeListener(_onDraftChanged);
    _textController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showDmPeerCard(
    BuildContext context,
    ChannelModel? channel,
  ) async {
    final selfId = context.read<AuthBloc>().state.user?.id ?? '';
    UserModel? peer = channel?.peer;
    peer ??= channel?.members.where((m) => m.id != selfId).firstOrNull;
    peer ??= _spaceMembers.where((m) => m.id != selfId).firstOrNull;

    if (peer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load colleague profile')),
      );
      return;
    }

    try {
      final fresh = await AppDependencies.instance.memberRepository
          .getUserById(peer.id);
      if (!context.mounted) return;
      await showPeerProfileCard(context, user: fresh);
    } catch (_) {
      if (!context.mounted) return;
      await showPeerProfileCard(context, user: peer);
    }
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
      final max = _scrollController.position.maxScrollExtent;
      // Jump on first open so chat never lands mid-thread.
      if (force) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openThread(BuildContext context, MessageModel message) {
    final channel = _resolvedChannel ?? widget.channel;
    final args = ThreadRouteArgs(
      rootMessage: message,
      channel: channel,
    );
    if (_isDm) {
      context.push(
        AppRoutes.dmThreadPath(widget.channelId, message.id),
        extra: args,
      );
    } else {
      context.push(
        AppRoutes.threadPath(widget.spaceId!, widget.channelId, message.id),
        extra: args,
      );
    }
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

  Future<void> _confirmDeleteMessage(
    BuildContext context,
    MessageModel message,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ChannelChatCubit>().deleteMessage(message.id);
    }
  }

  Future<void> _editMessage(BuildContext context, MessageModel message) async {
    final controller = TextEditingController(text: message.content.text ?? '');
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated != null && updated.isNotEmpty && context.mounted) {
      await context.read<ChannelChatCubit>().editMessage(message.id, updated);
    }
  }

  Future<void> _clearDraft() async {
    await AppDependencies.instance.draftMessageService
        .clearDraft(widget.channelId);
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
        notificationRepository: deps.notificationRepository,
        onChannelAlertsCleared: (count) {
          deps.notificationBadgeCubit.setCount(count);
          deps.navBadgesCubit.refresh();
        },
        channelId: widget.channelId,
        currentUserId: currentUserId,
        readReceiptsEnabled: () =>
            deps.authBloc.state.user?.notifications.readReceiptsEnabled ??
            true,
      ),
      child: Builder(
        builder: (context) {
          final channel = _resolvedChannel ?? widget.channel;
          final peer = _dmPeer(channel, currentUserId);
          // Prefer peer name; avoid flashing "Channel" / bare "Direct message".
          final title = _chatTitle(channel, peer);
          final isNeedlChat = _isDm &&
              (channel?.isGroupDm == true || _spaceMembers.length > 2);
          final subtitle = isNeedlChat
              ? '${(_spaceMembers.isNotEmpty ? _spaceMembers : channel?.members ?? const []).length} people · Tap for list'
              : _isDm
                  ? _dmPresenceSubtitle(context, channel)
                  : (channel?.description.trim().isNotEmpty == true
                      ? channel!.description
                      : 'Tap for channel details');
          final peerOnline = !isNeedlChat &&
              peer != null &&
              (context.watch<PresenceCubit>().state[peer.id]?.isOnline ??
                  false);
          final showReadReceipts = _isDm &&
              (context.watch<AuthBloc>().state.user?.notifications
                      .readReceiptsEnabled ??
                  true);
          final nameByUserId = <String, String>{
            for (final m in _spaceMembers)
              if (m.id.isNotEmpty) m.id: m.displayName,
            if (peer != null && peer.id.isNotEmpty)
              peer.id: peer.displayName,
            for (final m in channel?.members ?? const <UserModel>[])
              if (m.id.isNotEmpty) m.id: m.displayName,
          };

          return Scaffold(
            backgroundColor: AppColors.backgroundApp,
            appBar: AppBar(
              backgroundColor: AppColors.navyPrimary,
              foregroundColor: AppColors.textOnDark,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.tealPrimary,
                ),
                tooltip: 'Back',
                onPressed: () async {
                  await AppDependencies.instance.draftMessageService.saveDraft(
                    widget.channelId,
                    _textController.text,
                  );
                  if (!context.mounted) return;
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.messages);
                  }
                },
              ),
              titleSpacing: 0,
              title: InkWell(
                onTap: () {
                  final isNeedl = channel?.isGroupDm == true ||
                      _spaceMembers.length > 2;
                  if (_isDm && isNeedl) {
                    showNeedlMembersSheet(
                      context,
                      members: _spaceMembers.isNotEmpty
                          ? _spaceMembers
                          : (channel?.members ?? const []),
                      title: title,
                    );
                  } else if (_isDm) {
                    _showDmPeerCard(context, channel);
                  } else {
                    _showChatInfo(context, channel, title);
                  }
                },
                borderRadius: AppRadius.button,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isDm && peerOnline
                              ? AppColors.tealPrimary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: AppAvatar(
                        name: title,
                        imageUrl: isNeedlChat ? null : peer?.avatarUrl,
                        size: 36,
                        showPresence: _isDm && !isNeedlChat,
                        isOnline: peerOnline,
                        backgroundColor: AppColors.tealPrimary,
                        foregroundColor: AppColors.navyPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: AppColors.textOnDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: _isDm && peerOnline
                                    ? AppColors.tealPrimary
                                    : AppColors.textOnDarkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textOnDark,
                  ),
                  color: AppColors.surfaceCard,
                  onSelected: (value) async {
                    switch (value) {
                      case 'rename':
                        await showRenameNeedlDialog(
                          context,
                          channelId: widget.channelId,
                          currentName: title,
                        );
                        await _loadChannelContext();
                        return;
                      case 'add_people':
                        await showAddNeedlPeopleSheet(
                          context,
                          channel: channel ??
                              ChannelModel(
                                id: widget.channelId,
                                name: title,
                                type: ChannelType.direct,
                              ),
                          existingMembers: _spaceMembers.isNotEmpty
                              ? _spaceMembers
                              : (channel?.members ?? const []),
                        );
                        return;
                      case 'peer':
                        await _showDmPeerCard(context, channel);
                        return;
                      case 'needl_members':
                        showNeedlMembersSheet(
                          context,
                          members: _spaceMembers.isNotEmpty
                              ? _spaceMembers
                              : (channel?.members ?? const []),
                          title: title,
                        );
                        return;
                      case 'members':
                        final spaceId = widget.spaceId;
                        if (spaceId != null && spaceId.isNotEmpty) {
                          context.push(AppRoutes.spaceMembersPath(spaceId));
                        }
                        return;
                      case 'search':
                        await _showInChatSearch(context);
                        return;
                      case 'info':
                        await _showChatInfo(context, channel, title);
                        return;
                      case 'pinned':
                        await _showPinnedMessagesSheet();
                        return;
                    }
                  },
                  itemBuilder: (ctx) {
                    if (_isDm) {
                      final isNeedl = channel?.isGroupDm == true ||
                          _spaceMembers.length > 2;
                      return [
                        if (isNeedl)
                          const PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Rename Needl'),
                              dense: true,
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'add_people',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.person_add_alt_1_outlined),
                            title: Text('Add people'),
                            dense: true,
                          ),
                        ),
                        if (isNeedl)
                          const PopupMenuItem(
                            value: 'needl_members',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.people_outline),
                              title: Text('People in this Needl'),
                              dense: true,
                            ),
                          )
                        else
                          const PopupMenuItem(
                            value: 'peer',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.person_outline),
                              title: Text('View profile'),
                              dense: true,
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'search',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.search),
                            title: Text('Search'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'info',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.info_outline),
                            title: Text('Chat info'),
                            dense: true,
                          ),
                        ),
                      ];
                    }
                    return const [
                      PopupMenuItem(
                        value: 'info',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.info_outline),
                          title: Text('Channel info'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'members',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.people_outline),
                          title: Text('Members'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'search',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.search),
                          title: Text('Search'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'pinned',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.push_pin_outlined),
                          title: Text('Pinned messages'),
                          dense: true,
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: BlocConsumer<ChannelChatCubit, ChannelChatState>(
                    listenWhen: (prev, next) =>
                        prev.messages.length != next.messages.length ||
                        prev.messages != next.messages,
                    listener: (_, state) {
                      final grew = state.messages.length > _lastMessageCount;
                      final firstPaint =
                          _lastMessageCount == 0 && state.messages.isNotEmpty;
                      _lastMessageCount = state.messages.length;
                      if (firstPaint) {
                        _scrollToBottom(force: true);
                      } else if (grew) {
                        _scrollToBottom();
                      }
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
                                ? _EmptyChatState(isDm: _isDm)
                                : ListView.builder(
                                    key: PageStorageKey('chat-list-${widget.channelId}'),
                                    controller: _scrollController,
                                    cacheExtent: 480,
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
                                            key: GlobalObjectKey(message.id),
                                            message: message,
                                            isMine: isMine,
                                            // Sender names in space channels + Needls (group DMs).
                                            showSender: (!_isDm ||
                                                    isNeedlChat) &&
                                                showSender,
                                            currentUserId: currentUserId,
                                            isDm: _isDm,
                                            showReadReceipts: showReadReceipts,
                                            nameByUserId: nameByUserId,
                                            isPinned: _isMessagePinned(message),
                                            isHighlighted:
                                                _highlightMessageId ==
                                                    message.id,
                                            localImageBytes: state
                                                .localMediaByMessageId[message.id],
                                            onQuoteReply: message.localOnly
                                                ? null
                                                : () {
                                                    context
                                                        .read<ChannelChatCubit>()
                                                        .setPendingReply(message);
                                                    _composerFocusNode.requestFocus();
                                                  },
                                            onJumpToQuoted:
                                                message.hasQuoteReply
                                                    ? () => _jumpToQuoted(
                                                          message.replyTo!
                                                              .messageId,
                                                        )
                                                    : null,
                                            onOpenThread: message.localOnly
                                                ? null
                                                : () => _openThread(
                                                      context,
                                                      message,
                                                    ),
                                            onCopy: () =>
                                                _copyMessage(message),
                                            onEdit: isMine &&
                                                    message.type ==
                                                        MessageType.text
                                                ? () => _editMessage(
                                                      context,
                                                      message,
                                                    )
                                                : null,
                                            onDelete: isMine
                                                ? () => _confirmDeleteMessage(
                                                      context,
                                                      message,
                                                    )
                                                : null,
                                            onBookmark: () => _bookmarkMessage(
                                              message,
                                              channel,
                                            ),
                                            onPin: () => _pinMessage(message),
                                            onUnpin: () =>
                                                _unpinMessage(message),
                                            onForward: () =>
                                                _forwardMessage(message),
                                            onReact: (emoji) => context
                                                .read<ChannelChatCubit>()
                                                .toggleReaction(
                                                  message.id,
                                                  emoji,
                                                ),
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
                      p.isSending != n.isSending ||
                      p.isUploading != n.isUploading ||
                      p.typingUserNames != n.typingUserNames ||
                      p.pendingReply != n.pendingReply,
                  builder: (context, state) {
                    final cubit = context.read<ChannelChatCubit>();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (state.typingUserNames.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TypingBubble(
                                label: state.typingUserNames.join(', '),
                              ),
                            ),
                          ),
                        if (state.pendingReply != null)
                          ReplyQuoteBar(
                            message: state.pendingReply!,
                            onCancel: cubit.clearPendingReply,
                          ),
                        _TypingBinder(
                          controller: _textController,
                          cubit: cubit,
                          onTyping: _handleTyping,
                          child: MentionAwareComposer(
                          controller: _textController,
                          focusNode: _composerFocusNode,
                          mentionCandidates: _mentionCandidates,
                          excludeSelfId: currentUserId,
                          isBusy: state.isSending || state.isUploading,
                          showTopBorder: state.pendingReply == null,
                          onSend: (text, mentions) async {
                            cubit.sendMessage(text, mentions: mentions);
                            _textController.clear();
                            await _clearDraft();
                            _isTyping = false;
                            cubit.emitTypingStop();
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

  String _chatTitle(ChannelModel? channel, UserModel? peer) {
    if (_isDm) {
      final resolved = channel ?? _resolvedChannel;
      if (resolved != null && resolved.isGroupDm) {
        return resolved.displayName;
      }
      final peerName = peer?.displayName.trim() ?? '';
      if (peerName.isNotEmpty) return peerName;
      final fromChannel = channel?.peer?.displayName.trim() ?? '';
      if (fromChannel.isNotEmpty) return fromChannel;
      final name = channel?.displayName.trim() ?? '';
      if (name.isNotEmpty &&
          name.toLowerCase() != 'channel' &&
          name.toLowerCase() != 'direct message' &&
          name.toLowerCase() != 'direct messages') {
        return name;
      }
      return 'Chat';
    }
    final name = channel?.displayName.trim() ?? '';
    if (name.isNotEmpty &&
        name.toLowerCase() != 'channel' &&
        name != '#channel') {
      return name;
    }
    return 'Chat';
  }

  Future<void> _showInChatSearch(BuildContext context) async {
    final messages = context.read<ChannelChatCubit>().state.messages;
    final qController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final q = qController.text.trim().toLowerCase();
                final hits = q.isEmpty
                    ? const <MessageModel>[]
                    : messages
                        .where(
                          (m) =>
                              !m.isDeleted &&
                              m.displayText.toLowerCase().contains(q),
                        )
                        .toList()
                        .reversed
                        .toList();
                return SizedBox(
                  height: MediaQuery.sizeOf(sheetContext).height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Search this chat',
                        style: AppTextStyles.screenTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Only messages in this conversation',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Find in conversation…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: q.isEmpty
                            ? Center(
                                child: Text(
                                  'Type to search messages here only',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : hits.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matches in this chat',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: hits.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final m = hits[i];
                                      return ListTile(
                                        title: Text(
                                          m.displayText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          [
                                            if (!_isDm) m.sender.displayName,
                                            if (m.createdAt != null)
                                              DateFormat.MMMd().add_jm().format(
                                                    m.createdAt!.toLocal(),
                                                  ),
                                          ].where((s) => s.isNotEmpty).join(' · '),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(sheetContext),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    qController.dispose();
  }

  Future<void> _showChatInfo(
    BuildContext context,
    ChannelModel? channel,
    String title,
  ) async {
    final messages = context.read<ChannelChatCubit>().state.messages;
    final media = messages
        .where(
          (m) =>
              !m.isDeleted &&
              (m.type == MessageType.image ||
                  m.type == MessageType.video ||
                  m.type == MessageType.document) &&
              (m.content.mediaUrl?.isNotEmpty ?? false),
        )
        .toList()
        .reversed
        .toList();
    final images = media.where((m) => m.type == MessageType.image).toList();
    final documents = media
        .where(
          (m) =>
              m.type == MessageType.document || m.type == MessageType.video,
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: DefaultTabController(
              length: 3,
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.screenTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isDm
                          ? 'Shared media in this conversation'
                          : (channel?.description.trim().isNotEmpty == true
                              ? channel!.description
                              : 'Channel details, media and files'),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!_isDm) ...[
                      const SizedBox(height: 8),
                      if (channel != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            channel.type == ChannelType.emergency
                                ? Icons.warning_amber_rounded
                                : Icons.tag,
                            color: channel.type == ChannelType.emergency
                                ? AppColors.emergencyRed
                                : AppColors.tealDark,
                          ),
                          title: Text(channel.displayName),
                          subtitle: Text(
                            'Type: ${channel.type.value}'
                            '${channel.isPrivate ? ' · Private' : ''}',
                          ),
                        ),
                      if (widget.spaceId != null &&
                          widget.spaceId!.isNotEmpty) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.groups_outlined,
                            color: AppColors.tealDark,
                          ),
                          title: const Text('Open group (space)'),
                          subtitle: const Text('Members, channels, invites'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.push(
                              AppRoutes.spaceDetailPath(widget.spaceId!),
                            );
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.people_outline,
                            color: AppColors.tealDark,
                          ),
                          title: const Text('View members'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.push(
                              AppRoutes.spaceMembersPath(widget.spaceId!),
                            );
                          },
                        ),
                      ],
                    ],
                    const TabBar(
                      labelColor: AppColors.tealDark,
                      tabs: [
                        Tab(text: 'Media'),
                        Tab(text: 'Docs'),
                        Tab(text: 'Links'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _ChatMediaGrid(messages: images),
                          _ChatDocList(messages: documents),
                          _ChatLinkList(messages: messages),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  UserModel? _dmPeer(ChannelModel? channel, String selfId) {
    UserModel? peer = channel?.peer;
    peer ??= channel?.members.where((m) => m.id != selfId).firstOrNull;
    peer ??= _spaceMembers.where((m) => m.id != selfId).firstOrNull;
    return peer;
  }

  /// Presence (socket online) and duty availability are separate.
  /// Online → "Online · On call". Not connected → always "Offline" (never "Available").
  String? _dmPresenceSubtitle(BuildContext context, ChannelModel? channel) {
    final selfId = context.read<AuthBloc>().state.user?.id ?? '';
    final peer = _dmPeer(channel, selfId);
    final peerId = peer?.id;
    if (peerId == null || peerId.isEmpty) return null;
    final presence = context.watch<PresenceCubit>().state[peerId];
    final isOnline = presence?.isOnline ?? false;
    final status = presence?.status ?? peer?.availability.status;
    final duty = status != null ? availabilityLabel(status) : null;

    if (isOnline) {
      if (duty != null &&
          status != AvailabilityStatus.offline &&
          status != AvailabilityStatus.available) {
        return 'Online · $duty';
      }
      if (duty != null && status == AvailabilityStatus.available) {
        return 'Online · Available';
      }
      return 'Online';
    }
    // Socket offline wins over stale "Available" duty status.
    if (duty != null &&
        status != AvailabilityStatus.available &&
        status != AvailabilityStatus.offline) {
      return 'Offline · $duty';
    }
    return 'Offline';
  }

  Future<void> _pinMessage(MessageModel message) async {
    if (message.localOnly || message.id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait until the message is sent')),
      );
      return;
    }
    if (!_isMessagePinned(message)) {
      setState(() {
        _pinnedMessages = [
          ..._pinnedMessages,
          PinnedMessageEntry(
            messageId: message.id,
            message: message,
            pinnedAt: DateTime.now(),
          ),
        ];
      });
    }
    try {
      final pinned = await AppDependencies.instance.channelRepository.pinMessage(
        widget.channelId,
        message.id,
      );
      if (pinned.isNotEmpty) {
        _applyPinnedMessages(pinned);
      } else {
        await _refreshPinnedMessages();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message pinned')),
        );
      }
    } on AppException catch (e) {
      await _refreshPinnedMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      await _refreshPinnedMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pin message')),
        );
      }
    }
  }

  Future<void> _unpinMessage(MessageModel message) async {
    if (message.id.isEmpty) return;
    setState(() {
      _pinnedMessages = _pinnedMessages
          .where((p) {
            final pid =
                (p.messageId.isNotEmpty ? p.messageId : p.message.id).trim();
            return pid != message.id.trim();
          })
          .toList(growable: false);
    });
    try {
      final pinned =
          await AppDependencies.instance.channelRepository.unpinMessage(
        widget.channelId,
        message.id,
      );
      if (pinned.isNotEmpty || _pinnedMessages.isEmpty) {
        _applyPinnedMessages(pinned);
      } else {
        await _refreshPinnedMessages();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message unpinned')),
        );
      }
    } on AppException catch (e) {
      await _refreshPinnedMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      await _refreshPinnedMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unpin message')),
        );
      }
    }
  }

  Future<void> _forwardMessage(MessageModel message) async {
    await showForwardMessageSheet(
      context,
      message: message,
      sourceChannelId: widget.channelId,
    );
  }

  Future<void> _copyMessage(MessageModel message) async {
    final body = message.displayText.trim();
    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to copy')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  void _jumpToQuoted(String messageId) {
    if (messageId.isEmpty) return;
    final exists = context
        .read<ChannelChatCubit>()
        .state
        .messages
        .any((m) => m.id == messageId);
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message is not loaded in this chat yet'),
        ),
      );
      return;
    }

    setState(() => _highlightMessageId = messageId);
    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _highlightMessageId = null);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = GlobalObjectKey(messageId).currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        alignment: 0.35,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _bookmarkMessage(
    MessageModel message,
    ChannelModel? channel,
  ) async {
    await saveMessageBookmark(
      messageId: message.id,
      channelId: widget.channelId,
      spaceId: widget.spaceId ?? '',
      title: channel?.displayName ?? 'Channel',
      subtitle: message.displayText,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to bookmarks')),
      );
    }
  }
}

class _TypingBinder extends StatefulWidget {
  const _TypingBinder({
    required this.controller,
    required this.cubit,
    required this.onTyping,
    required this.child,
  });

  final TextEditingController controller;
  final ChannelChatCubit cubit;
  final void Function(ChannelChatCubit cubit) onTyping;
  final Widget child;

  @override
  State<_TypingBinder> createState() => _TypingBinderState();
}

class _TypingBinderState extends State<_TypingBinder> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _TypingBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
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

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.isDm});

  final bool isDm;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      subtitle: isDm
          ? 'Send a message to start the conversation.'
          : 'Start a topic — share images, PDFs, or text.\nUse threads to discuss each patient.',
    );
  }
}

class _ChatMediaGrid extends StatelessWidget {
  const _ChatMediaGrid({required this.messages});

  final List<MessageModel> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('No media shared yet'));
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        final url = m.content.thumbnailUrl ?? m.content.mediaUrl ?? '';
        return InkWell(
          key: ValueKey('media-${m.id}'),
          onTap: () {
            final full = m.content.mediaUrl ?? url;
            if (full.isEmpty) return;
            showDialog<void>(
              context: context,
              builder: (ctx) => Dialog(
                child: InteractiveViewer(
                  child: ChatNetworkImage(
                    imageUrl: full,
                    width: 320,
                    height: 320,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
          child: url.isEmpty
              ? Container(color: AppColors.surfaceInput)
              : ChatNetworkImage(
                  imageUrl: url,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: BorderRadius.zero,
                ),
        );
      },
    );
  }
}

class _ChatDocList extends StatelessWidget {
  const _ChatDocList({required this.messages});

  final List<MessageModel> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('No documents shared yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: messages.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final m = messages[index];
          final name = m.content.fileName ?? 'Document';
        final url = m.content.mediaUrl;
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(m.sender.displayName),
          onTap: url == null || url.isEmpty
              ? null
              : () => DocumentOpenService.open(
                    context,
                    url: url,
                    fileName: m.content.fileName ?? name,
                    mimeType: m.content.mimeType,
                  ),
        );
      },
    );
  }
}

class _ChatLinkList extends StatelessWidget {
  const _ChatLinkList({required this.messages});

  final List<MessageModel> messages;

  static final _linkRe = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final links = <String>[];
    for (final m in messages) {
      if (m.isDeleted || m.type != MessageType.text) continue;
      final text = m.content.text ?? '';
      for (final match in _linkRe.allMatches(text)) {
        links.add(match.group(0)!);
      }
    }
    if (links.isEmpty) {
      return const Center(child: Text('No links shared yet'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: links.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final url = links[index];
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        );
      },
    );
  }
}
