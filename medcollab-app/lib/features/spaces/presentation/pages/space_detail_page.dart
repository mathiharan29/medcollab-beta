import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_fab.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';
import 'package:medcollab_app/features/channels/presentation/widgets/create_channel_dialog.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class SpaceDetailPage extends StatefulWidget {
  const SpaceDetailPage({required this.spaceId, super.key});

  final String spaceId;

  @override
  State<SpaceDetailPage> createState() => _SpaceDetailPageState();
}

class _SpaceDetailPageState extends State<SpaceDetailPage> {
  final _spaceRepository = AppDependencies.instance.spaceRepository;
  final _memberRepository = AppDependencies.instance.memberRepository;
  final _searchController = TextEditingController();
  late Future<SpaceModel> _spaceFuture;
  int? _memberCount;

  @override
  void initState() {
    super.initState();
    _spaceFuture = _spaceRepository.getSpaceById(widget.spaceId);
    _loadMemberCount();
    AppDependencies.instance.socketClient.syncSpaceRooms();
  }

  Future<void> _loadMemberCount() async {
    try {
      final members = await _memberRepository.getSpaceMembers(widget.spaceId);
      if (mounted) setState(() => _memberCount = members.length);
    } catch (_) {
      // Non-blocking — member count is supplementary.
    }
  }

  void _reload() {
    setState(() {
      _spaceFuture = _spaceRepository.getSpaceById(widget.spaceId);
    });
    _loadMemberCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChannelModel> _filterChannels(List<ChannelModel> channels, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return channels;
    return channels
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.description.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<SpaceModel>(
          future: _spaceFuture,
          builder: (context, snapshot) {
            final space = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(space?.name ?? 'Space'),
                if (_memberCount != null)
                  Text(
                    '$_memberCount members',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Handoffs',
            onPressed: () => context.push(
              AppRoutes.spaceHandoffsPath(widget.spaceId),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Members',
            onPressed: () {
              context.push(
                AppRoutes.spaceMembersPath(widget.spaceId),
              );
            },
          ),
        ],
      ),
      floatingActionButton: AppFab(
        label: 'Channel',
        icon: Icons.add,
        onPressed: () => CreateChannelDialog.show(
          context,
          spaceId: widget.spaceId,
          onCreated: (_) => _reload(),
        ),
      ),
      body: FutureBuilder<SpaceModel>(
        future: _spaceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppListSkeleton();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            final message = snapshot.error is AppException
                ? (snapshot.error as AppException).message
                : 'Could not load space';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ErrorBanner(message: message),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final space = snapshot.data!;
          final channels = List<ChannelModel>.from(space.channels)
            ..sort((a, b) => a.position.compareTo(b.position));
          final filtered = _filterChannels(channels, _searchController.text);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (space.inviteCode != null)
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryMuted,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Invite code: ${space.inviteCode}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMuted,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Shift handoffs',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Structured patient handover between shifts',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () => context.push(
                      AppRoutes.spaceHandoffsPath(widget.spaceId),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'Search channels…',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  '${filtered.length} channel${filtered.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? AppEmptyState(
                        icon: Icons.tag_outlined,
                        title: _searchController.text.isEmpty
                            ? 'No channels yet'
                            : 'No matches found',
                        subtitle: _searchController.text.isEmpty
                            ? 'Create a channel to start collaborating.'
                            : 'Try a different search term.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final channel = filtered[index];
                          return _ChannelTile(
                            channel: channel,
                            onTap: () => context.push(
                              AppRoutes.channelPath(
                                widget.spaceId,
                                channel.id,
                              ),
                              extra: channel,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.onTap});

  final ChannelModel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = channel.lastMessage?.text;
    final isEmergency = channel.type == ChannelType.emergency;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isEmergency
                        ? AppColors.emergency.withValues(alpha: 0.08)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: isEmergency
                          ? AppColors.emergency.withValues(alpha: 0.2)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    channel.isPrivate ? Icons.lock_outline : Icons.tag,
                    size: 18,
                    color: isEmergency
                        ? AppColors.emergency
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isEmergency ? AppColors.emergency : null,
                            ),
                      ),
                      if (channel.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          channel.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (preview != null && preview.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
