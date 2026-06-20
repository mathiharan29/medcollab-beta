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
    this.status = AvailabilityStatus.available,
    this.updatedAt,
  });

  final bool isOnline;
  final AvailabilityStatus status;
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

  void _onPresenceUpdate(Map<String, dynamic> data) {
    final userId = data['userId']?.toString();
    if (userId == null) return;

    final availabilityRaw = asJsonMap(data['availability']);
    AvailabilityStatus status = AvailabilityStatus.available;
    if (availabilityRaw != null) {
      status = AvailabilityStatus.fromString(
        availabilityRaw['status']?.toString(),
      );
    }

    final updated = Map<String, PresenceInfo>.from(state);
    final existing = updated[userId];
    updated[userId] = PresenceInfo(
      isOnline: data['isOnline'] as bool? ?? existing?.isOnline ?? false,
      status: availabilityRaw != null
          ? status
          : (existing?.status ?? status),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );

    if (updated.length > 300) {
      final keys = updated.keys.toList();
      for (var i = 0; i < keys.length - 300; i++) {
        updated.remove(keys[i]);
      }
    }
    emit(updated);
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
