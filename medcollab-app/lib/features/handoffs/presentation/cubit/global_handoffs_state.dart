part of 'global_handoffs_cubit.dart';

class GlobalHandoffsState extends Equatable {
  const GlobalHandoffsState({
    this.isLoading = true,
    this.error,
    this.handoffs = const [],
    this.filter = GlobalHandoffFilter.pending,
    this.searchQuery = '',
    this.currentUserId = '',
  });

  final bool isLoading;
  final String? error;
  final List<HandoffModel> handoffs;
  final GlobalHandoffFilter filter;
  final String searchQuery;
  final String currentUserId;

  List<HandoffModel> get visibleHandoffs => handoffsForFilter(filter);

  /// True when the user is the sender or current assignee. Handoffs the user
  /// only reassigned away stay visible solely under the Reassigned tab.
  bool _isCurrentParticipant(HandoffModel h) =>
      currentUserId.isEmpty ||
      h.fromUser.id == currentUserId ||
      h.toUser.id == currentUserId;

  /// Filtered (+ search) list for a specific tab — used by swipe PageView.
  List<HandoffModel> handoffsForFilter(GlobalHandoffFilter tab) {
    var list = switch (tab) {
      // Pending ack, shift day still current.
      GlobalHandoffFilter.pending => handoffs
          .where(
            (h) =>
                _isCurrentParticipant(h) &&
                h.status == HandoffStatus.submitted &&
                !_isShiftPast(h),
          )
          .toList(),
      // Acknowledged and still on/after the shift day.
      GlobalHandoffFilter.active => handoffs
          .where(
            (h) =>
                _isCurrentParticipant(h) &&
                h.status == HandoffStatus.acknowledged &&
                !_isShiftPast(h),
          )
          .toList(),
      // Past shift date: completed (acked) or not attended (still pending).
      GlobalHandoffFilter.completed => handoffs
          .where(
            (h) =>
                _isCurrentParticipant(h) &&
                _isShiftPast(h) &&
                (h.status == HandoffStatus.acknowledged ||
                    h.status == HandoffStatus.submitted),
          )
          .toList(),
      GlobalHandoffFilter.drafts =>
        handoffs.where((h) => h.status == HandoffStatus.draft).toList(),
      // Handoffs this user reassigned to another doctor.
      GlobalHandoffFilter.reassigned => handoffs
          .where((h) => h.wasReassignedBy(currentUserId))
          .toList(),
    };
    if (searchQuery.isEmpty) return list;
    final q = searchQuery.toLowerCase();
    return list.where((h) => _matchesSearch(h, q)).toList();
  }

  static bool _matchesSearch(HandoffModel h, String q) {
    if (h.fromUser.displayName.toLowerCase().contains(q)) return true;
    if (h.toUser.displayName.toLowerCase().contains(q)) return true;
    if (h.shiftSummary.toLowerCase().contains(q)) return true;
    if (h.shiftType.value.contains(q)) return true;
    for (final p in h.patients) {
      if (p.patientIdentifier.toLowerCase().contains(q)) return true;
      if (p.clinicalAlias.toLowerCase().contains(q)) return true;
      if (p.diagnosis.toLowerCase().contains(q)) return true;
      if (p.bedNumber.toLowerCase().contains(q)) return true;
      if (p.ward.toLowerCase().contains(q)) return true;
      if (p.notes.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  /// Shift day is past when local calendar day is after the handoff shiftDate.
  static bool _isShiftPast(HandoffModel h) {
    final shift = h.shiftDate;
    if (shift == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shiftDay = DateTime(shift.year, shift.month, shift.day);
    return shiftDay.isBefore(today);
  }

  GlobalHandoffsState copyWith({
    bool? isLoading,
    String? error,
    List<HandoffModel>? handoffs,
    GlobalHandoffFilter? filter,
    String? searchQuery,
    String? currentUserId,
  }) {
    return GlobalHandoffsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      handoffs: handoffs ?? this.handoffs,
      filter: filter ?? this.filter,
      searchQuery: searchQuery ?? this.searchQuery,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, error, handoffs, filter, searchQuery, currentUserId];
}
