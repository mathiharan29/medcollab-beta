import 'package:equatable/equatable.dart';

/// `User.notifications` preferences from the backend.
class NotificationPreferencesModel extends Equatable {
  const NotificationPreferencesModel({
    this.emergencyAlerts = true,
    this.mentions = true,
    this.newMessages = true,
    this.handoffs = true,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      emergencyAlerts: json['emergencyAlerts'] as bool? ?? true,
      mentions: json['mentions'] as bool? ?? true,
      newMessages: json['newMessages'] as bool? ?? true,
      handoffs: json['handoffs'] as bool? ?? true,
      quietHoursStart: json['quietHoursStart'] as String?,
      quietHoursEnd: json['quietHoursEnd'] as String?,
    );
  }

  final bool emergencyAlerts;
  final bool mentions;
  final bool newMessages;
  final bool handoffs;
  final String? quietHoursStart;
  final String? quietHoursEnd;

  Map<String, dynamic> toJson() => {
        'emergencyAlerts': emergencyAlerts,
        'mentions': mentions,
        'newMessages': newMessages,
        'handoffs': handoffs,
        if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
        if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
      };

  @override
  List<Object?> get props => [
        emergencyAlerts,
        mentions,
        newMessages,
        handoffs,
        quietHoursStart,
        quietHoursEnd,
      ];
}
