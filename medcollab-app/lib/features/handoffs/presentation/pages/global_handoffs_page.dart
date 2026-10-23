import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/global_handoffs_cubit.dart';
import 'package:medcollab_app/features/handoffs/presentation/widgets/handoff_card.dart';
import 'package:medcollab_app/features/spaces/data/models/space_model.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

class GlobalHandoffsPage extends StatelessWidget {
  const GlobalHandoffsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.id ?? '';
    return BlocProvider(
      create: (_) => GlobalHandoffsCubit(
        handoffRepository: AppDependencies.instance.handoffRepository,
        socketClient: AppDependencies.instance.socketClient,
        currentUserId: userId,
      ),
      child: const _GlobalHandoffsView(),
    );
  }
}

class _GlobalHandoffsView extends StatefulWidget {
  const _GlobalHandoffsView();

  @override
  State<_GlobalHandoffsView> createState() => _GlobalHandoffsViewState();
}

class _GlobalHandoffsViewState extends State<_GlobalHandoffsView> {
  final _searchController = TextEditingController();
  late final PageController _pageController;
  bool _searchOpen = false;
  List<SpaceModel>? _cachedSpaces;
  bool _syncingPage = false;

  static const _filters = GlobalHandoffFilter.values;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: GlobalHandoffFilter.pending.index,
    );
    // Prefetch spaces so "+" opens instantly.
    _prefetchSpaces();
  }

  Future<void> _prefetchSpaces() async {
    try {
      final spaces =
          await AppDependencies.instance.spaceRepository.getMySpaces();
      if (mounted) _cachedSpaces = spaces;
    } catch (_) {
      // Ignore — create flow will fetch again if needed.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _createHandoff() async {
    var spaces = _cachedSpaces;
    if (spaces == null) {
      spaces = await AppDependencies.instance.spaceRepository.getMySpaces();
      if (mounted) _cachedSpaces = spaces;
    }
    if (!mounted) return;
    if (spaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join a group to create a handoff')),
      );
      return;
    }

    SpaceModel? space = spaces.length == 1 ? spaces.first : null;
    space ??= await showModalBottomSheet<SpaceModel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Create handoff in which group?'),
              ),
              ...spaces!.map(
                (item) => ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(item.name),
                  onTap: () => Navigator.of(sheetContext).pop(item),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (space == null || !mounted) return;
    await context.push(AppRoutes.spaceHandoffCreatePath(space.id));
    if (mounted) {
      await context.read<GlobalHandoffsCubit>().load();
    }
  }

  void _onFilterTap(GlobalHandoffFilter filter) {
    context.read<GlobalHandoffsCubit>().setFilter(filter);
    final page = filter.index;
    if (_pageController.hasClients &&
        (_pageController.page?.round() ?? page) != page) {
      _syncingPage = true;
      _pageController
          .animateToPage(
            page,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _syncingPage = false);
    }
  }

  void _onPageChanged(int index) {
    if (_syncingPage) return;
    final filter = _filters[index];
    final cubit = context.read<GlobalHandoffsCubit>();
    if (cubit.state.filter != filter) {
      cubit.setFilter(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppGaps.screenH,
                12,
                AppGaps.screenH,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Handoffs', style: AppTextStyles.screenTitle),
                  ),
                  _TealIconButton(
                    icon: Icons.search,
                    tooltip: 'Search',
                    onPressed: () {
                      setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) {
                          _searchController.clear();
                          context.read<GlobalHandoffsCubit>().search('');
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _TealIconButton(
                    icon: Icons.add,
                    tooltip: 'New handoff',
                    onPressed: _createHandoff,
                  ),
                ],
              ),
            ),
            if (_searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppGaps.screenH,
                  0,
                  AppGaps.screenH,
                  8,
                ),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'Search handoffs…',
                  onChanged: (q) =>
                      context.read<GlobalHandoffsCubit>().search(q),
                  onClear: () =>
                      context.read<GlobalHandoffsCubit>().search(''),
                ),
              ),
            BlocBuilder<GlobalHandoffsCubit, GlobalHandoffsState>(
              buildWhen: (p, n) => p.filter != n.filter,
              builder: (context, state) {
                return SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppGaps.screenH,
                    ),
                    children: [
                      for (final filter in _filters) ...[
                        _FilterPill(
                          label: _filterLabel(filter),
                          selected: state.filter == filter,
                          onTap: () => _onFilterTap(filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<GlobalHandoffsCubit, GlobalHandoffsState>(
                builder: (context, state) {
                  if (state.isLoading && state.handoffs.isEmpty) {
                    return const AppListSkeleton();
                  }
                  if (state.error != null && state.handoffs.isEmpty) {
                    return Center(child: ErrorBanner(message: state.error!));
                  }

                  return PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _filters.length,
                    itemBuilder: (context, pageIndex) {
                      final filter = _filters[pageIndex];
                      final handoffs = state.handoffsForFilter(filter);
                      if (handoffs.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No handoffs here',
                          subtitle:
                              'Handoffs track critical or cross-cover patients — '
                              'not your full ward list. Swipe to switch Pending, Active, Done.',
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () =>
                            context.read<GlobalHandoffsCubit>().load(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppGaps.screenH,
                            4,
                            AppGaps.screenH,
                            AppGaps.sectionGap,
                          ),
                          itemCount: handoffs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppGaps.itemGap + 2),
                          itemBuilder: (context, index) {
                            final handoff = handoffs[index];
                            return HandoffCard(
                              handoff: handoff,
                              onTap: () async {
                                final cubit =
                                    context.read<GlobalHandoffsCubit>();
                                await context.push(
                                  AppRoutes.spaceHandoffDetailPath(
                                    handoff.spaceId,
                                    handoff.id,
                                  ),
                                );
                                // Reload so reassigned items move to the
                                // Reassigned tab instead of vanishing.
                                if (!cubit.isClosed) await cubit.load();
                              },
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(GlobalHandoffFilter filter) => switch (filter) {
        GlobalHandoffFilter.pending => 'Pending',
        GlobalHandoffFilter.active => 'Active',
        GlobalHandoffFilter.completed => 'Done',
        GlobalHandoffFilter.drafts => 'Drafts',
        GlobalHandoffFilter.reassigned => 'Reassigned',
      };
}

class _TealIconButton extends StatelessWidget {
  const _TealIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.tealTint,
        borderRadius: AppRadius.button,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.button,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: AppColors.tealDark),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navyPrimary : AppColors.surfaceCard,
      borderRadius: AppRadius.pill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pill,
            border: selected
                ? null
                : Border.all(color: AppColors.borderDefault, width: 0.5),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textOnDark : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
