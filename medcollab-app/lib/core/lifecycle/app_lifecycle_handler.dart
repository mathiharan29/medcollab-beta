import 'package:flutter/widgets.dart';
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
    if (state == AppLifecycleState.resumed) {
      AppDependencies.instance.authRepository.ensureSocketConnected();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
