import 'package:flutter/material.dart';
import 'package:medcollab_app/core/theme/app_colors.dart';
import 'package:medcollab_app/core/theme/app_radius.dart';

/// Dark navy bottom nav — Vocle redesign brief §6 / Step 2.
///
/// Active tab: teal icon + label on a teal/14% rounded chip.
/// Optional [showDot] (8×8 red) or [badgeCount] (pill) for alerts.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    required this.currentIndex,
    required this.onTap,
    this.messagesDot = false,
    this.handoffsDot = false,
    this.alertsBadge = 0,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Red dot on Messages when any unread conversations exist.
  final bool messagesDot;

  /// Red dot on Handoffs when any pending handoffs exist.
  final bool handoffsDot;

  /// Numeric badge on Alerts when unread > 0.
  final int alertsBadge;

  static const _tabs = <_AppNavTab>[
    _AppNavTab(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _AppNavTab(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
    ),
    _AppNavTab(
      label: 'Handoffs',
      icon: Icons.swap_horiz_rounded,
      activeIcon: Icons.swap_horiz_rounded,
    ),
    _AppNavTab(
      label: 'Alerts',
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
    ),
    _AppNavTab(
      label: 'Profile',
      icon: Icons.account_circle_outlined,
      activeIcon: Icons.account_circle_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: AppColors.chrome,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 10, 4, 10 + bottomInset.clamp(0, 20)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_tabs.length, (index) {
            final tab = _tabs[index];
            final isActive = currentIndex == index;
            final showDot = switch (index) {
              1 => messagesDot,
              2 => handoffsDot,
              _ => false,
            };
            final badge = index == 3 ? alertsBadge : 0;

            return _AppNavItem(
              tab: tab,
              isActive: isActive,
              showDot: showDot && badge <= 0,
              badgeCount: badge,
              onTap: () => onTap(index),
            );
          }),
        ),
      ),
    );
  }
}

class _AppNavTab {
  const _AppNavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _AppNavItem extends StatelessWidget {
  const _AppNavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    this.showDot = false,
    this.badgeCount = 0,
  });

  final _AppNavTab tab;
  final bool isActive;
  final VoidCallback onTap;
  final bool showDot;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.tealPrimary
        : Colors.white.withValues(alpha: 0.35);

    final semanticsLabel = switch (true) {
      _ when badgeCount > 0 =>
        '${tab.label}, $badgeCount unread alerts',
      _ when showDot => '${tab.label}, unread',
      _ => tab.label,
    };

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: semanticsLabel,
        excludeSemantics: true,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 32,
              decoration: isActive
                  ? BoxDecoration(
                      color: AppColors.tealPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      isActive ? tab.activeIcon : tab.icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  if (showDot)
                    Positioned(
                      top: 2,
                      right: 4,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: const ValueKey('nav-dot'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.chrome,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 0,
                      right: 2,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: ValueKey('nav-badge-$badgeCount'),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed,
                            borderRadius: AppRadius.pill,
                            border: Border.all(
                              color: AppColors.chrome,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            badgeCount > 99 ? '99+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                color: color,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
