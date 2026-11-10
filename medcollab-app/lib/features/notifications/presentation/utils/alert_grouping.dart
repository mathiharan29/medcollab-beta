import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';

/// One row on the Alerts page. Ordinary chat traffic is collapsed to one
/// row per chat (WhatsApp-style: "Dr Bala · 4 new messages"), so a burst
/// of messages from the same person no longer floods the list.
/// Mentions, handoffs, invites and emergencies stay individual: each one
/// needs its own attention.
class AlertGroup {
  AlertGroup({required this.key, required this.items});

  final String key;

  /// Newest first; never empty.
  final List<AppNotificationModel> items;

  AppNotificationModel get latest => items.first;
  int get count => items.length;
  int get unreadCount => items.where((n) => !n.read).length;
  bool get isGrouped => items.length > 1;
  String? get channelId => latest.metadata.channelId;
}

bool _isEmergency(AppNotificationModel n) =>
    n.type.toLowerCase().contains('emergency') ||
    n.title.toLowerCase().contains('emergency');

/// Key that collapses this alert with others, or null to keep it alone.
String? alertGroupKey(AppNotificationModel n) {
  final channelId = n.metadata.channelId;
  if (channelId == null || _isEmergency(n)) return null;
  return switch (n.category) {
    // Messages and thread replies collapse per chat (alerts carry the
    // reply's own id, not the thread root, so per-thread keys can't work).
    AppNotificationCategory.message ||
    AppNotificationCategory.reply =>
      'chat:$channelId',
    _ => null,
  };
}

/// Groups [items] (newest first) and keeps that order by each group's
/// newest alert.
List<AlertGroup> groupAlerts(List<AppNotificationModel> items) {
  final groups = <String, AlertGroup>{};
  final order = <AlertGroup>[];
  for (final n in items) {
    final key = alertGroupKey(n) ?? 'single:${n.id}';
    final existing = groups[key];
    if (existing != null) {
      existing.items.add(n);
    } else {
      final g = AlertGroup(key: key, items: [n]);
      groups[key] = g;
      order.add(g);
    }
  }
  return order;
}
