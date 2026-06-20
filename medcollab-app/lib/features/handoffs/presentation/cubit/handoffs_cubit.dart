import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';

part 'handoffs_state.dart';

enum HandoffListFilter { active, archived }

class HandoffsCubit extends Cubit<HandoffsState> {
  HandoffsCubit({
    required HandoffRepository handoffRepository,
    required SocketClient socketClient,
    required this.spaceId,
    required this.currentUserId,
  })  : _repository = handoffRepository,
        _socketClient = socketClient,
        super(const HandoffsState()) {
    _listenForHandoffMessages();
    loadHandoffs();
  }

  final HandoffRepository _repository;
  final SocketClient _socketClient;
  final String spaceId;
  final String currentUserId;

  StreamSubscription<Map<String, dynamic>>? _messageSub;

  Future<void> loadHandoffs() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final handoffs = await _repository.getHandoffsForSpace(spaceId);
      emit(state.copyWith(handoffs: handoffs, isLoading: false));
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  void setFilter(HandoffListFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query.trim()));
  }

  Future<void> archiveHandoff(HandoffModel handoff) async {
    if (handoff.isDraft) {
      emit(state.copyWith(isBusy: true, error: null));
      try {
        await _repository.deleteHandoff(handoff.id);
        final updated =
            state.handoffs.where((h) => h.id != handoff.id).toList();
        emit(state.copyWith(handoffs: updated, isBusy: false));
      } on AppException catch (e) {
        emit(state.copyWith(isBusy: false, error: e.message));
      }
      return;
    }

    if (handoff.status == HandoffStatus.submitted &&
        handoff.toUser.id == currentUserId) {
      emit(state.copyWith(isBusy: true, error: null));
      try {
        final updated = await _repository.acknowledgeHandoff(handoff.id);
        _upsertHandoff(updated);
        emit(state.copyWith(isBusy: false));
      } on AppException catch (e) {
        emit(state.copyWith(isBusy: false, error: e.message));
      }
    }
  }

  void _upsertHandoff(HandoffModel handoff) {
    if (handoff.spaceId != spaceId) return;
    final list = List<HandoffModel>.from(state.handoffs);
    final index = list.indexWhere((h) => h.id == handoff.id);
    if (index >= 0) {
      list[index] = handoff;
    } else {
      list.insert(0, handoff);
    }
    list.sort((a, b) {
      final at = a.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    emit(state.copyWith(handoffs: list));
  }

  void _listenForHandoffMessages() {
    _messageSub =
        _socketClient.onMapEvent(SocketEvents.newMessage).listen((data) {
      try {
        final type = data['type'] as String?;
        if (type != MessageType.handoff.value) return;
        final msgSpaceId = data['spaceId']?.toString();
        if (msgSpaceId != null && msgSpaceId != spaceId) return;
        loadHandoffs();
      } catch (_) {
        // Ignore malformed payloads.
      }
    });
  }

  @override
  Future<void> close() {
    _messageSub?.cancel();
    return super.close();
  }
}
