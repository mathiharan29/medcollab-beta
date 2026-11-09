import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';

/// Hosts the bottom-tab branch navigators in a horizontal [PageView] so the
/// main tabs (Home, Messages, Handoffs, Alerts, Profile) can be swiped
/// (REQ 8), while every branch keeps its state like the default IndexedStack.
///
/// Pages with their own horizontal tabs (Messages: Direct/Needl/Groups,
/// Handoffs: Pending/Active/Done) keep their inner swipe; swiping past an
/// inner tab's first/last page continues to the neighbouring main tab.
class SwipeableShellContainer extends StatefulWidget {
  const SwipeableShellContainer({
    required this.navigationShell,
    required this.children,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<SwipeableShellContainer> createState() =>
      _SwipeableShellContainerState();
}

class _SwipeableShellContainerState extends State<SwipeableShellContainer> {
  late final PageController _controller;

  /// Overscroll (px) at an inner tab edge needed to switch main tab.
  static const _edgeHandoffThreshold = 28.0;
  double _innerOverscroll = 0;
  bool _handedOffThisDrag = false;

  int get _index => widget.navigationShell.currentIndex;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _index);
  }

  @override
  void didUpdateWidget(covariant SwipeableShellContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tab tap, back-to-Home or deep link changed the branch: follow it.
    if (!_controller.hasClients) return;
    // Never fight the user's finger: badge/state rebuilds can land mid-swipe.
    if (_controller.position.isScrollingNotifier.value) return;
    final shown = _controller.page?.round() ?? _index;
    if (shown != _index) {
      _controller.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.children.length || index == _index) return;
    ShellTabHistory.visit(index);
    widget.navigationShell.goBranch(index);
  }

  bool _onNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    if (n.depth == 0) {
      // The main PageView itself.
      if (n is ScrollEndNotification) {
        final page = _controller.page?.round();
        if (page != null && page != _index) _goTo(page);
      }
      return false;
    }
    // A nested horizontal scrollable (inner TabBarView, chip row...).
    if (n is ScrollStartNotification) {
      _innerOverscroll = 0;
      _handedOffThisDrag = false;
    } else if (n is OverscrollNotification && n.dragDetails != null) {
      if (_handedOffThisDrag) return false;
      _innerOverscroll += n.overscroll;
      if (_innerOverscroll.abs() >= _edgeHandoffThreshold) {
        _handedOffThisDrag = true;
        final target = _innerOverscroll > 0 ? _index + 1 : _index - 1;
        if (target >= 0 && target < widget.children.length) {
          _controller.animateToPage(
            target,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
          _goTo(target);
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: PageView(
        controller: _controller,
        // Settle on drag end; branch switch happens in _onNotification.
        onPageChanged: (_) {},
        children: [
          for (final child in widget.children) _KeepAlivePage(child: child),
        ],
      ),
    );
  }
}

/// Keeps an off-screen branch navigator (and its scroll/state) alive.
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
