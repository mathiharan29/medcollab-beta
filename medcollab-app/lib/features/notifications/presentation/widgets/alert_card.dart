import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/features/notifications/data/models/notification_model.dart';

/// Vocle alert / notification row (brief § SCREEN 7).
class AlertCard extends StatelessWidget {
  const AlertCard({
    required this.notification,
    required this.onTap,
    this.onLongPress,
    this.groupCount = 1,
    this.groupUnread = 0,
    this.unreadOverride,
    super.key,
  });

  /// Latest alert of the row (a grouped row shows its newest message).
  final AppNotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Alerts collapsed into this row (1 = a single alert).
  final int groupCount;
  final int groupUnread;

  /// Grouped rows are unread while any alert in them is.
  final bool? unreadOverride;

  // Theme-aware (REQ 6): these were fixed light colours, so in dark mode an
  // unread alert became a pale card with near-invisible white text.
  static bool get _dark => AppColors.isDark;
  static Color get _mentionBg =>
      _dark ? const Color(0xFF26295A) : const Color(0xFFEEF2FF);
  static Color get _mentionFg =>
      _dark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1);
  static Color get _emergencyTitle =>
      _dark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
  static Color get _emergencyTitleRead =>
      _dark ? const Color(0xFFE59A9A) : const Color(0xFFB45353);
  static Color get _emergencyCardBg =>
      _dark ? AppColors.emergencyTint : const Color(0xFFFFF5F5);
  static Color get _emergencyCardBgRead =>
      _dark ? AppColors.surfaceCard : const Color(0xFFFFFBFB);
  static Color get _unreadTint =>
      _dark ? AppColors.tealTint : const Color(0xFFF0FDFA);

  bool get _isEmergency {
    final cat = notification.categoryLabel.toLowerCase();
    final title = notification.title.toLowerCase();
    final type = notification.type.toLowerCase();
    return cat.contains('emergency') ||
        title.contains('emergency') ||
        type.contains('emergency');
  }

  bool get _isUnread => unreadOverride ?? !notification.read;

  @override
  Widget build(BuildContext context) {
    final time = notification.createdAt != null
        ? DateFormat('MMM d · h:mm a').format(notification.createdAt!.toLocal())
        : '';
    final icon = _iconStyle();
    final title = notification.title.isNotEmpty
        ? notification.title
        : (notification.actorName ?? 'Alert');

    // Unread emergency = strong red; after view, fade to soft tint + neutral border.
    final emergencyUnread = _isEmergency && _isUnread;
    final emergencyRead = _isEmergency && !_isUnread;

    return Material(
      color: emergencyUnread
          ? _emergencyCardBg
          : emergencyRead
              ? _emergencyCardBgRead
              : (_isUnread ? _unreadTint : AppColors.surfaceCard),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(
          color: emergencyUnread
              ? AppColors.emergencyBorder
              : emergencyRead
                  ? AppColors.borderDefault
                  : (_isUnread
                      ? AppColors.tealPrimary.withValues(alpha: 0.35)
                      : AppColors.borderDefault),
          width: _isUnread && !_isEmergency ? 1 : 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isUnread)
                Container(
                  width: 4,
                  color: _isEmergency
                      ? AppColors.emergencyRed
                      : AppColors.tealPrimary,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppGaps.cardH,
                    vertical: AppGaps.cardV,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: icon.bg,
                          borderRadius: AppRadius.groupIcon,
                        ),
                        child: Icon(icon.icon, color: icon.fg, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontWeight: _isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: emergencyUnread
                                    ? _emergencyTitle
                                    : emergencyRead
                                        ? _emergencyTitleRead
                                        : AppColors.textPrimary,
                              ),
                            ),
                            if (notification.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                notification.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: _isUnread
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: _isUnread
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (time.isNotEmpty || groupCount > 1) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (groupCount > 1)
                                    groupUnread > 1
                                        ? '$groupUnread new messages'
                                        : '$groupCount messages',
                                  if (time.isNotEmpty) time,
                                ].join(' · '),
                                style: AppTextStyles.timestamp,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isUnread && groupUnread > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: const Key('alert-group-count'),
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.tealPrimary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            groupUnread > 99 ? '99+' : '$groupUnread',
                            style: AppTextStyles.badge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ] else if (_isUnread) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isEmergency
                                  ? AppColors.emergencyRed
                                  : AppColors.tealPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({Color bg, IconData icon, Color fg}) _iconStyle() {
    if (_isEmergency) {
      if (_isUnread) {
        return (
          bg: AppColors.emergencyRed,
          icon: Icons.warning_rounded,
          fg: Colors.white,
        );
      }
      return (
        bg: AppColors.emergencyTint,
        icon: Icons.warning_amber_rounded,
        fg: _emergencyTitleRead,
      );
    }
    return switch (notification.category) {
      AppNotificationCategory.mention => (
          bg: _mentionBg,
          icon: Icons.alternate_email,
          fg: _mentionFg,
        ),
      AppNotificationCategory.handoff => (
          bg: AppColors.statusPendTint,
          icon: Icons.swap_horiz_rounded,
          fg: AppColors.statusPending,
        ),
      AppNotificationCategory.invite => (
          bg: AppColors.tealTint,
          icon: Icons.group_add_outlined,
          fg: AppColors.tealPrimary,
        ),
      AppNotificationCategory.reply ||
      AppNotificationCategory.message ||
      AppNotificationCategory.announcement ||
      AppNotificationCategory.other =>
        (
          bg: AppColors.tealTint,
          icon: Icons.chat_bubble_outline,
          fg: AppColors.tealPrimary,
        ),
    };
  }
}
