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
    loadMembers();
  }

  final MemberRepository _memberRepository;
  final UserRepository _userRepository;
  final PresenceCubit _presenceCubit;
  final SocketClient _socketClient;
  final AuthBloc _authBloc;
  final String spaceId;
  final String currentUserId;

  Future<void> loadMembers() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final members = await _memberRepository.getSpaceMembers(spaceId);
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

  Future<void> updateMyAvailability(AvailabilityStatus status) async {
    emit(state.copyWith(isUpdatingAvailability: true, error: null));
    try {
      final availability = await _userRepository.updateAvailability(
        status: status,
      );
      _socketClient.updateAvailability(status: status.value);
      _authBloc.add(AuthAvailabilityUpdated(availability));
      emit(state.copyWith(isUpdatingAvailability: false));
      applyPresenceUpdate();
    } on AppException catch (e) {
      emit(state.copyWith(isUpdatingAvailability: false, error: e.message));
    }
  }

  List<SpaceMemberModel> _mergePresence(List<SpaceMemberModel> members) {
    return members.map((m) {
      final presence = _presenceCubit.state[m.user.id];
      final isSelf = m.user.id == currentUserId;
      final isOnline = presence?.isOnline ??
          (isSelf && _socketClient.isConnected ? true : m.isOnline);
      return m.copyWith(
        isOnline: isOnline,
        user: m.user.copyWith(
          availability: m.user.availability.copyWith(
            status: presence?.status ?? m.user.availability.status,
          ),
        ),
      );
    }).toList();
  }

  void applyPresenceUpdate() {
    if (state.members.isEmpty) return;
    emit(state.copyWith(members: _mergePresence(state.members)));
  }
}
