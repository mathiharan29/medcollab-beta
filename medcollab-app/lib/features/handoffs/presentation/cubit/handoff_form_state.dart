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
    this.status = HandoffStatus.draft,
    this.voiceNote,
    this.contentVersion = 0,
    this.uploadsInFlight = 0,
    this.conflict = false,
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
      status: handoff.status,
      voiceNote: handoff.voiceNote,
      contentVersion: handoff.contentVersion,
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

  /// Spoken summary of the whole shift (issue 5).
  final HandoffVoiceNote? voiceNote;

  /// Server version this form was loaded / last saved at (issue 5).
  final int contentVersion;

  /// Voice notes / attachments still uploading: Save & Send wait for them.
  final int uploadsInFlight;

  /// Last save was refused because the handoff changed elsewhere.
  final bool conflict;

  bool get isEditing => handoffId != null;
  bool get isUploading => uploadsInFlight > 0;

  /// Status of the handoff being edited (draft for a new one).
  final HandoffStatus status;

  /// Already sent to the receiver: saving updates it in place (REQ 10).
  bool get isSent => status != HandoffStatus.draft;

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
    HandoffStatus? status,
    HandoffVoiceNote? voiceNote,
    bool clearVoiceNote = false,
    int? contentVersion,
    int? uploadsInFlight,
    bool? conflict,
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
      status: status ?? this.status,
      voiceNote: clearVoiceNote ? null : (voiceNote ?? this.voiceNote),
      contentVersion: contentVersion ?? this.contentVersion,
      uploadsInFlight: uploadsInFlight ?? this.uploadsInFlight,
      conflict: conflict ?? false,
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
        status,
        voiceNote,
        contentVersion,
        uploadsInFlight,
        conflict,
      ];
}
