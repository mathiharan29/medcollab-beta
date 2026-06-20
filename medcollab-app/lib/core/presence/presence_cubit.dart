import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/constants/socket_events.dart';
import 'package:medcollab_app/core/socket/socket_client.dart';
import 'package:medcollab_app/core/utils/json_map_utils.dart';

class PresenceInfo extends Equatable {
  const PresenceInfo({
    this.isOnline = false,
    this.status,
    this.updatedAt,
  });

  final bool isOnline;
  /// Set only when an explicit availability payload is received.
  final AvailabilityStatus? status;
  final DateTime? updatedAt;

  PresenceInfo copyWith({
    bool? isOnline,
    AvailabilityStatus? status,
    DateTime? updatedAt,
  }) {
    return PresenceInfo(
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [isOnline, status, updatedAt];
}

/// Tracks online status and availability from socket `presence_update` events.
class PresenceCubit extends Cubit<Map<String, PresenceInfo>> {
  PresenceCubit({required SocketClient socketClient})
      : _socketClient = socketClient,
        super(const {}) {
    _sub = _socketClient
        .onMapEvent(SocketEvents.presenceUpdate)
        .listen(_onPresenceUpdate);
  }

  final SocketClient _socketClient;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// Seed presence from API on first load — never overwrites live online state.
  void mergeApiSnapshot(Map<String, PresenceInfo> snapshot) {
    if (snapshot.isEmpty) return;
    final updated = Map<String, PresenceInfo>.from(state);
    for (final entry in snapshot.entries) {
      final existing = updated[entry.key];
      updated[entry.key] = PresenceInfo(
        isOnline: existing?.isOnline ?? entry.value.isOnline,
        status: entry.value.status ?? existing?.status,
        updatedAt: _latest(
          entry.value.updatedAt,
          existing?.updatedAt,
        ),
      );
    }
    emit(updated);
  }

  /// Full resync from API after reconnect — refreshes online flags from server.
  void refreshFromApi(Map<String, PresenceInfo> snapshot) {
    if (snapshot.isEmpty) return;
    final updated = Map<String, PresenceInfo>.from(state);
    final now = DateTime.now();
    for (final entry in snapshot.entries) {
      final existing = updated[entry.key];
      updated[entry.key] = PresenceInfo(
        isOnline: entry.value.isOnline,
        status: entry.value.status ?? existing?.status,
        updatedAt: now,
      );
    }
    emit(updated);
  }

  void applyLocal({
    required String userId,
    required AvailabilityStatus status,
    bool isOnline = true,
  }) {
    final updated = Map<String, PresenceInfo>.from(state);
    final existing = updated[userId];
    updated[userId] = (existing ?? const PresenceInfo()).copyWith(
      isOnline: isOnline,
      status: status,
      updatedAt: DateTime.now(),
    );
    emit(updated);
  }

  void _onPresenceUpdate(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    if (userId == null || userId.isEmpty) return;

    final status = _parseAvailabilityStatus(data);

    final updated = Map<String, PresenceInfo>.from(state);
    final existing = updated[userId];

    final incomingAt =
        DateTime.tryParse(data['updatedAt']?.toString() ?? '') ??
            DateTime.now();
    if (existing != null &&
        existing.updatedAt != null &&
        incomingAt.isBefore(existing.updatedAt!)) {
      return;
    }

    final isOnline = data.containsKey('isOnline')
        ? data['isOnline'] as bool? ?? false
        : (existing?.isOnline ?? false);

    updated[userId] = PresenceInfo(
      isOnline: isOnline,
      status: status ?? existing?.status,
      updatedAt: incomingAt,
    );

    if (updated.length > 300) {
      final keys = updated.keys.toList();
      for (var i = 0; i < keys.length - 300; i++) {
        updated.remove(keys[i]);
      }
    }
    emit(updated);
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  AvailabilityStatus? _parseAvailabilityStatus(Map<String, dynamic> data) {
    final availabilityRaw = asJsonMap(data['availability']);
    if (availabilityRaw != null) {
      return AvailabilityStatus.fromString(
        availabilityRaw['status']?.toString(),
      );
    }
    if (data['status'] != null) {
      return AvailabilityStatus.fromString(data['status']?.toString());
    }
    return null;
  }

  bool isUserOnline(String userId) => state[userId]?.isOnline ?? false;

  AvailabilityStatus statusFor(String userId) =>
      state[userId]?.status ?? AvailabilityStatus.offDuty;

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

extension AvailabilityStatusLabel on AvailabilityStatus {
  String get presenceLabel => switch (this) {
        AvailabilityStatus.available => 'Available',
        AvailabilityStatus.doNotDisturb => 'Busy',
        AvailabilityStatus.inOt => 'In OT',
        AvailabilityStatus.offDuty => 'Off Duty',
        AvailabilityStatus.onCall => 'On Call',
        AvailabilityStatus.inIcu => 'In ICU',
        AvailabilityStatus.onRounds => 'On Rounds',
      };

  static List<AvailabilityStatus> get quickPresenceOptions => [
        AvailabilityStatus.available,
        AvailabilityStatus.doNotDisturb,
        AvailabilityStatus.inOt,
        AvailabilityStatus.offDuty,
      ];
}
