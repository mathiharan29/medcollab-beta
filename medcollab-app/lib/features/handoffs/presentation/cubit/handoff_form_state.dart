part of 'handoff_form_cubit.dart';

class HandoffFormState extends Equatable {
  const HandoffFormState({
    this.handoffId,
    required this.channelId,
    this.assignedDoctor,
    this.shiftDate,
    this.shiftType = ShiftType.morning,
    this.patients = const [],
    this.shiftSummary = '',
    this.isSaving = false,
    this.error,
  });

  factory HandoffFormState.initial({required String channelId}) {
    return HandoffFormState(
      channelId: channelId,
      shiftDate: DateTime.now(),
    );
  }

  factory HandoffFormState.fromHandoff(HandoffModel handoff) {
    return HandoffFormState(
      handoffId: handoff.id,
      channelId: handoff.channelId,
      assignedDoctor: handoff.toUser,
      shiftDate: handoff.shiftDate,
      shiftType: handoff.shiftType,
      patients: handoff.patients,
      shiftSummary: handoff.shiftSummary,
    );
  }

  final String? handoffId;
  final String channelId;
  final UserModel? assignedDoctor;
  final DateTime? shiftDate;
  final ShiftType shiftType;
  final List<HandoffPatientModel> patients;
  final String shiftSummary;
  final bool isSaving;
  final String? error;

  bool get isEditing => handoffId != null;

  HandoffFormState copyWith({
    String? handoffId,
    String? channelId,
    UserModel? assignedDoctor,
    DateTime? shiftDate,
    ShiftType? shiftType,
    List<HandoffPatientModel>? patients,
    String? shiftSummary,
    bool? isSaving,
    String? error,
  }) {
    return HandoffFormState(
      handoffId: handoffId ?? this.handoffId,
      channelId: channelId ?? this.channelId,
      assignedDoctor: assignedDoctor ?? this.assignedDoctor,
      shiftDate: shiftDate ?? this.shiftDate,
      shiftType: shiftType ?? this.shiftType,
      patients: patients ?? this.patients,
      shiftSummary: shiftSummary ?? this.shiftSummary,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        handoffId,
        channelId,
        assignedDoctor,
        shiftDate,
        shiftType,
        patients,
        shiftSummary,
        isSaving,
        error,
      ];
}
