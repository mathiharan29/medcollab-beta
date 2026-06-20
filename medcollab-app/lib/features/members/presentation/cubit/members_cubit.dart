import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/presence/presence_cubit.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/members/data/models/space_member_model.dart';
import 'package:medcollab_app/features/members/data/repositories/member_repository.dart';

part 'members_state.dart';

class MembersCubit extends Cubit<MembersState> {
  MembersCubit({
    required MemberRepository memberRepository,
    required UserRepository userRepository,
    required PresenceCubit presenceCubit,
    required SocketClient socketClient,
    required AuthBloc authBloc,
    required this.spaceId,
    required this.currentUserId,
  })  : _memberRepository = memberRepository,
        _userRepository = userRepository,
        _presenceCubit = presenceCubit,
        _socketClient = socketClient,
        _authBloc = authBloc,
        super(const MembersState()) {
    _connectionSub = _socketClient.connectionStream.listen((connected) {
      if (connected && _hasLoadedOnce) {
        loadMembers(silent: true, refreshPresence: true);
      }
    });
    loadMembers();
  }

  final MemberRepository _memberRepository;
  final UserRepository _userRepository;
  final PresenceCubit _presenceCubit;
  final SocketClient _socketClient;
  final AuthBloc _authBloc;
  final String spaceId;
  final String currentUserId;

  StreamSubscription<bool>? _connectionSub;
  bool _hasLoadedOnce = false;

  Future<void> loadMembers({
    bool silent = false,
    bool refreshPresence = false,
  }) async {
    if (!silent) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final members = await _memberRepository.getSpaceMembers(spaceId);
      if (refreshPresence) {
        _refreshPresenceFromApi(members);
      } else {
        _seedPresenceFromApi(members);
      }
      _hasLoadedOnce = true;
      emit(
        state.copyWith(
          members: _mergePresence(members),
          isLoading: false,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    emit(state.copyWith(searchQuery: trimmed));
    if (trimmed.length < 2) {
      emit(state.copyWith(searchResults: const [], isSearching: false));
      return;
    }

    emit(state.copyWith(isSearching: true, error: null));
    try {
      final users = await _memberRepository.searchMembers(
        query: trimmed,
        spaceId: spaceId,
      );
      emit(state.copyWith(searchResults: users, isSearching: false));
    } on AppException catch (e) {
      emit(state.copyWith(isSearching: false, error: e.message));
    }
  }

  void _seedPresenceFromApi(List<SpaceMemberModel> members) {
    final snapshot = <String, PresenceInfo>{};
    for (final member in members) {
      final userId = member.user.id;
      if (userId.isEmpty) continue;
      snapshot[userId] = PresenceInfo(
        isOnline: member.isOnline,
        status: member.user.availability.status,
        updatedAt: member.user.availability.updatedAt,
      );
    }
    _presenceCubit.mergeApiSnapshot(snapshot);
  }

  void _refreshPresenceFromApi(List<SpaceMemberModel> members) {
    final snapshot = <String, PresenceInfo>{};
    for (final member in members) {
      final userId = member.user.id;
      if (userId.isEmpty) continue;
      snapshot[userId] = PresenceInfo(
        isOnline: member.isOnline,
        status: member.user.availability.status,
        updatedAt: member.user.availability.updatedAt,
      );
    }
    _presenceCubit.refreshFromApi(snapshot);
    if (currentUserId.isNotEmpty && _socketClient.isConnected) {
      final authUser = _authBloc.state.user;
      if (authUser != null) {
        _presenceCubit.applyLocal(
          userId: currentUserId,
          status: authUser.availability.status,
          isOnline: true,
        );
      }
    }
  }

  List<SpaceMemberModel> _mergePresence(List<SpaceMemberModel> members) {
    final authUser = _authBloc.state.user;
    final presenceMap = _presenceCubit.state;

    return members.map((member) {
      final userId = member.user.id;
      final isSelf = userId == currentUserId;
      final presence = presenceMap[userId];

      final resolvedStatus = isSelf && authUser != null
          ? authUser.availability.status
          : (presence?.status ?? member.user.availability.status);

      final resolvedOnline = isSelf && _socketClient.isConnected
          ? true
          : (presence != null ? presence.isOnline : member.isOnline);

      return member.copyWith(
        isOnline: resolvedOnline,
        user: member.user.copyWith(
          availability: member.user.availability.copyWith(
            status: resolvedStatus,
          ),
        ),
      );
    }).toList();
  }

  Future<void> updateMyAvailability(AvailabilityStatus status) async {
    emit(state.copyWith(isUpdatingAvailability: true, error: null));
    try {
      final availability = await _userRepository.updateAvailability(
        status: status,
      );
      _authBloc.add(AuthAvailabilityUpdated(availability));
      _presenceCubit.applyLocal(
        userId: currentUserId,
        status: status,
      );
      emit(state.copyWith(isUpdatingAvailability: false));
      applyPresenceUpdate();
    } on AppException catch (e) {
      emit(state.copyWith(isUpdatingAvailability: false, error: e.message));
    }
  }

  void applyPresenceUpdate() {
    if (state.members.isEmpty) return;
    emit(state.copyWith(members: _mergePresence(state.members)));
  }

  @override
  Future<void> close() {
    _connectionSub?.cancel();
    return super.close();
  }
}
