part of 'members_cubit.dart';

class MembersState extends Equatable {
  const MembersState({
    this.members = const [],
    this.searchResults = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.isSearching = false,
    this.isUpdatingAvailability = false,
    this.error,
  });

  final List<SpaceMemberModel> members;
  final List<UserModel> searchResults;
  final String searchQuery;
  final bool isLoading;
  final bool isSearching;
  final bool isUpdatingAvailability;
  final String? error;

  List<SpaceMemberModel> get filteredMembers {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return members;
    return members
        .where(
          (m) =>
              m.user.displayName.toLowerCase().contains(q) ||
              (m.user.speciality?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  MembersState copyWith({
    List<SpaceMemberModel>? members,
    List<UserModel>? searchResults,
    String? searchQuery,
    bool? isLoading,
    bool? isSearching,
    bool? isUpdatingAvailability,
    String? error,
  }) {
    return MembersState(
      members: members ?? this.members,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      isUpdatingAvailability:
          isUpdatingAvailability ?? this.isUpdatingAvailability,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        members,
        searchResults,
        searchQuery,
        isLoading,
        isSearching,
        isUpdatingAvailability,
        error,
      ];
}
