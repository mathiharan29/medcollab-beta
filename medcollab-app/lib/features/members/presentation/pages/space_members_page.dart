import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/members/presentation/cubit/members_cubit.dart';
import 'package:medcollab_app/features/members/presentation/widgets/member_widgets.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_empty_state.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_search_bar.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_skeleton.dart';
import 'package:medcollab_app/shared/presentation/widgets/error_banner.dart';

/// Space member list with search and presence indicators.
class SpaceMembersPage extends StatefulWidget {
  const SpaceMembersPage({
    required this.spaceId,
    this.spaceName,
    super.key,
  });

  final String spaceId;
  final String? spaceName;

  @override
  State<SpaceMembersPage> createState() => _SpaceMembersPageState();
}

class _SpaceMembersPageState extends State<SpaceMembersPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.instance;

    return BlocProvider(
      create: (_) => MembersCubit(
        memberRepository: deps.memberRepository,
        userRepository: deps.userRepository,
        presenceCubit: deps.presenceCubit,
        socketClient: deps.socketClient,
        authBloc: deps.authBloc,
        spaceId: widget.spaceId,
        currentUserId: context.read<AuthBloc>().state.user?.id ?? '',
      ),
      child: BlocListener<PresenceCubit, Map<String, PresenceInfo>>(
        bloc: deps.presenceCubit,
        listener: (context, _) {
          context.read<MembersCubit>().applyPresenceUpdate();
        },
        child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(
                title: Text(widget.spaceName ?? 'Members'),
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AppSearchBar(
                      controller: _searchController,
                      hintText: 'Search members…',
                      onChanged: (q) {
                        setState(() {});
                        context.read<MembersCubit>().search(q);
                      },
                      onClear: () {
                        _searchController.clear();
                        setState(() {});
                        context.read<MembersCubit>().search('');
                      },
                    ),
                  ),
                  _PresencePicker(),
                  Expanded(
                    child: BlocBuilder<MembersCubit, MembersState>(
                      builder: (context, state) {
                        if (state.isLoading && state.members.isEmpty) {
                          return const AppListSkeleton();
                        }

                        final members = state.filteredMembers;
                        return Column(
                          children: [
                            if (state.error != null)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: ErrorBanner(message: state.error!),
                              ),
                            Expanded(
                              child: members.isEmpty
                                  ? AppEmptyState(
                                      icon: Icons.people_outline,
                                      title: state.searchQuery.isEmpty
                                          ? 'No members found'
                                          : 'No matches found',
                                      subtitle: state.searchQuery.isEmpty
                                          ? null
                                          : 'Try a different search term.',
                                    )
                                  : ListView.separated(
                                      itemCount: members.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final member = members[index];
                                        return MemberListTile(
                                          member: member,
                                          onTap: () => UserProfileSheet.show(
                                            context,
                                            member,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
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
  }
}

class _PresencePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final current = user?.availability.status ?? AvailabilityStatus.available;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: AvailabilityStatusLabel.quickPresenceOptions.map((status) {
          final selected = status == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(status.presenceLabel),
              selected: selected,
              onSelected: (_) {
                context.read<MembersCubit>().updateMyAvailability(status);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
