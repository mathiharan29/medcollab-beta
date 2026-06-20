part of 'handoffs_cubit.dart';

class HandoffsState extends Equatable {
  const HandoffsState({
    this.handoffs = const [],
    this.isLoading = false,
    this.isBusy = false,
    this.filter = HandoffListFilter.active,
    this.searchQuery = '',
    this.error,
  });

  final List<HandoffModel> handoffs;
  final bool isLoading;
  final bool isBusy;
  final HandoffListFilter filter;
  final String searchQuery;
  final String? error;

  List<HandoffModel> get visibleHandoffs {
    final q = searchQuery.toLowerCase();
    return handoffs.where((h) {
      final matchesFilter = switch (filter) {
        HandoffListFilter.active => h.isActive,
        HandoffListFilter.archived => h.isArchived,
      };
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;

      if (h.toUser.displayName.toLowerCase().contains(q)) return true;
      if (h.fromUser.displayName.toLowerCase().contains(q)) return true;
      if (h.shiftSummary.toLowerCase().contains(q)) return true;
      if (h.shiftType.value.contains(q)) return true;

      for (final p in h.patients) {
        if (p.patientIdentifier.toLowerCase().contains(q)) return true;
        if (p.diagnosis.toLowerCase().contains(q)) return true;
        if (p.bedNumber.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  HandoffsState copyWith({
    List<HandoffModel>? handoffs,
    bool? isLoading,
    bool? isBusy,
    HandoffListFilter? filter,
    String? searchQuery,
    String? error,
  }) {
    return HandoffsState(
      handoffs: handoffs ?? this.handoffs,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [handoffs, isLoading, isBusy, filter, searchQuery, error];
}
