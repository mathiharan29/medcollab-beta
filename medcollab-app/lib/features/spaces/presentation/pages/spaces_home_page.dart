import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_spacing.dart';
import 'package:medcollab_app/core/utils/phone_utils.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/features/spaces/presentation/widgets/create_space_dialog.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_fab.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

/// Lists clinical groups (spaces) the doctor belongs to.
/// Reached from Profile → My Groups. Sign-out lives on Profile only.
class SpacesHomePage extends StatefulWidget {
  const SpacesHomePage({super.key});

  @override
  State<SpacesHomePage> createState() => _SpacesHomePageState();
}

class _SpacesHomePageState extends State<SpacesHomePage>
    with WidgetsBindingObserver {
  final _spaceRepository = AppDependencies.instance.spaceRepository;
  late Future<List<SpaceModel>> _spacesFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _spacesFuture = _spaceRepository.getMySpaces();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _spacesFuture = _spaceRepository.getMySpaces();
    });
    AppDependencies.instance.socketClient.syncSpaceRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            onPressed: () => _showJoinDialog(context),
            icon: const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            tooltip: 'Scan / paste invite',
            onPressed: () => context.push(AppRoutes.scanInviteQr),
            icon: const Icon(Icons.qr_code_2_outlined),
          ),
        ],
      ),
      floatingActionButton: AppFab(
        label: 'New group',
        onPressed: () => _showCreateDialog(context),
      ),
      body: FutureBuilder<List<SpaceModel>>(
        future: _spacesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppListSkeleton();
          }

          if (snapshot.hasError) {
            final message = snapshot.error is AppException
                ? (snapshot.error as AppException).message
                : 'Could not load spaces';
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

          final spaces = snapshot.data ?? [];
          if (spaces.isEmpty) {
            return AppEmptyState(
              icon: Icons.domain_outlined,
              title: 'Your clinical groups live here',
              subtitle:
                  'Join with an invite code from a colleague, or create a '
                  'department space to start collaborating.',
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showJoinDialog(context),
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Join with invite code'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create a group'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.md,
              ),
              itemCount: spaces.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final space = spaces[index];
                return Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    leading: AppAvatar(
                      name: space.name,
                      size: 40,
                    ),
                    title: Text(
                      space.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      '${space.channels.length} channels · ${space.type.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onTap: () async {
                      await AppDependencies.instance.recentItemsService
                          .recordSpaceVisit(
                        spaceId: space.id,
                        name: space.name,
                      );
                      await context.push(AppRoutes.spaceDetailPath(space.id));
                      if (mounted) _reload();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final created = await CreateSpaceDialog.show(context);
    if (created && mounted) _reload();
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final codeController = TextEditingController();

    final joined = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Invite code or link',
                hintText: 'A3K7BX or invite URL',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx, false);
                context.push(AppRoutes.scanInviteQr);
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final extracted = PhoneUtils.extractInviteCode(
                    codeController.text,
                  ) ??
                  codeController.text.trim().toUpperCase();
              if (extracted.length < 4) return;
              try {
                await _spaceRepository.joinSpace(extracted);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        e is AppException ? e.message : 'Invalid code',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );

    codeController.dispose();
    if (joined == true) _reload();
  }
}
