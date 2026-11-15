import 'package:flutter/material.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';
import 'package:medcollab_app/core/theme/app_text_styles.dart';

/// Subgroup (channel) list row inside a group (brief SCREEN 3).
class SubgroupRow extends StatelessWidget {
  const SubgroupRow({
    required this.name,
    required this.preview,
    this.type = ChannelType.general,
    this.timestamp,
    this.unreadCount = 0,
    this.hasDraft = false,
    this.onTap,
    super.key,
  });

  final String name;
  final String preview;
  final ChannelType type;
  final String? timestamp;
  final int unreadCount;
  final bool hasDraft;
  final VoidCallback? onTap;

  /// Icon treatment by subgroup name/type — emergency / general / academics /
  /// else grey `#` (brief SCREEN 3).
  static ({Color bg, Color fg, IconData icon}) styleForName(
    String name,
    ChannelType type,
  ) {
    final key = name.toLowerCase().replaceFirst('#', '');
    if (key == 'emergency' || type == ChannelType.emergency) {
      return (
        bg: AppColors.emergencyTint,
        fg: AppColors.emergencyRed,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (key == 'general') {
      return (
        bg: AppColors.tealTint,
        fg: AppColors.tealPrimary,
        icon: Icons.chat_bubble_outline,
      );
    }
    if (key == 'academics' ||
        key == 'academic' ||
        type == ChannelType.academic) {
      return (
        bg: const Color(0xFFEEF2FF),
        fg: const Color(0xFF6366F1),
        icon: Icons.menu_book_outlined,
      );
    }
    return (
      bg: AppColors.surfaceInput,
      fg: AppColors.textMuted,
      icon: Icons.tag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = styleForName(name, type);
    final displayName = name.startsWith('#') ? name : '#$name';

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
              color: AppColors.borderDefault,
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.subgroupIconValue),
                  ),
                ),
                child: Icon(style.icon, color: style.fg, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timestamp != null && timestamp!.isNotEmpty)
                    Text(timestamp!, style: AppTextStyles.timestamp),
                  if (hasDraft) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusPendTint,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        'Draft',
                        style: AppTextStyles.badge.copyWith(
                          color: const Color(0xFF9A4F0A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else if (unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.tealPrimary,
                        borderRadius: AppRadius.pill,
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
            ],
          ),
        ),
      ),
    );
  }
}
