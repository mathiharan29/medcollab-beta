// REQ 3: system back from anywhere inside the app goes to Home (popups
// close first; Home asks before exiting). The catalog case now covers REQ 3.
// REQ 8: main tabs can be swiped; inner tabs swipe first and hand off to
// the neighbouring main tab at their edge; tab state is preserved.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/app_navigation_back_handler.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/router/back_guard.dart';
import 'package:medcollab_app/core/router/popup_route_tracker.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';
import 'package:medcollab_app/features/shell/presentation/widgets/swipeable_shell_container.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('Home taps $taps'),
      );
}

class _Harness {
  _Harness() {
    router = GoRouter(
      initialLocation: AppRoutes.home,
      observers: [popups.createObserver()],
      routes: [
        StatefulShellRoute(
          builder: (context, state, shell) {
            ShellTabHistory.bind(shell);
            return Scaffold(
              body: shell,
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: shell.currentIndex,
                onTap: (i) {
                  ShellTabHistory.visit(i);
                  shell.goBranch(i, initialLocation: i == shell.currentIndex);
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
                  BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Handoffs'),
                ],
              ),
            );
          },
          navigatorContainerBuilder: (context, shell, children) =>
              SwipeableShellContainer(navigationShell: shell, children: children),
          branches: [
            StatefulShellBranch(
              observers: [popups.createObserver()],
              routes: [GoRoute(path: AppRoutes.home,
                  builder: (_, __) => const Center(child: _Counter()))],
            ),
            StatefulShellBranch(
              observers: [popups.createObserver()],
              routes: [GoRoute(path: AppRoutes.messages,
                  builder: (context, _) => DefaultTabController(
                        length: 2,
                        child: Column(children: [
                          const TabBar(tabs: [Tab(text: 'Direct'), Tab(text: 'Groups')]),
                          Expanded(child: TabBarView(children: [
                            Center(child: FilledButton(
                              onPressed: () => context.push('/chat'),
                              child: const Text('DIRECT PAGE'),
                            )),
                            const Center(child: Text('GROUPS PAGE')),
                          ])),
                        ]),
                      ))],
            ),
            StatefulShellBranch(
              observers: [popups.createObserver()],
              routes: [GoRoute(path: AppRoutes.handoffs,
                  builder: (_, __) => const Center(child: Text('HANDOFFS PAGE')))],
            ),
          ],
        ),
        GoRoute(path: '/chat',
            builder: (_, __) => const Scaffold(body: Center(child: Text('CHAT PAGE')))),
      ],
    );
  }

  final popups = PopupRouteTracker();
  late final GoRouter router;
  String get path => router.state.uri.path;

  Widget app() => MaterialApp.router(
        routerConfig: router,
        builder: (_, child) => AppNavigationBackHandler(
          router: router,
          popupTracker: popups,
          child: child ?? const SizedBox.shrink(),
        ),
      );
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Future<void> _swipe(WidgetTester tester, {required bool left}) async {
  await tester.fling(find.byType(PageView).first,
      Offset(left ? -600 : 600, 0), 1500);
  await tester.pumpAndSettle();
}

void main() {
  late _Harness h;
  setUp(() {
    BackGuard.clear();
    h = _Harness();
  });
  tearDown(() => h.router.dispose());

  testWidgets('FR-NAV-03: system Back from a chat returns directly to Home',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DIRECT PAGE'));
    await tester.pumpAndSettle();
    expect(h.path, '/chat');

    await _back(tester);
    expect(h.path, AppRoutes.home,
        reason: 'not back to the Messages tab — Home');
    expect(find.text('Home taps 0'), findsOneWidget);
  });

  testWidgets('REQ 3: back from another tab goes Home; Home asks before exit',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Handoffs'));
    await tester.pumpAndSettle();
    expect(h.path, AppRoutes.handoffs);

    await _back(tester);
    expect(h.path, AppRoutes.home);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Swipe back again to exit Vocle'), findsOneWidget);
    expect(h.path, AppRoutes.home);
  });

  testWidgets('REQ 3: leaving Home disarms "back again to exit"',
      (tester) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute(); // arms exit on Home
    await tester.pump();
    await tester.tap(find.text('Handoffs'));
    await tester.pumpAndSettle();
    await _back(tester); // back to Home
    await tester.binding.handlePopRoute(); // first back on Home again
    await tester.pump();
    expect(exits, 0, reason: 'must prompt again, not close the app');
    expect(find.text('Swipe back again to exit Vocle'), findsOneWidget);

    await tester.binding.handlePopRoute(); // deliberate second back
    await tester.pump();
    expect(exits, 1);
  });

  testWidgets('REQ 3: a dirty screen can veto back, then allow it',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Handoffs'));
    await tester.pumpAndSettle();

    var allow = false;
    Future<bool> guard() async => allow;
    BackGuard.register(guard);
    await _back(tester);
    expect(h.path, AppRoutes.handoffs, reason: 'guard vetoed leaving');

    allow = true;
    await _back(tester);
    expect(h.path, AppRoutes.home);
    BackGuard.unregister(guard);
  });

  testWidgets('REQ 3: popup closes first, then back goes Home', (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Handoffs'));
    await tester.pumpAndSettle();
    showDialog<void>(
      context: tester.element(find.text('HANDOFFS PAGE')),
      builder: (_) => const AlertDialog(content: Text('A DIALOG')),
    );
    await tester.pumpAndSettle();

    await _back(tester);
    expect(find.text('A DIALOG'), findsNothing);
    expect(h.path, AppRoutes.handoffs, reason: 'only the dialog closed');
    await _back(tester);
    expect(h.path, AppRoutes.home);
  });

  testWidgets('REQ 8: swipe moves between main tabs and keeps state',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home taps 0'));
    await tester.pump();
    expect(find.text('Home taps 1'), findsOneWidget);

    await _swipe(tester, left: true);
    expect(h.path, AppRoutes.messages);
    expect(find.text('DIRECT PAGE'), findsOneWidget);
    final bar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.currentIndex, 1, reason: 'bottom bar follows the swipe');

    await _swipe(tester, left: false);
    expect(h.path, AppRoutes.home);
    expect(find.text('Home taps 1'), findsOneWidget,
        reason: 'tab state survives swiping away and back');

    // Tapping a tab still works and moves the page.
    await tester.tap(find.text('Handoffs'));
    await tester.pumpAndSettle();
    expect(find.text('HANDOFFS PAGE'), findsOneWidget);
  });

  testWidgets('REQ 8: inner tabs swipe first, then hand off at their edge',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    // First swipe: inner Direct → Groups, still on Messages.
    await tester.fling(find.text('DIRECT PAGE'), const Offset(-600, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('GROUPS PAGE'), findsOneWidget);
    expect(h.path, AppRoutes.messages);

    // Second swipe at the inner edge: continue to Handoffs.
    await tester.drag(find.text('GROUPS PAGE'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(h.path, AppRoutes.handoffs);
    expect(find.text('HANDOFFS PAGE'), findsOneWidget);
  });
}
