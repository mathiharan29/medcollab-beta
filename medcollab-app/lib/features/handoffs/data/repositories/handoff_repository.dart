import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_patient_model.dart';
import 'package:medcollab_app/shared/data/repositories/base_repository.dart';

class HandoffsPage {
  const HandoffsPage({required this.handoffs, required this.hasMore});

  final List<HandoffModel> handoffs;
  final bool hasMore;
}

class HandoffRepository extends BaseRepository {
  HandoffRepository({required super.apiClient});

  /// `GET /api/spaces/:spaceId/handoffs`
  Future<HandoffsPage> getSpaceHandoffs(
    String spaceId, {
    HandoffStatus? status,
    String? before,
    int limit = 30,
  }) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.spaceHandoffs(spaceId),
        queryParameters: {
          'limit': limit,
          if (status != null) 'status': status.value,
          if (before != null) 'before': before,
        },
        parser: (json) => HandoffsPage(
          handoffs: parseNestedList(json, 'handoffs', HandoffModel.fromJson),
          hasMore: json['hasMore'] as bool? ?? false,
        ),
      ),
    );
  }

  /// `GET /api/handoffs` — includes sender drafts.
  Future<List<HandoffModel>> getMyHandoffs({
    String? spaceId,
    String type = 'all',
    HandoffStatus? status,
  }) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.handoffs,
        queryParameters: {
          'type': type,
          if (spaceId != null) 'spaceId': spaceId,
          if (status != null) 'status': status.value,
        },
        parser: (json) =>
            parseNestedList(json, 'handoffs', HandoffModel.fromJson),
      ),
    );
  }

  /// Merges space history with the current user's sent handoffs (drafts + submitted).
  Future<List<HandoffModel>> getHandoffsForSpace(String spaceId) async {
    final spacePage = await getSpaceHandoffs(spaceId, limit: 50);
    final mySent = await getMyHandoffs(spaceId: spaceId, type: 'sent');

    final merged = <String, HandoffModel>{};
    for (final h in spacePage.handoffs) {
      merged[h.id] = h;
    }
    for (final h in mySent) {
      merged[h.id] = h;
    }

    final list = merged.values.toList()
      ..sort((a, b) {
        final at = a.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return list;
  }

  /// `GET /api/handoffs/:id`
  Future<HandoffModel> getHandoffById(String handoffId) {
    return execute(
      () => apiClient.get(
        ApiEndpoints.handoffById(handoffId),
        parser: (json) =>
            parseNested(json, 'handoff', HandoffModel.fromJson),
      ),
    );
  }

  /// `POST /api/handoffs`
  Future<HandoffModel> createHandoff({
    required String spaceId,
    required String channelId,
    required String toUserId,
    required DateTime shiftDate,
    required ShiftType shiftType,
    List<HandoffPatientModel> patients = const [],
    String shiftSummary = '',
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.handoffs,
        data: {
          'spaceId': spaceId,
          'channelId': channelId,
          'toUserId': toUserId,
          'shiftDate': shiftDate.toIso8601String(),
          'shiftType': shiftType.value,
          'patients': patients.map((p) => p.toJson()).toList(),
          'shiftSummary': shiftSummary,
        },
        parser: (json) =>
            parseNested(json, 'handoff', HandoffModel.fromJson),
      ),
    );
  }

  /// `PUT /api/handoffs/:id`
  Future<HandoffModel> updateHandoff({
    required String handoffId,
    DateTime? shiftDate,
    ShiftType? shiftType,
    List<HandoffPatientModel>? patients,
    String? shiftSummary,
  }) {
    return execute(
      () => apiClient.put(
        ApiEndpoints.handoffById(handoffId),
        data: {
          if (shiftDate != null) 'shiftDate': shiftDate.toIso8601String(),
          if (shiftType != null) 'shiftType': shiftType.value,
          if (patients != null)
            'patients': patients.map((p) => p.toJson()).toList(),
          if (shiftSummary != null) 'shiftSummary': shiftSummary,
        },
        parser: (json) =>
            parseNested(json, 'handoff', HandoffModel.fromJson),
      ),
    );
  }

  /// `POST /api/handoffs/:id/submit`
  Future<HandoffModel> submitHandoff(String handoffId) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.submitHandoff(handoffId),
        parser: (json) =>
            parseNested(json, 'handoff', HandoffModel.fromJson),
      ),
    );
  }

  /// `POST /api/handoffs/:id/acknowledge`
  Future<HandoffModel> acknowledgeHandoff(
    String handoffId, {
    String note = '',
  }) {
    return execute(
      () => apiClient.post(
        ApiEndpoints.acknowledgeHandoff(handoffId),
        data: note.isNotEmpty ? {'note': note} : null,
        parser: (json) =>
            parseNested(json, 'handoff', HandoffModel.fromJson),
      ),
    );
  }

  /// `DELETE /api/handoffs/:id` — draft only.
  Future<void> deleteHandoff(String handoffId) {
    return execute(() => apiClient.delete(ApiEndpoints.handoffById(handoffId)));
  }
}
