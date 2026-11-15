import 'package:flutter/widgets.dart';
import 'package:medcollab_app/core/chat/active_chat_tracker.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';

/// Reconnects the socket when the app returns to the foreground.
class AppLifecycleHandler extends StatefulWidget {
  const AppLifecycleHandler({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final deps = AppDependencies.instance;
    final tracker = ActiveChatTracker.instance;
    switch (state) {
      case AppLifecycleState.resumed:
        tracker.setForeground(true);
        deps.authRepository.ensureSocketConnected();
        // Alerts may have changed while away (read from the notification
        // shade, on another phone, new messages). The chat on screen is
        // being read again, so its alerts clear now.
        final open = tracker.channelId;
        if (open != null) {
          deps.notificationBadgeCubit.markChatRead(open);
        }
        deps.navBadgesCubit.refresh();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        tracker.setForeground(false);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
