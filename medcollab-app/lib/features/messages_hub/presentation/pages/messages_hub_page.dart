import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/realtime/typing_presence.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/router/dm_navigation.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/messages/data/models/message_request_model.dart';
import 'package:medcollab_app/features/channels/presentation/widgets/create_channel_dialog.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/last_message_preview.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/features/spaces/presentation/widgets/create_space_dialog.dart';
import 'package:medcollab_app/features/spaces/presentation/widgets/space_invite_share_sheet.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_fab.dart';
import 'package:medcollab_app/features/notifications/presentation/utils/notification_unread_utils.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/dm_row.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';
import 'package:medcollab_app/shared/presentation/widgets/group_row.dart';
import 'package:medcollab_app/shared/presentation/widgets/subgroup_row.dart';

/// Messages hub: Group → subgroups, plus Direct (brief SCREEN 2–3).
class MessagesHubPage extends StatefulWidget {
  const MessagesHubPage({super.key});

  @override
  State<MessagesHubPage> createState() => _MessagesHubPageState();
}

class _MessagesHubPageState extends State<MessagesHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<SpaceModel>> _spacesFuture;
  late Future<List<ChannelModel>> _dmsFuture;
  late Future<List<MessageRequestModel>> _pendingRequestsFuture;
  late Future<Set<String>> _draftIdsFuture;
  late Future<Map<String, int>> _unreadByChannelFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reload();
  }

  void _reload() {
    setState(() {
      _spacesFuture =
          AppDependencies.instance.spaceRepository.getMySpaces();
      _dmsFuture = AppDependencies.instance.channelRepository.getMyDMs();
      _pendingRequestsFuture = AppDependencies.instance.messageRequestRepository
          .listRequests(direction: 'received', status: 'pending')
          .catchError((_) => <MessageRequestModel>[]);
      _draftIdsFuture =
          AppDependencies.instance.draftMessageService.draftChannelIds();
      _unreadByChannelFuture = _loadUnreadByChannel();
    });
  }

  Future<Map<String, int>> _loadUnreadByChannel() async {
    try {
      final page = await AppDependencies.instance.notificationRepository
          .getNotifications(limit: 100);
      return unreadCountsByChannel(page.notifications);
    } catch (_) {
      return const {};
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: Column(
        children: [
          _MessagesHeader(
            tabController: _tabController,
            onSearch: () => context.push(AppRoutes.search),
            onCompose: () => context.push(AppRoutes.startDm),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DirectTab(
                  dmsFuture: _dmsFuture,
                  pendingRequestsFuture: _pendingRequestsFuture,
                  draftIdsFuture: _draftIdsFuture,
                  unreadByChannelFuture: _unreadByChannelFuture,
                  onReload: _reload,
                ),
                _NeedlTab(
                  dmsFuture: _dmsFuture,
                  draftIdsFuture: _draftIdsFuture,
                  unreadByChannelFuture: _unreadByChannelFuture,
                  onReload: _reload,
                ),
                _GroupsTab(
                  spacesFuture: _spacesFuture,
                  draftIdsFuture: _draftIdsFuture,
                  unreadByChannelFuture: _unreadByChannelFuture,
                  onReload: _reload,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    required this.tabController,
    required this.onSearch,
    required this.onCompose,
  });

  final TabController tabController;
  final VoidCallback onSearch;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: AppColors.surfaceCard,
      child: Column(
        children: [
          SizedBox(height: top),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppGaps.screenH,
              8,
              4,
              0,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Messages', style: AppTextStyles.screenTitle),
                ),
                IconButton(
                  tooltip: 'Search',
                  onPressed: onSearch,
                  icon: const Icon(
                    Icons.search,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  tooltip: 'New message',
                  onPressed: onCompose,
                  icon: const Icon(
                    Icons.edit_square,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabController,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTextStyles.cardTitle.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: AppTextStyles.cardTitle.copyWith(
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: AppColors.textMuted,
            ),
            indicatorColor: AppColors.tealPrimary,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppColors.borderLight,
            tabs: const [
              Tab(text: 'Direct'),
              Tab(text: 'Needl'),
              Tab(text: 'Groups'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeedlTab extends StatelessWidget {
  const _NeedlTab({
    required this.dmsFuture,
    required this.draftIdsFuture,
    required this.unreadByChannelFuture,
    required this.onReload,
  });

  final Future<List<ChannelModel>> dmsFuture;
  final Future<Set<String>> draftIdsFuture;
  final Future<Map<String, int>> unreadByChannelFuture;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        dmsFuture,
        draftIdsFuture,
        unreadByChannelFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppListSkeleton();
        }
        if (snapshot.hasError) {
          return const Center(
            child: ErrorBanner(message: 'Could not load Needls'),
          );
        }

        final allDms = snapshot.data![0] as List<ChannelModel>;
        final draftIds = snapshot.data![1] as Set<String>;
        final unreadByChannel = snapshot.data![2] as Map<String, int>;
        final needls = allDms.where((dm) => dm.isGroupDm).toList();

        return RefreshIndicator(
          onRefresh: () async => onReload(),
          child: needls.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(AppGaps.screenH),
                  children: [
                    AppEmptyState(
                      icon: Icons.hub_outlined,
                      title: 'No Needls yet',
                      subtitle:
                          'A Needl is a private chat with two or more '
                          'colleagues that you created or joined — like a '
                          'group DM. Space channels stay under Groups.',
                      action: FilledButton.icon(
                        onPressed: () => context.push(AppRoutes.startDm),
                        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                        label: const Text('Start a Needl'),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppGaps.screenH),
                  itemCount: needls.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppGaps.itemGap),
                  itemBuilder: (context, index) {
                    final needl = needls[index];
                    final preview = needl.lastMessage;
                    final hasDraft = draftIds.contains(needl.id);
                    final memberCount = needl.members.length;
                    final previewText = hasDraft
                        ? (preview != null
                            ? 'Draft · ${preview.previewLabel}'
                            : 'Draft awaiting')
                        : (preview != null
                            ? preview.previewLabel
                            : 'No messages yet');
                    final memberHint = memberCount > 0
                        ? '$memberCount people'
                        : 'Needl';

                    return ListenableBuilder(
                      listenable: TypingPresence.instance,
                      builder: (context, _) {
                        final typing =
                            TypingPresence.instance.labelFor(needl.id);
                        return DMRow(
                          key: ValueKey('needl-${needl.id}'),
                          name: needl.displayName,
                          preview: '$memberHint · $previewText',
                          imageUrl: null,
                          elevated: true,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.tealPrimary
                                  .withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.hub_outlined,
                              size: 20,
                              color: AppColors.tealDark,
                            ),
                          ),
                          timestamp: hasDraft
                              ? null
                              : _formatTimestamp(preview?.sentAt),
                          unreadCount: unreadByChannel[needl.id] ?? 0,
                          isOnline: false,
                          typingLabel: typing,
                          onTap: () async {
                            await openDmChat(
                              context,
                              channelId: needl.id,
                              channel: needl,
                            );
                            onReload();
                          },
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({
    required this.spacesFuture,
    required this.draftIdsFuture,
    required this.unreadByChannelFuture,
    required this.onReload,
  });

  final Future<List<SpaceModel>> spacesFuture;
  final Future<Set<String>> draftIdsFuture;
  final Future<Map<String, int>> unreadByChannelFuture;
  final VoidCallback onReload;

  int _spaceUnread(SpaceModel space, Map<String, int> unreadByChannel) {
    var total = 0;
    for (final channel in space.channels) {
      total += unreadByChannel[channel.id] ?? 0;
    }
    return total;
  }

  Future<void> _createGroup(BuildContext context) async {
    final created = await CreateSpaceDialog.show(context);
    if (created) onReload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AppFab(
        heroTag: 'messages-groups-new-group-fab',
        label: '+ New group',
        icon: Icons.group_add_outlined,
        onPressed: () => _createGroup(context),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        spacesFuture,
        draftIdsFuture,
        unreadByChannelFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppListSkeleton();
        }
        if (snapshot.hasError) {
          return const Center(
            child: ErrorBanner(message: 'Could not load groups'),
          );
        }
        final spaces = snapshot.data![0] as List<SpaceModel>;
        final unreadByChannel =
            snapshot.data![2] as Map<String, int>;

        if (spaces.isEmpty) {
          return AppEmptyState(
            icon: Icons.domain_outlined,
            title: 'No channels yet',
            subtitle:
                'Join a clinical group to see ward and team subgroups here.',
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => context.push(AppRoutes.spacesList),
                  child: const Text('Browse / join groups'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push(AppRoutes.startDm),
                  child: const Text('New message'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => onReload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppGaps.screenH),
            itemCount: spaces.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppGaps.itemGap),
            itemBuilder: (context, index) {
              final space = spaces[index];
              final latest = _latestChannel(space);
              final preview = _groupPreview(latest);
              final timestamp = _formatTimestamp(latest?.lastMessage?.sentAt);

              return GroupRow(
                key: ValueKey('group-${space.id}'),
                name: space.name,
                preview: preview,
                timestamp: timestamp,
                unreadCount: _spaceUnread(space, unreadByChannel),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SpaceSubgroupsPage(
                        space: space,
                        initialUnreadByChannel: unreadByChannel,
                      ),
                    ),
                  );
                  onReload();
                },
              );
            },
          ),
        );
      },
    );
  }

  ChannelModel? _latestChannel(SpaceModel space) {
    if (space.channels.isEmpty) return null;
    final sorted = List<ChannelModel>.of(space.channels)
      ..sort((a, b) {
        final at = a.lastMessage?.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.lastMessage?.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return sorted.first;
  }

  String _groupPreview(ChannelModel? channel) {
    if (channel == null) return 'No subgroups yet';
    final tag = channel.displayName;
    final msg = channel.lastMessage;
    if (msg?.text == null || msg!.text!.isEmpty) {
      return tag;
    }
    final sender = (msg.senderName ?? '').trim();
    if (sender.isEmpty) return '$tag · ${msg.text}';
    return '$tag · $sender: ${msg.text}';
  }
}

/// Group → list of subgroups, with create (+) and live draft badges.
class SpaceSubgroupsPage extends StatefulWidget {
  const SpaceSubgroupsPage({
    required this.space,
    this.initialUnreadByChannel = const {},
    super.key,
  });

  final SpaceModel space;
  final Map<String, int> initialUnreadByChannel;

  @override
  State<SpaceSubgroupsPage> createState() => _SpaceSubgroupsPageState();
}

class _SpaceSubgroupsPageState extends State<SpaceSubgroupsPage> {
  late List<ChannelModel> _channels;
  Set<String> _draftIds = {};
  Map<String, int> _unreadByChannel = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _channels = List.of(widget.space.channels);
    _unreadByChannel = Map.of(widget.initialUnreadByChannel);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final channels = await AppDependencies.instance.channelRepository
          .getSpaceChannels(widget.space.id);
      final drafts =
          await AppDependencies.instance.draftMessageService.draftChannelIds();
      final unread = await _loadUnreadByChannel();
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _draftIds = drafts;
        _unreadByChannel = unread;
        _loading = false;
      });
    } catch (_) {
      final drafts =
          await AppDependencies.instance.draftMessageService.draftChannelIds();
      final unread = await _loadUnreadByChannel();
      if (!mounted) return;
      setState(() {
        _draftIds = drafts;
        _unreadByChannel = unread;
        _loading = false;
      });
    }
  }

  Future<Map<String, int>> _loadUnreadByChannel() async {
    try {
      final page = await AppDependencies.instance.notificationRepository
          .getNotifications(limit: 100);
      return unreadCountsByChannel(page.notifications);
    } catch (_) {
      return Map.of(_unreadByChannel);
    }
  }

  Future<void> _openChannel(ChannelModel channel) async {
    await AppDependencies.instance.recentItemsService.recordChannelVisit(
      spaceId: widget.space.id,
      channelId: channel.id,
      channelName: channel.name,
      spaceName: widget.space.name,
    );
    if (!mounted) return;
    await context.push(
      AppRoutes.channelPath(widget.space.id, channel.id),
      extra: channel,
    );
    await _refresh();
  }

  void _createSubgroup() {
    CreateChannelDialog.show(
      context,
      spaceId: widget.space.id,
      onCreated: (channel) {
        setState(() {
          _channels = [..._channels, channel];
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final channels = List<ChannelModel>.of(_channels)
      ..sort((a, b) {
        final at = a.lastMessage?.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.lastMessage?.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: Column(
        children: [
          Material(
            color: AppColors.surfaceCard,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4,
                top + 4,
                AppGaps.screenH,
                10,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.space.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.screenTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Members',
                    onPressed: () => context.push(
                      AppRoutes.spaceMembersPath(widget.space.id),
                    ),
                    icon: const Icon(
                      Icons.people_outline,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.space.inviteCode != null &&
                      widget.space.inviteCode!.isNotEmpty)
                    IconButton(
                      tooltip: 'Invite code',
                      onPressed: () => SpaceInviteShareSheet.show(
                        context,
                        spaceName: widget.space.name,
                        inviteCode: widget.space.inviteCode!,
                      ),
                      icon: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  Material(
                    color: AppColors.tealPrimary,
                    borderRadius: AppRadius.button,
                    child: InkWell(
                      onTap: _createSubgroup,
                      borderRadius: AppRadius.button,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.add,
                          color: AppColors.textOnDark,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading && channels.isEmpty
                ? const AppListSkeleton()
                : channels.isEmpty
                    ? AppEmptyState(
                        icon: Icons.tag,
                        title: 'No subgroups yet',
                        subtitle: 'Create a subgroup for this clinical team.',
                        action: FilledButton.icon(
                          onPressed: _createSubgroup,
                          icon: const Icon(Icons.add),
                          label: const Text('New subgroup'),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppGaps.screenH),
                          itemCount: channels.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppGaps.itemGap),
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            final preview = channel.lastMessage;
                            final hasDraft = _draftIds.contains(channel.id);
                            final previewText = hasDraft
                                ? 'Draft awaiting'
                                : _subgroupPreviewText(preview);

                            return SubgroupRow(
                              key: ValueKey('sub-${channel.id}'),
                              name: channel.displayName,
                              preview: previewText,
                              type: channel.type,
                              timestamp: hasDraft
                                  ? null
                                  : _formatTimestamp(preview?.sentAt),
                              unreadCount: _unreadByChannel[channel.id] ?? 0,
                              hasDraft: hasDraft,
                              onTap: () => _openChannel(channel),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _subgroupPreviewText(LastMessagePreview? preview) {
    if (preview == null) return 'No new messages';
    final text = preview.text;
    if (text == null || text.isEmpty) return 'No new messages';
    final sender = (preview.senderName ?? '').trim();
    if (sender.isEmpty) return text;
    return '$sender: $text';
  }
}

class _DirectTab extends StatefulWidget {
  const _DirectTab({
    required this.dmsFuture,
    required this.pendingRequestsFuture,
    required this.draftIdsFuture,
    required this.unreadByChannelFuture,
    required this.onReload,
  });

  final Future<List<ChannelModel>> dmsFuture;
  final Future<List<MessageRequestModel>> pendingRequestsFuture;
  final Future<Set<String>> draftIdsFuture;
  final Future<Map<String, int>> unreadByChannelFuture;
  final VoidCallback onReload;

  @override
  State<_DirectTab> createState() => _DirectTabState();
}

class _DirectTabState extends State<_DirectTab> {
  String? _busyRequestId;

  Future<void> _acceptRequest(MessageRequestModel request) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = request.id);
    try {
      final result = await AppDependencies.instance.messageRequestRepository
          .acceptRequest(request.id);
      final channel = result.channel ??
          await AppDependencies.instance.channelRepository
              .createOrGetDM(request.peer.id);
      if (!mounted) return;
      await openDmChat(
        context,
        channelId: channel.id,
        channel: channel,
      );
      widget.onReload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not accept request')),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _declineRequest(String id) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = id);
    try {
      await AppDependencies.instance.messageRequestRepository
          .declineRequest(id);
      widget.onReload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not decline request')),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait([
        widget.dmsFuture,
        widget.pendingRequestsFuture,
        widget.draftIdsFuture,
        widget.unreadByChannelFuture,
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppListSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppGaps.screenH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ErrorBanner(
                    message: 'Could not load direct messages.',
                  ),
                  const SizedBox(height: AppGaps.sectionGap),
                  FilledButton(
                    onPressed: () => context.push(AppRoutes.startDm),
                    child: const Text('New message'),
                  ),
                ],
              ),
            ),
          );
        }

        final allDms = snapshot.data![0] as List<ChannelModel>;
        final pending =
            snapshot.data![1] as List<MessageRequestModel>;
        final draftIds = snapshot.data![2] as Set<String>;
        final unreadByChannel =
            snapshot.data![3] as Map<String, int>;
        // Needls (3+ people) live under the Needl tab — keep Direct 1:1 / notes.
        final dms = allDms.where((dm) => !dm.isGroupDm).toList();

        if (dms.isEmpty && pending.isEmpty) {
          return AppEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No direct messages yet',
            subtitle:
                'Search by name or mobile number to start a private chat. '
                'Doctors outside your network must approve a request first — '
                'no chat or Seen until they accept.',
            action: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.startDm),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('New message'),
            ),
          );
        }

        return BlocBuilder<PresenceCubit, Map<String, PresenceInfo>>(
          builder: (context, presence) {
            return RefreshIndicator(
              onRefresh: () async => widget.onReload(),
              child: ListView(
                padding: const EdgeInsets.all(AppGaps.screenH),
                children: [
                  if (pending.isNotEmpty) ...[
                    Text(
                      'Message requests',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'No chat or Seen until you accept',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppGaps.itemGap),
                    ...pending.map((request) {
                      final busy = _busyRequestId == request.id;
                      final peerLine = [
                        request.peer.role.label,
                        if (request.peer.speciality?.isNotEmpty == true)
                          request.peer.speciality!,
                        if (request.peer.institution?.isNotEmpty == true)
                          request.peer.institution!,
                      ].join(' · ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppGaps.itemGap),
                        child: Material(
                          color: AppColors.surfaceCard,
                          borderRadius: AppRadius.card,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    AppAvatar(
                                      name: request.peer.displayName,
                                      imageUrl: request.peer.avatarUrl,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request.peer.displayName,
                                            style: AppTextStyles.cardTitle,
                                          ),
                                          if (peerLine.isNotEmpty)
                                            Text(
                                              peerLine,
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (request.introMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '"${request.introMessage}"',
                                      style: AppTextStyles.cardTitle.copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () => _declineRequest(request.id),
                                        child: const Text('Decline'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: busy
                                            ? null
                                            : () => _acceptRequest(request),
                                        child: busy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Accept & chat'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (dms.isNotEmpty) ...[
                      const SizedBox(height: AppGaps.sectionGap),
                      Text(
                        'Recent chats',
                        style: AppTextStyles.cardTitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppGaps.itemGap),
                    ],
                  ],
                  ...dms.map((dm) {
                    final preview = dm.lastMessage;
                    final hasDraft = draftIds.contains(dm.id);
                    final peer = dm.peer;
                    final isOnline = peer != null &&
                        (presence[peer.id]?.isOnline ?? false);
                    final previewText = hasDraft
                        ? (preview != null
                            ? 'Draft · ${preview.previewLabel}'
                            : 'Draft awaiting')
                        : (preview != null
                            ? preview.previewLabel
                            : 'No messages yet');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppGaps.itemGap),
                      child: ListenableBuilder(
                        listenable: TypingPresence.instance,
                        builder: (context, _) {
                          final typing =
                              TypingPresence.instance.labelFor(dm.id);
                          return DMRow(
                            key: ValueKey('dm-${dm.id}'),
                            name: dm.displayName,
                            preview: previewText,
                            imageUrl: peer?.avatarUrl,
                            timestamp: hasDraft
                                ? null
                                : _formatTimestamp(preview?.sentAt),
                            unreadCount: unreadByChannel[dm.id] ?? 0,
                            isOnline: isOnline,
                            typingLabel: typing,
                            onTap: () async {
                              await openDmChat(
                                context,
                                channelId: dm.id,
                                channel: dm,
                              );
                              widget.onReload();
                            },
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String? _formatTimestamp(DateTime? sentAt) {
  if (sentAt == null) return null;
  final local = sentAt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  if (day == today) return DateFormat.jm().format(local);
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (now.difference(local).inDays < 7) return DateFormat.E().format(local);
  return DateFormat.MMMd().format(local);
}
