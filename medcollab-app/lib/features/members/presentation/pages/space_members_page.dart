import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/members/presentation/cubit/members_cubit.dart';
import 'package:medcollab_app/features/members/presentation/widgets/member_widgets.dart';
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
        spaceId: widget.spaceId,
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
                    child: SearchBar(
                      controller: _searchController,
                      hintText: 'Search members…',
                      leading: const Icon(Icons.search),
                      onChanged: (q) =>
                          context.read<MembersCubit>().search(q),
                      trailing: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<MembersCubit>().search('');
                            },
                          ),
                      ],
                    ),
                  ),
                  _PresencePicker(),
                  Expanded(
                    child: BlocBuilder<MembersCubit, MembersState>(
                      builder: (context, state) {
                        if (state.isLoading && state.members.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                                  ? Center(
                                      child: Text(
                                        state.searchQuery.isEmpty
                                            ? 'No members found'
                                            : 'No members match "${state.searchQuery}"',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
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
