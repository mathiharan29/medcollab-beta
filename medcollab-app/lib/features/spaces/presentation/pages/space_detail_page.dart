import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
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
  late Future<SpaceModel> _spaceFuture;

  @override
  void initState() {
    super.initState();
    _spaceFuture = _spaceRepository.getSpaceById(widget.spaceId);
  }

  void _reload() {
    setState(() {
      _spaceFuture = _spaceRepository.getSpaceById(widget.spaceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<SpaceModel>(
          future: _spaceFuture,
          builder: (context, snapshot) =>
              Text(snapshot.data?.name ?? 'Space'),
        ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Channels',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: channels.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final channel = channels[index];
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
      leading: Icon(
        isEmergency ? Icons.emergency_outlined : Icons.tag,
        color: isEmergency ? AppColors.emergency : AppColors.textSecondary,
      ),
      title: Text(
        channel.displayName,
        style: TextStyle(
          fontWeight: isEmergency ? FontWeight.w600 : FontWeight.w500,
          color: isEmergency ? AppColors.emergency : null,
        ),
      ),
      subtitle: preview != null && preview.isNotEmpty
          ? Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              channel.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }
}
