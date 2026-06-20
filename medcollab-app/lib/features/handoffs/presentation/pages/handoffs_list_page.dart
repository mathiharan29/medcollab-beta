import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoffs_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_widgets.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_fab.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class HandoffsListPage extends StatefulWidget {
  const HandoffsListPage({
    required this.spaceId,
    this.spaceName,
    super.key,
  });

  final String spaceId;
  final String? spaceName;

  @override
  State<HandoffsListPage> createState() => _HandoffsListPageState();
}

class _HandoffsListPageState extends State<HandoffsListPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AppDependencies.instance.socketClient.syncSpaceRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';
    final routeExtra = GoRouterState.of(context).extra;
    final initialHandoff =
        routeExtra is HandoffModel ? routeExtra : null;

    return BlocProvider(
      create: (_) => HandoffsCubit(
        handoffRepository: deps.handoffRepository,
        socketClient: deps.socketClient,
        spaceId: widget.spaceId,
        currentUserId: currentUserId,
        initialHandoff: initialHandoff,
      ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.spaceName ?? 'Handoffs'),
            ),
            floatingActionButton: AppFab(
              label: 'New handoff',
              icon: Icons.assignment_outlined,
              onPressed: () async {
                final result = await context.push<HandoffModel>(
                  AppRoutes.spaceHandoffCreatePath(widget.spaceId),
                );
                if (context.mounted && result != null) {
                  context.read<HandoffsCubit>().applyHandoff(result);
                }
              },
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'Search handoffs…',
                    onChanged: (q) =>
                        context.read<HandoffsCubit>().search(q),
                    onClear: () =>
                        context.read<HandoffsCubit>().search(''),
                  ),
                ),
                BlocBuilder<HandoffsCubit, HandoffsState>(
                  buildWhen: (p, n) => p.filter != n.filter,
                  builder: (context, state) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<HandoffListFilter>(
                        segments: const [
                          ButtonSegment(
                            value: HandoffListFilter.active,
                            label: Text('Active'),
                            icon: Icon(Icons.pending_actions),
                          ),
                          ButtonSegment(
                            value: HandoffListFilter.archived,
                            label: Text('Archived'),
                            icon: Icon(Icons.archive_outlined),
                          ),
                        ],
                        selected: {state.filter},
                        onSelectionChanged: (s) => context
                            .read<HandoffsCubit>()
                            .setFilter(s.first),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: BlocBuilder<HandoffsCubit, HandoffsState>(
                    builder: (context, state) {
                      if (state.isLoading && state.handoffs.isEmpty) {
                        return const AppCardSkeleton();
                      }

                      final items = state.visibleHandoffs;
                      return RefreshIndicator(
                        onRefresh: () =>
                            context.read<HandoffsCubit>().loadHandoffs(),
                        child: Column(
                          children: [
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: ErrorBanner(message: state.error!),
                              ),
                            Expanded(
                              child: items.isEmpty
                                  ? AppEmptyState(
                                      icon: Icons.assignment_outlined,
                                      title: state.searchQuery.isEmpty
                                          ? 'No ${state.filter == HandoffListFilter.active ? 'active' : 'archived'} handoffs'
                                          : 'No matches found',
                                      subtitle: state.searchQuery.isEmpty
                                          ? 'Create a handoff to transfer patient responsibility.'
                                          : 'Try a different search term.',
                                    )
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 88),
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        final handoff = items[index];
                                        final canArchive = handoff.isDraft &&
                                                handoff.fromUser.id ==
                                                    currentUserId ||
                                            handoff.status ==
                                                    HandoffStatus.submitted &&
                                                handoff.toUser.id ==
                                                    currentUserId;
                                        return HandoffListTile(
                                          handoff: handoff,
                                          onTap: () async {
                                            final result =
                                                await context.push<HandoffModel>(
                                              AppRoutes.spaceHandoffDetailPath(
                                                widget.spaceId,
                                                handoff.id,
                                              ),
                                            );
                                            if (context.mounted &&
                                                result != null) {
                                              context
                                                  .read<HandoffsCubit>()
                                                  .applyHandoff(result);
                                            }
                                          },
                                          onArchive: canArchive
                                              ? () => context
                                                  .read<HandoffsCubit>()
                                                  .archiveHandoff(handoff)
                                              : null,
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
              ],
            ),
          );
        },
      ),
    );
  }
}
