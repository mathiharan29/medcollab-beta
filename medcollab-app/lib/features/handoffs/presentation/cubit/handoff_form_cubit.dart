import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/state/safe_emit.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_voice_note.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';

part 'handoff_form_state.dart';

class HandoffFormCubit extends Cubit<HandoffFormState> with SafeEmit<HandoffFormState> {
  HandoffFormCubit({
    required HandoffRepository handoffRepository,
    required this.spaceId,
    required this.channelId,
    required this.currentUserId,
    HandoffModel? existing,
  })  : _repository = handoffRepository,
        super(
          existing != null
              ? HandoffFormState.fromHandoff(existing)
              : HandoffFormState.initial(channelId: channelId),
        );

  final HandoffRepository _repository;
  final String spaceId;
  final String channelId;
  final String currentUserId;

  void setAssignedDoctor(UserModel doctor) {
    emit(state.copyWith(assignedDoctor: doctor));
  }

  void setShiftDate(DateTime date) {
    emit(state.copyWith(shiftDate: date));
  }

  void setShiftType(ShiftType type) {
    emit(state.copyWith(shiftType: type));
  }

  void setShiftSummary(String summary) {
    emit(state.copyWith(shiftSummary: summary));
  }

  void setPatients(List<HandoffPatientModel> patients) {
    emit(state.copyWith(patients: patients));
  }

  /// Shift voice handover recorded / re-recorded (issue 5).
  void setVoiceNote(HandoffVoiceNote note) {
    emit(state.copyWith(voiceNote: note));
  }

  void removeVoiceNote() {
    emit(state.copyWith(clearVoiceNote: true));
  }

  /// Bracket uploads so Save / Send wait for them (never send a handoff
  /// whose voice note is still on the phone).
  void uploadStarted() =>
      emit(state.copyWith(uploadsInFlight: state.uploadsInFlight + 1));
  void uploadFinished() => emit(state.copyWith(
      uploadsInFlight: (state.uploadsInFlight - 1).clamp(0, 1 << 20)));

  Future<HandoffModel?> saveDraft() async {
    if (!_validate()) return null;
    if (state.isUploading) {
      emit(state.copyWith(error: 'Wait for the voice note to finish uploading'));
      return null;
    }
    emit(state.copyWith(isSaving: true, error: null));
    try {
      final HandoffModel result;
      if (state.handoffId != null) {
        result = await _repository.updateHandoff(
          handoffId: state.handoffId!,
          shiftDate: state.shiftDate,
          shiftType: state.shiftType,
          patients: state.patients,
          shiftSummary: state.shiftSummary,
          voiceNote: state.voiceNote,
          setVoiceNote: true,
          baseContentVersion: state.contentVersion,
        );
      } else {
        result = await _repository.createHandoff(
          spaceId: spaceId,
          channelId: channelId,
          toUserId: state.assignedDoctor!.id,
          shiftDate: state.shiftDate!,
          shiftType: state.shiftType,
          patients: state.patients,
          shiftSummary: state.shiftSummary,
          voiceNote: state.voiceNote,
        );
      }
      emit(state.copyWith(
        isSaving: false,
        handoffId: result.id,
        // Next save is based on what the server now holds.
        contentVersion: result.contentVersion,
        // Server-side patient ids (new patients) for the next edit.
        patients: result.patients.isNotEmpty ? result.patients : null,
      ));
      return result;
    } on ConflictException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message, conflict: true));
      return null;
    } on AppException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message));
      return null;
    }
  }

  /// After a conflict: load what the server has now (the doctor's unsaved
  /// changes on this screen are replaced — they were made on an old copy).
  Future<void> reloadLatest() async {
    final id = state.handoffId;
    if (id == null) return;
    emit(state.copyWith(isSaving: true));
    try {
      final latest = await _repository.getHandoffById(id);
      emit(HandoffFormState.fromHandoff(latest));
    } on AppException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message, conflict: true));
    }
  }

  /// REQ 10: save edits to a handoff that was already sent. The server keeps
  /// it sent, records the edit, and (if acknowledged) asks for re-ack.
  Future<HandoffModel?> saveChanges() async {
    if (state.patients.isEmpty) {
      emit(state.copyWith(error: 'A sent handoff needs at least one patient'));
      return null;
    }
    return saveDraft();
  }

  Future<HandoffModel?> submit() async {
    if (state.isSent) return saveChanges();
    final saved = await saveDraft();
    if (saved == null) return null;
    if (state.patients.isEmpty) {
      emit(state.copyWith(error: 'Add at least one patient before submitting'));
      return null;
    }

    emit(state.copyWith(isSaving: true, error: null));
    try {
      final result = await _repository.submitHandoff(saved.id);
      emit(state.copyWith(isSaving: false));
      return result;
    } on AppException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message));
      return null;
    }
  }

  bool _validate() {
    if (state.assignedDoctor == null) {
      emit(state.copyWith(error: 'Select the assigned doctor'));
      return false;
    }
    if (state.shiftDate == null) {
      emit(state.copyWith(error: 'Shift date is required'));
      return false;
    }
    return true;
  }
}
