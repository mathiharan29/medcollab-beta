import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/channels/presentation/widgets/create_channel_dialog.dart';
import 'package:medcollab_app/features/spaces/data/models/channel_model.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateChannelDialog.show(
          context,
          spaceId: widget.spaceId,
          onCreated: (_) => _reload(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Channel'),
      ),
      body: FutureBuilder<SpaceModel>(
        future: _spaceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                Material(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Shift handoffs'),
                    subtitle: const Text(
                      'Structured patient handover between shifts',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      AppRoutes.spaceHandoffsPath(widget.spaceId),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search channels…',
                  leading: const Icon(Icons.search),
                  onChanged: (_) => setState(() {}),
                  trailing: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  '${filtered.length} channel${filtered.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No channels yet'
                              : 'No channels match "${_searchController.text}"',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final channel = filtered[index];
                          return _ChannelTile(
                            channel: channel,
                            onTap: () => context.push(
                              AppRoutes.channelPath(widget.spaceId, channel.id),
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        channel.isPrivate ? Icons.lock_outline : Icons.tag,
        color: isEmergency ? AppColors.emergency : AppColors.textSecondary,
      ),
      title: Text(
        channel.displayName,
        style: TextStyle(
          fontWeight: isEmergency ? FontWeight.w600 : FontWeight.w500,
          color: isEmergency ? AppColors.emergency : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channel.description.isNotEmpty)
            Text(
              channel.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          if (preview != null && preview.isNotEmpty)
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
