// REQ-1: On Messages → Groups, system back with the Create group dialog
// (or its Type dropdown) open must close that popup, not jump to Home
// leaving the dialog on screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/router/app_navigation_back_handler.dart';
import 'package:medcollab_app/core/router/popup_route_tracker.dart';
import 'package:medcollab_app/core/router/shell_tab_history.dart';
import 'package:medcollab_app/features/spaces/presentation/widgets/create_space_dialog.dart';

const _home = '/home';
const _messages = '/messages';

class _Harness {
  _Harness() {
    router = GoRouter(
      initialLocation: _messages,
      observers: [popups.createObserver()],
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) {
            ShellTabHistory.bind(shell);
            return Scaffold(body: shell);
          },
          branches: [
            StatefulShellBranch(
              observers: [popups.createObserver()],
              routes: [
                GoRoute(
                  path: _home,
                  builder: (_, __) => const Center(child: Text('HOME TAB')),
                ),
              ],
            ),
            StatefulShellBranch(
              observers: [popups.createObserver()],
              routes: [
                GoRoute(
                  path: _messages,
                  builder: (context, __) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('GROUPS TAB'),
                        TextButton(
                          onPressed: () async {
                            createdResult = await CreateSpaceDialog.show(
                              context,
                              createSpace: (
                                  {required String name,
                                  required SpaceType type}) async {
                                created.add((name, type));
                              },
                            );
                          },
                          child: const Text('New group'),
                        ),
                        TextButton(
                          // Bottom sheets default to the branch navigator.
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => const SizedBox(
                              height: 120,
                              child: Text('BRANCH SHEET'),
                            ),
                          ),
                          child: const Text('Open sheet'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final popups = PopupRouteTracker();
  late final GoRouter router;
  final created = <(String, SpaceType)>[];
  bool? createdResult;

  String get path => router.routeInformationProvider.value.uri.path;

  Widget app() => MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AppNavigationBackHandler(
          router: router,
          popupTracker: popups,
          child: child ?? const SizedBox.shrink(),
        ),
      );
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  late _Harness h;

  setUp(() => h = _Harness());
  tearDown(() => h.router.dispose());

  testWidgets('back closes Create group dialog and stays on Messages',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(h.path, _messages);

    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    expect(find.text('Create space'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ward 5');

    await _systemBack(tester);

    expect(find.text('Create space'), findsNothing,
        reason: 'dialog must be dismissed by back');
    expect(h.path, _messages, reason: 'back must not also leave Messages');
    expect(find.text('GROUPS TAB'), findsOneWidget);
    expect(h.createdResult, isFalse);
    expect(h.created, isEmpty);
    expect(h.popups.hasOpenPopup, isFalse);
    expect(tester.takeException(), isNull,
        reason: 'no "controller used after disposed" during exit animation');
  });

  testWidgets('back closes the open Type dropdown first, then the dialog',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();

    // Open the department/type dropdown menu.
    await tester.tap(find.text(SpaceType.department.label));
    await tester.pumpAndSettle();
    expect(find.text(SpaceType.department.label), findsNWidgets(2),
        reason: 'menu open: selected value + menu item');

    await _systemBack(tester);
    expect(find.text(SpaceType.department.label), findsOneWidget,
        reason: 'menu closed');
    expect(find.text('Create space'), findsOneWidget,
        reason: 'dialog still open after first back');
    expect(h.path, _messages);

    await _systemBack(tester);
    expect(find.text('Create space'), findsNothing);
    expect(h.path, _messages);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back closes a branch-navigator bottom sheet on a tab root',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('BRANCH SHEET'), findsOneWidget);

    await _systemBack(tester);
    expect(find.text('BRANCH SHEET'), findsNothing);
    expect(h.path, _messages);
  });

  testWidgets('with no popup open, back on Messages still goes Home',
      (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await _systemBack(tester);
    expect(h.path, _home, reason: 'existing tab-back behaviour unchanged');
    expect(find.text('HOME TAB'), findsOneWidget);
  });

  testWidgets('Create still creates and closes the dialog', (tester) async {
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Ward 5  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(h.created, [('Ward 5', SpaceType.department)]);
    expect(h.createdResult, isTrue);
    expect(find.text('Create space'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
