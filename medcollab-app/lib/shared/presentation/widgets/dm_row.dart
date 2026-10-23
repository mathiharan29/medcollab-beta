import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';
import 'package:medcollab_app/shared/presentation/widgets/typing_bubble.dart';

/// Direct-message list row (brief SCREEN 2).
class DMRow extends StatelessWidget {
  const DMRow({
    required this.name,
    required this.preview,
    this.imageUrl,
    this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
    this.typingLabel,
    this.onTap,
    this.leading,
    this.elevated = false,
    super.key,
  });

  final String name;
  final String preview;
  final String? imageUrl;
  final String? timestamp;
  final int unreadCount;
  final bool isOnline;
  final String? typingLabel;
  final VoidCallback? onTap;

  /// Replaces the initials avatar (e.g. Needl hub icon).
  final Widget? leading;

  /// Adds a light shadow so the card separates from the grey background.
  final bool elevated;

  static Color colorFromName(String name) {
    const palette = <Color>[
      Color(0xFF00A88F),
      Color(0xFF6366F1),
      Color(0xFF0EA5E9),
      Color(0xFFD97706),
      Color(0xFFEC4899),
      Color(0xFF059669),
      Color(0xFF8B5CF6),
      Color(0xFF1A6FBF),
    ];
    if (name.isEmpty) return palette[0];
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash + unit * 31) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(
              color: typingLabel != null
                  ? AppColors.tealPrimary
                  : AppColors.borderDefault,
              width: typingLabel != null ? 1 : 0.5,
            ),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              leading ??
                  AppAvatar(
                    name: name,
                    imageUrl: imageUrl,
                    size: 38,
                    showPresence: true,
                    isOnline: isOnline,
                    backgroundColor:
                        colorFromName(name).withValues(alpha: 0.18),
                    foregroundColor: colorFromName(name),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    if (typingLabel != null)
                      TypingBubble(compact: true, label: typingLabel)
                    else
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              if (timestamp != null && timestamp!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(timestamp!, style: AppTextStyles.timestamp),
              ],
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.tealPrimary,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
