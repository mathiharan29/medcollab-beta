import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/router/app_navigation_back_handler.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';

void main() {
  testWidgets('FR-NAV-03: nested detail pops before tab visit history',
      (tester) async {
    final paths = <String>[];
    final router = GoRouter(initialLocation: AppRoutes.home, routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) {
          ShellTabHistory.bind(shell);
          return Scaffold(
            body: shell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: shell.currentIndex,
              onTap: (index) {
                ShellTabHistory.visit(index);
                shell.goBranch(index,
                    initialLocation: index == shell.currentIndex);
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
                BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Handoffs'),
              ],
            ),
          );
        },
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.home,
              builder: (_, __) => const Center(child: Text('Home content')))]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.messages,
              builder: (_, __) => const Center(child: Text('Messages content')))]),
          StatefulShellBranch(routes: [GoRoute(path: AppRoutes.handoffs,
              builder: (context, _) => Center(child: FilledButton(
                onPressed: () => context.push('/handoff-detail'),
                child: const Text('Open handoff detail'),
              )))]),
        ],
      ),
      GoRoute(path: '/handoff-detail',
          builder: (_, __) => const Scaffold(body: Center(
            child: Text('Handoff detail content'),
          ))),
    ]);
    addTearDown(router.dispose);
    router.routerDelegate.addListener(() => paths.add(router.state.uri.path));
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (_, child) => AppNavigationBackHandler(
          child: child ?? const SizedBox.shrink()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Messages content'), findsOneWidget);
    await tester.tap(find.text('Handoffs'));
    await tester.pumpAndSettle();
    expect(find.text('Open handoff detail'), findsOneWidget);
    await tester.tap(find.text('Open handoff detail'));
    await tester.pumpAndSettle();
    expect(find.text('Handoff detail content'), findsOneWidget);
    expect(router.state.uri.path, '/handoff-detail');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open handoff detail'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.handoffs);
    final tabBackPaths = <String>[];
    for (var attempt = 0;
        attempt < 3 && router.state.uri.path != AppRoutes.home;
        attempt++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      tabBackPaths.add(router.state.uri.path);
    }
    expect(paths, containsAllInOrder([
      AppRoutes.messages, AppRoutes.handoffs, '/handoff-detail',
      AppRoutes.handoffs,
    ]));
    expect(paths.where((path) => path == '/handoff-detail').length, 1,
        reason: 'Nested detail must not remain duplicated in route history');
    expect(ShellTabHistory.goBack(), isTrue,
        reason: 'The tab history itself retains the prior Messages visit');
    await tester.pumpAndSettle();
    expect(find.text('Messages content'), findsOneWidget);
    expect(ShellTabHistory.goBack(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);
    expect(tabBackPaths, [AppRoutes.messages, AppRoutes.home],
        reason: 'Each Back from a shell tab must restore exactly one prior tab');
  });
}
