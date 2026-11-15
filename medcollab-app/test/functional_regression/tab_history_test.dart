// Back (beta 11-14, supersedes REQ 3's "always Home"): system back / edge
// swipe moves ONE level up — chat → Messages, settings page → Profile,
// thread → chat; a main tab → Home; Home asks before exiting. Popups close
// first; dirty screens can veto.
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
                  BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
            StatefulShellBranch(
              observers: [popups.createObserver()],
              routes: [GoRoute(path: AppRoutes.profile,
                  builder: (context, _) => Center(child: FilledButton(
                        onPressed: () => context.push(AppRoutes.notificationSettings),
                        child: const Text('PROFILE PAGE'),
                      )))],
            ),
          ],
        ),
        GoRoute(path: '/chat',
            builder: (_, __) => const Scaffold(body: Center(child: Text('CHAT PAGE')))),
        GoRoute(path: AppRoutes.notificationSettings,
            builder: (context, _) => Scaffold(body: Center(child: FilledButton(
                  onPressed: () => context.push(AppRoutes.editProfile),
                  child: const Text('SETTINGS PAGE'),
                )))),
        GoRoute(path: AppRoutes.editProfile,
            builder: (_, __) => const Scaffold(body: Center(child: Text('EDIT PAGE')))),
        GoRoute(path: AppRoutes.dm,
            builder: (context, s) => Scaffold(body: Center(child: FilledButton(
                  onPressed: () => context.push(
                      AppRoutes.dmThreadPath(s.pathParameters['channelId']!, 'm1')),
                  child: const Text('DM PAGE'),
                )))),
        GoRoute(path: AppRoutes.dmThread,
            builder: (_, __) => const Scaffold(body: Center(child: Text('THREAD PAGE')))),
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

  testWidgets('back from a chat goes to Messages, then Home', (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DIRECT PAGE'));
    await tester.pumpAndSettle();
    expect(h.path, '/chat');

    await _back(tester);
    expect(h.path, AppRoutes.messages, reason: 'one level up: chat home');
    expect(find.text('DIRECT PAGE'), findsOneWidget,
        reason: 'same inner tab (Direct) as before opening the chat');

    await _back(tester);
    expect(h.path, AppRoutes.home);
  });

  testWidgets('settings: sub-page → parent page → Profile → Home',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PROFILE PAGE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SETTINGS PAGE'));
    await tester.pumpAndSettle();
    expect(h.path, AppRoutes.editProfile);

    await _back(tester);
    expect(h.path, AppRoutes.notificationSettings);
    await _back(tester);
    expect(h.path, AppRoutes.profile);
    await _back(tester);
    expect(h.path, AppRoutes.home);
  });

  testWidgets('thread → its chat → Messages → Home', (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    h.router.push(AppRoutes.dmPath('c1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DM PAGE'));
    await tester.pumpAndSettle();
    expect(h.path, AppRoutes.dmThreadPath('c1', 'm1'));

    await _back(tester);
    expect(h.path, AppRoutes.dmPath('c1'));
    await _back(tester);
    expect(h.path, AppRoutes.messages);
    await _back(tester);
    expect(h.path, AppRoutes.home);
  });

  testWidgets('chat opened from a notification (nothing below) → Messages → Home',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.router.go(AppRoutes.dmThreadPath('c9', 'm1'));
    await tester.pumpAndSettle();
    expect(h.router.canPop(), isFalse);

    await _back(tester);
    expect(h.path, AppRoutes.dmPath('c9'));
    await _back(tester);
    expect(h.path, AppRoutes.messages);
    await _back(tester);
    expect(h.path, AppRoutes.home);
  });

  test('logicalParentOf maps every deep screen one level up', () {
    expect(logicalParentOf('/dm/a'), AppRoutes.messages);
    expect(logicalParentOf('/dm/new'), AppRoutes.messages);
    expect(logicalParentOf('/dm/a/threads/m'), '/dm/a');
    expect(logicalParentOf('/spaces/s/channels/c'), AppRoutes.messages);
    expect(logicalParentOf('/spaces/s/channels/c/threads/m'), '/spaces/s/channels/c');
    expect(logicalParentOf('/spaces/s/handoffs/h/edit'), '/spaces/s/handoffs/h');
    expect(logicalParentOf('/spaces/s/handoffs/h'), AppRoutes.handoffs);
    expect(logicalParentOf('/spaces/s/handoffs/create'), '/spaces/s/handoffs');
    expect(logicalParentOf('/spaces/s/handoffs'), '/spaces/s');
    expect(logicalParentOf('/spaces/s/members'), '/spaces/s');
    expect(logicalParentOf('/spaces/s'), AppRoutes.messages);
    expect(logicalParentOf('/profile/edit'), AppRoutes.profile);
    expect(logicalParentOf('/notifications/settings'), AppRoutes.profile);
    expect(logicalParentOf('/bookmarks'), AppRoutes.profile);
    expect(logicalParentOf('/help'), AppRoutes.profile);
    expect(logicalParentOf('/links/c/x/m/y'), AppRoutes.messages);
    expect(logicalParentOf('/search'), AppRoutes.home);
    for (final tab in AppRoutes.shellPaths) {
      expect(logicalParentOf(tab), isNull);
    }
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

  testWidgets('popup closes first, then back goes Home', (tester) async {
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
