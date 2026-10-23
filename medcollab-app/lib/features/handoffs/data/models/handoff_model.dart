import 'package:equatable/equatable.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_assignment_entry.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_write_back_note.dart';

/// Clinical shift handoff — maps to backend `Handoff` document.
class HandoffModel extends Equatable {
  const HandoffModel({
    required this.id,
    required this.spaceId,
    required this.channelId,
    required this.fromUser,
    required this.toUser,
    required this.shiftDate,
    required this.shiftType,
    this.patients = const [],
    this.shiftSummary = '',
    this.status = HandoffStatus.draft,
    this.submittedAt,
    this.acknowledgedAt,
    this.acknowledgementNote = '',
    this.writeBackNotes = const [],
    this.assignmentHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory HandoffModel.fromJson(Map<String, dynamic> json) {
    final id = json['_id'] ?? json['id'];

    UserModel parseUser(dynamic raw) {
      if (raw is Map<String, dynamic>) return UserModel.fromJson(raw);
      return UserModel(id: raw?.toString() ?? '');
    }

    return HandoffModel(
      id: id.toString(),
      spaceId: json['spaceId']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      fromUser: parseUser(json['fromUserId']),
      toUser: parseUser(json['toUserId']),
      shiftDate: json['shiftDate'] != null
          ? DateTime.tryParse(json['shiftDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      shiftType: ShiftType.fromString(json['shiftType'] as String?),
      patients: json['patients'] is List
          ? (json['patients'] as List)
              .map(asJsonMap)
              .whereType<Map<String, dynamic>>()
              .map(HandoffPatientModel.fromJson)
              .toList()
          : const [],
      shiftSummary: json['shiftSummary'] as String? ?? '',
      status: HandoffStatus.fromString(json['status'] as String?),
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString())
          : null,
      acknowledgedAt: json['acknowledgedAt'] != null
          ? DateTime.tryParse(json['acknowledgedAt'].toString())
          : null,
      acknowledgementNote: json['acknowledgementNote'] as String? ?? '',
      writeBackNotes: parseWriteBackNotes(json['writeBackNotes']),
      assignmentHistory: parseAssignmentHistory(json['assignmentHistory']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  final String id;
  final String spaceId;
  final String channelId;
  final UserModel fromUser;
  final UserModel toUser;
  final DateTime? shiftDate;
  final ShiftType shiftType;
  final List<HandoffPatientModel> patients;
  final String shiftSummary;
  final HandoffStatus status;
  final DateTime? submittedAt;
  final DateTime? acknowledgedAt;
  final String acknowledgementNote;
  final List<HandoffWriteBackNote> writeBackNotes;
  final List<HandoffAssignmentEntry> assignmentHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True when [userId] reassigned this handoff (assignment history or a
  /// `reassign` write-back note authored by them).
  bool wasReassignedBy(String userId) {
    if (userId.isEmpty) return false;
    if (assignmentHistory.any((e) => e.byUserId == userId)) return true;
    return writeBackNotes
        .any((n) => n.kind == 'reassign' && n.author.id == userId);
  }

  bool get isDraft => status == HandoffStatus.draft;
  bool get isArchived => status == HandoffStatus.acknowledged;
  bool get isActive =>
      status == HandoffStatus.draft || status == HandoffStatus.submitted;

  /// True when the handoff's calendar shift day is before today (local).
  bool get isShiftPast {
    if (shiftDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shiftDay =
        DateTime(shiftDate!.year, shiftDate!.month, shiftDate!.day);
    return shiftDay.isBefore(today);
  }

  /// Clinical lifecycle label combining status + whether the shift day passed.
  String get lifecycleLabel {
    if (status == HandoffStatus.draft) return 'Draft';
    if (status == HandoffStatus.submitted) {
      return isShiftPast ? 'Not attended' : 'Pending';
    }
    if (status == HandoffStatus.acknowledged) {
      return isShiftPast ? 'Completed' : 'Active';
    }
    return status.value;
  }

  DateTime? get lastUpdated => updatedAt ?? submittedAt ?? createdAt;

  HandoffPatientModel? get primaryPatient =>
      patients.isNotEmpty ? patients.first : null;

  bool get hasFlaggedPatient => patients.any((p) => p.isFlagged);

  HandoffModel copyWith({
    String? id,
    String? spaceId,
    String? channelId,
    UserModel? fromUser,
    UserModel? toUser,
    DateTime? shiftDate,
    ShiftType? shiftType,
    List<HandoffPatientModel>? patients,
    String? shiftSummary,
    HandoffStatus? status,
    DateTime? submittedAt,
    DateTime? acknowledgedAt,
    String? acknowledgementNote,
    List<HandoffWriteBackNote>? writeBackNotes,
    List<HandoffAssignmentEntry>? assignmentHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HandoffModel(
      id: id ?? this.id,
      spaceId: spaceId ?? this.spaceId,
      channelId: channelId ?? this.channelId,
      fromUser: fromUser ?? this.fromUser,
      toUser: toUser ?? this.toUser,
      shiftDate: shiftDate ?? this.shiftDate,
      shiftType: shiftType ?? this.shiftType,
      patients: patients ?? this.patients,
      shiftSummary: shiftSummary ?? this.shiftSummary,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgementNote: acknowledgementNote ?? this.acknowledgementNote,
      writeBackNotes: writeBackNotes ?? this.writeBackNotes,
      assignmentHistory: assignmentHistory ?? this.assignmentHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        spaceId,
        channelId,
        fromUser,
        toUser,
        shiftDate,
        shiftType,
        patients,
        shiftSummary,
        status,
        submittedAt,
        acknowledgedAt,
        acknowledgementNote,
        writeBackNotes,
        assignmentHistory,
        createdAt,
        updatedAt,
      ];
}
