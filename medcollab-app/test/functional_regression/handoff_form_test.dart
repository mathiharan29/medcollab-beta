import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';
import 'package:medcollab_app/features/handoffs/presentation/cubit/handoff_form_cubit.dart';

import 'fakes/chat_fakes.dart';

const _sender = UserModel(id: 'doctor-a', name: 'Doctor A');
const _receiver = UserModel(id: 'doctor-b', name: 'Doctor B');
const _patient = HandoffPatientModel(
  id: 'patient-synthetic-1',
  bedNumber: 'B-04',
  clinicalAlias: 'Synthetic Patient',
  pendingTasks: ['Review results'],
);

class _FakeHandoffRepository extends HandoffRepository {
  _FakeHandoffRepository() : super(apiClient: isolatedApiClient());

  int createCalls = 0;
  int updateCalls = 0;
  int submitCalls = 0;
  final updatedIds = <String>[];
  final submittedIds = <String>[];
  List<HandoffPatientModel> savedPatients = const [];
  String savedSummary = '';

  HandoffModel _handoff({HandoffStatus status = HandoffStatus.draft}) =>
      HandoffModel(
        id: 'handoff-synthetic-1',
        spaceId: 'space-synthetic-1',
        channelId: 'channel-synthetic-1',
        fromUser: _sender,
        toUser: _receiver,
        shiftDate: DateTime.utc(2026, 10, 10),
        shiftType: ShiftType.morning,
        patients: savedPatients,
        shiftSummary: savedSummary,
        status: status,
      );

  @override
  Future<HandoffModel> createHandoff({
    required String spaceId,
    required String channelId,
    required String toUserId,
    required DateTime shiftDate,
    required ShiftType shiftType,
    List<HandoffPatientModel> patients = const [],
    String shiftSummary = '',
  }) async {
    createCalls++;
    expect(spaceId, 'space-synthetic-1');
    expect(channelId, 'channel-synthetic-1');
    expect(toUserId, _receiver.id);
    savedPatients = patients;
    savedSummary = shiftSummary;
    return _handoff();
  }

  @override
  Future<HandoffModel> updateHandoff({
    required String handoffId,
    DateTime? shiftDate,
    ShiftType? shiftType,
    List<HandoffPatientModel>? patients,
    String? shiftSummary,
  }) async {
    updateCalls++;
    updatedIds.add(handoffId);
    if (patients != null) savedPatients = patients;
    if (shiftSummary != null) savedSummary = shiftSummary;
    return _handoff();
  }

  @override
  Future<HandoffModel> submitHandoff(String handoffId) async {
    submitCalls++;
    submittedIds.add(handoffId);
    if (submitCalls == 1) throw const ServerException('Synthetic submit failure');
    return _handoff(status: HandoffStatus.submitted);
  }
}

void main() {
  test('FR-HOF-11: failed submit retains the draft and retries its ID', () async {
    final repository = _FakeHandoffRepository();
    final form = HandoffFormCubit(
      handoffRepository: repository,
      spaceId: 'space-synthetic-1',
      channelId: 'channel-synthetic-1',
      currentUserId: _sender.id,
    );
    addTearDown(form.close);
    form.setAssignedDoctor(_receiver);
    form.setShiftDate(DateTime.utc(2026, 10, 10));
    form.setShiftSummary('Synthetic shift summary');
    form.setPatients(const [_patient]);

    final first = await form.submit();
    expect(first, isNull);
    expect(form.state.handoffId, 'handoff-synthetic-1');
    expect(form.state.error, 'Synthetic submit failure');
    expect(form.state.isSaving, isFalse);
    expect(form.state.shiftSummary, 'Synthetic shift summary');
    expect(form.state.patients, const [_patient]);
    expect(repository.createCalls, 1);
    expect(repository.updateCalls, 0);
    expect(repository.submitCalls, 1);
    expect(repository.savedPatients, const [_patient]);

    final retried = await form.submit();
    expect(retried?.status, HandoffStatus.submitted);
    expect(retried?.id, 'handoff-synthetic-1');
    expect(form.state.error, isNull);
    expect(repository.createCalls, 1, reason: 'Retry must not create another draft');
    expect(repository.updateCalls, 1);
    expect(repository.updatedIds, ['handoff-synthetic-1']);
    expect(repository.submittedIds, ['handoff-synthetic-1', 'handoff-synthetic-1']);
    expect(repository.savedSummary, 'Synthetic shift summary');
    expect(repository.savedPatients, const [_patient]);
  });
}
