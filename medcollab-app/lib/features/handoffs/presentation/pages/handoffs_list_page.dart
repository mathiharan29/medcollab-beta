import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoffs_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_widgets.dart';
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;
    final currentUserId =
        context.read<AuthBloc>().state.user?.id ?? '';

    return BlocProvider(
      create: (_) => HandoffsCubit(
        handoffRepository: deps.handoffRepository,
        socketClient: deps.socketClient,
        spaceId: widget.spaceId,
        currentUserId: currentUserId,
      ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.spaceName ?? 'Handoffs'),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => context.push(
                AppRoutes.spaceHandoffCreatePath(widget.spaceId),
              ),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('New handoff'),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search handoffs…',
                    leading: const Icon(Icons.search),
                    onChanged: (q) =>
                        context.read<HandoffsCubit>().search(q),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<HandoffsCubit>().search('');
                          },
                        ),
                    ],
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
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
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
                                  ? ListView(
                                      children: [
                                        const SizedBox(height: 80),
                                        Icon(
                                          Icons.assignment_outlined,
                                          size: 48,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: Text(
                                            state.searchQuery.isEmpty
                                                ? 'No ${state.filter == HandoffListFilter.active ? 'active' : 'archived'} handoffs'
                                                : 'No matches for "${state.searchQuery}"',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ),
                                      ],
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
                                          onTap: () => context.push(
                                            AppRoutes.spaceHandoffDetailPath(
                                              widget.spaceId,
                                              handoff.id,
                                            ),
                                          ),
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
