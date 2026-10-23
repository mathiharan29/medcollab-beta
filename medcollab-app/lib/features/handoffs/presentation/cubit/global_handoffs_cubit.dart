import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/features/handoffs/data/models/handoff_model.dart';
import 'package:medcollab_app/features/handoffs/data/repositories/handoff_repository.dart';

part 'global_handoffs_state.dart';

enum GlobalHandoffFilter { pending, active, completed, drafts, reassigned }

class GlobalHandoffsCubit extends Cubit<GlobalHandoffsState> {
  GlobalHandoffsCubit({
    required HandoffRepository handoffRepository,
    required SocketClient socketClient,
    required this.currentUserId,
  })  : _repository = handoffRepository,
        _socketClient = socketClient,
        super(GlobalHandoffsState(currentUserId: currentUserId)) {
    _listenForHandoffEvents();
    _connectionSub = _socketClient.connectionStream.listen((connected) {
      if (connected) _scheduleReload();
    });
    load();
  }

  final HandoffRepository _repository;
  final SocketClient _socketClient;
  final String currentUserId;

  StreamSubscription<Map<String, dynamic>>? _submittedSub;
  StreamSubscription<Map<String, dynamic>>? _ackSub;
  StreamSubscription<Map<String, dynamic>>? _reassignedSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _reloadDebounce;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final handoffs = await _repository.getMyHandoffs();
      handoffs.sort((a, b) {
        final at = a.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      emit(state.copyWith(handoffs: handoffs, isLoading: false));
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    }
  }

  void setFilter(GlobalHandoffFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  void search(String query) {
    emit(state.copyWith(searchQuery: query.trim()));
  }

  void _listenForHandoffEvents() {
    _submittedSub = _socketClient
        .onMapEvent(SocketEvents.handoffSubmitted)
        .listen((_) => _scheduleReload());
    _ackSub = _socketClient
        .onMapEvent(SocketEvents.handoffAcknowledged)
        .listen((_) => _scheduleReload());
    _reassignedSub = _socketClient
        .onMapEvent(SocketEvents.handoffReassigned)
        .listen((_) => _scheduleReload());
  }

  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), load);
  }

  @override
  Future<void> close() {
    _reloadDebounce?.cancel();
    _submittedSub?.cancel();
    _ackSub?.cancel();
    _reassignedSub?.cancel();
    _connectionSub?.cancel();
    return super.close();
  }
}
