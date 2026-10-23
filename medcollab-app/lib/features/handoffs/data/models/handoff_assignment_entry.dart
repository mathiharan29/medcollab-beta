import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';

/// One entry in a handoff's `assignmentHistory` audit trail.
class HandoffAssignmentEntry extends Equatable {
  const HandoffAssignmentEntry({
    this.fromUserId = '',
    this.toUserId = '',
    this.byUserId = '',
    this.note = '',
    this.at,
  });

  factory HandoffAssignmentEntry.fromJson(Map<String, dynamic> json) {
    String idOf(dynamic raw) {
      if (raw is Map) return (raw['_id'] ?? raw['id'])?.toString() ?? '';
      return raw?.toString() ?? '';
    }

    return HandoffAssignmentEntry(
      fromUserId: idOf(json['fromUserId']),
      toUserId: idOf(json['toUserId']),
      byUserId: idOf(json['byUserId']),
      note: json['note'] as String? ?? '',
      at: json['at'] != null ? DateTime.tryParse(json['at'].toString()) : null,
    );
  }

  final String fromUserId;
  final String toUserId;
  final String byUserId;
  final String note;
  final DateTime? at;

  @override
  List<Object?> get props => [fromUserId, toUserId, byUserId, note, at];
}

List<HandoffAssignmentEntry> parseAssignmentHistory(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map(asJsonMap)
      .whereType<Map<String, dynamic>>()
      .map(HandoffAssignmentEntry.fromJson)
      .toList();
}
