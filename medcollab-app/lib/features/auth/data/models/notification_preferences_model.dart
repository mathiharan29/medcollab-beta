import 'package:equatable/equatable.dart';

/// `User.notifications` preferences from the backend.
class NotificationPreferencesModel extends Equatable {
  const NotificationPreferencesModel({
    this.emergencyAlerts = true,
    this.mentions = true,
    this.newMessages = true,
    this.handoffs = true,
    this.readReceiptsEnabled = true,
    this.allowMessageRequestsFromAnyone = false,
    this.allowGroupAddsFromAnyone = false,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      emergencyAlerts: json['emergencyAlerts'] as bool? ?? true,
      mentions: json['mentions'] as bool? ?? true,
      newMessages: json['newMessages'] as bool? ?? true,
      handoffs: json['handoffs'] as bool? ?? true,
      readReceiptsEnabled: json['readReceiptsEnabled'] as bool? ?? true,
      allowMessageRequestsFromAnyone:
          json['allowMessageRequestsFromAnyone'] as bool? ?? false,
      allowGroupAddsFromAnyone:
          json['allowGroupAddsFromAnyone'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as String?,
      quietHoursEnd: json['quietHoursEnd'] as String?,
    );
  }

  final bool emergencyAlerts;
  final bool mentions;
  final bool newMessages;
  final bool handoffs;
  /// When false: hide Seen-by UI and do not write DM read receipts.
  final bool readReceiptsEnabled;
  /// Opt-in: doctors who find you by phone may send a message request.
  final bool allowMessageRequestsFromAnyone;

  /// REQ 5: may doctors you don't know add you to a group? People who share
  /// a group or a chat with you always can.
  final bool allowGroupAddsFromAnyone;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  Map<String, dynamic> toJson() => {
        'emergencyAlerts': emergencyAlerts,
        'mentions': mentions,
        'newMessages': newMessages,
        'handoffs': handoffs,
        'readReceiptsEnabled': readReceiptsEnabled,
        'allowMessageRequestsFromAnyone': allowMessageRequestsFromAnyone,
        'allowGroupAddsFromAnyone': allowGroupAddsFromAnyone,
        if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
        if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
      };

  NotificationPreferencesModel copyWith({
    bool? emergencyAlerts,
    bool? mentions,
    bool? newMessages,
    bool? handoffs,
    bool? readReceiptsEnabled,
    bool? allowMessageRequestsFromAnyone,
    bool? allowGroupAddsFromAnyone,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool clearQuietHoursStart = false,
    bool clearQuietHoursEnd = false,
  }) {
    return NotificationPreferencesModel(
      emergencyAlerts: emergencyAlerts ?? this.emergencyAlerts,
      mentions: mentions ?? this.mentions,
      newMessages: newMessages ?? this.newMessages,
      handoffs: handoffs ?? this.handoffs,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      allowMessageRequestsFromAnyone: allowMessageRequestsFromAnyone ??
          this.allowMessageRequestsFromAnyone,
      allowGroupAddsFromAnyone:
          allowGroupAddsFromAnyone ?? this.allowGroupAddsFromAnyone,
      quietHoursStart:
          clearQuietHoursStart ? null : (quietHoursStart ?? this.quietHoursStart),
      quietHoursEnd:
          clearQuietHoursEnd ? null : (quietHoursEnd ?? this.quietHoursEnd),
    );
  }

  @override
  List<Object?> get props => [
        emergencyAlerts,
        mentions,
        newMessages,
        handoffs,
        readReceiptsEnabled,
        allowMessageRequestsFromAnyone,
        allowGroupAddsFromAnyone,
        quietHoursStart,
        quietHoursEnd,
      ];
}
