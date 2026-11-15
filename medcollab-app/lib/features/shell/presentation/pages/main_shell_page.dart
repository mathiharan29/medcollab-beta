import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/realtime/hub_refresh_signal.dart';
import 'package:medcollab_app/features/handoffs/presentation/pages/global_handoffs_page.dart';
import 'package:medcollab_app/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:medcollab_app/features/messages_hub/presentation/pages/messages_hub_page.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:medcollab_app/features/profile/presentation/pages/profile_page.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';
import 'package:medcollab_app/features/shell/presentation/cubit/nav_badges_cubit.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_nav_bar.dart';

/// Bottom navigation shell — Vocle redesign Step 2 ([AppNavBar]).
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  @override
  void initState() {
    super.initState();
    ShellTabHistory.bind(widget.navigationShell);
    final deps = AppDependencies.instance;
    if (deps.socketClient.isConnected) {
      deps.socketClient.syncSpaceRooms();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<AuthBloc>().state.user?.id;
      deps.navBadgesCubit.setUserId(userId);
      deps.navBadgesCubit.refresh();
    });
  }

  @override
  void didUpdateWidget(covariant MainShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    ShellTabHistory.bind(widget.navigationShell);
    // However the Messages tab became visible (tap, back, swipe), let it
    // refresh lists that changed while it was hidden.
    if (widget.navigationShell.currentIndex == _messagesTabIndex &&
        oldWidget.navigationShell.currentIndex != _messagesTabIndex) {
      HubRefreshSignal.ping('messages-tab-shown');
    }
  }

  static const _messagesTabIndex = 1;

  void _onTap(int index) {
    ShellTabHistory.visit(index);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (index == 1 || index == 2 || index == 3) {
      AppDependencies.instance.navBadgesCubit.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: BlocBuilder<NavBadgesCubit, NavBadgesState>(
        builder: (context, badges) {
          return AppNavBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onTap,
            alertsBadge: badges.alertsCount,
            messagesDot: badges.messagesDot,
            handoffsDot: badges.handoffsDot,
          );
        },
      ),
    );
  }
}

/// Tab pages registered in [AppRouter] shell branches.
abstract final class ShellTabPages {
  static const home = HomeDashboardPage();
  static const messages = MessagesHubPage();
  static const handoffs = GlobalHandoffsPage();
  static const notifications = NotificationsPage();
  static const profile = ProfilePage();
}
