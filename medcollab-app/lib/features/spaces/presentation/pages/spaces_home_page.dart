import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

/// Post-auth home — lists spaces the user belongs to.
class SpacesHomePage extends StatefulWidget {
  const SpacesHomePage({super.key});

  @override
  State<SpacesHomePage> createState() => _SpacesHomePageState();
}

class _SpacesHomePageState extends State<SpacesHomePage> {
  final _spaceRepository = AppDependencies.instance.spaceRepository;
  late Future<List<SpaceModel>> _spacesFuture;

  @override
  void initState() {
    super.initState();
    _spacesFuture = _spaceRepository.getMySpaces();
  }

  void _reload() {
    setState(() {
      _spacesFuture = _spaceRepository.getMySpaces();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spaces'),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            onPressed: () => _showJoinDialog(context),
            icon: const Icon(Icons.group_add_outlined),
          ),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => context
                      .read<AuthBloc>()
                      .add(const AuthLogoutRequested()),
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New space'),
      ),
      body: FutureBuilder<List<SpaceModel>>(
        future: _spacesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.domain_outlined,
                      size: 56,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No spaces yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a department space or join with an invite code.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: spaces.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final space = spaces[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      space.name.isNotEmpty
                          ? space.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                  title: Text(space.name),
                  subtitle: Text(
                    '${space.channels.length} channels · ${space.type.value}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.spaceDetailPath(space.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameController = TextEditingController();
    var type = SpaceType.department;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create space'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Space name',
                  hintText: 'e.g. Medicine PG 2024',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SpaceType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: SpaceType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => type = v ?? type),
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
                if (nameController.text.trim().length < 2) return;
                try {
                  await _spaceRepository.createSpace(
                    name: nameController.text.trim(),
                    type: type,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          e is AppException ? e.message : 'Failed to create',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created == true) _reload();
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final codeController = TextEditingController();

    final joined = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join space'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Invite code',
            hintText: 'A3K7BX',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (codeController.text.trim().length < 4) return;
              try {
                await _spaceRepository.joinSpace(codeController.text);
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

    if (joined == true) _reload();
  }
}
