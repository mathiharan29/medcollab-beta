import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';

part 'handoff_form_state.dart';

class HandoffFormCubit extends Cubit<HandoffFormState> {
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

  Future<HandoffModel?> saveDraft() async {
    if (!_validate()) return null;
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
        );
      }
      emit(state.copyWith(isSaving: false, handoffId: result.id));
      return result;
    } on AppException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message));
      return null;
    }
  }

  Future<HandoffModel?> submit() async {
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
