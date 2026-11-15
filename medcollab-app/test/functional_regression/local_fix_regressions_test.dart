// Regression tests for fixes ported from the Oct 2026 local E2E run
// (docs/E2E_FUNCTIONAL_REPORT.md defects #2, #6, #7).
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/handoffs/presentation/utils/handoff_doctor_options.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/message_request_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/chat_fakes.dart';

class _RejectedSession extends AuthRepository {
  _RejectedSession(FakeSocketClient socket)
      : super(
          apiClient: isolatedApiClient(),
          storage: SecureStorageService(),
          socketClient: socket,
        );
  int logoutCalls = 0;

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<void> restoreSocketConnection() async {}

  @override
  Future<void> logout({String? fcmToken}) async {
    logoutCalls++;
    throw const UnknownException('No token provided');
  }
}

class _RejectingProfiles extends UserRepository {
  _RejectingProfiles() : super(apiClient: isolatedApiClient());

  @override
  Future<UserModel> getMe() async =>
      throw const UnauthorizedException('Session expired');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('#7 rejected saved session', () {
    test('reaches unauthenticated even when logout throws', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final socket = FakeSocketClient();
      final session = _RejectedSession(socket);
      final auth = AuthBloc(
        authRepository: session,
        userRepository: _RejectingProfiles(),
      );
      addTearDown(() async {
        await auth.close();
        await socket.disposeFake();
      });

      auth.add(const AuthStarted());
      final settled = await auth.stream
          .firstWhere((s) => s.status != AuthStatus.loading)
          .timeout(const Duration(seconds: 5));

      expect(settled.status, AuthStatus.unauthenticated);
      expect(session.logoutCalls, 1);
    });
  });

  group('#6 handoff assigned-doctor dropdown options', () {
    const a1 = UserModel(id: 'a', name: 'Dr A');
    const a2 = UserModel(id: 'a', name: 'Dr A (dup row)');
    const b = UserModel(id: 'b', name: 'Dr B');
    const blank = UserModel(id: '', name: 'No id');

    test('dedupes by id and drops blank ids', () {
      final r = handoffDoctorOptions([a1, blank, a2, b], null);
      expect(r.doctors.map((u) => u.id), ['a', 'b']);
      expect(r.selected, isNull);
    });

    test('selects the list instance matching the assignee id', () {
      // Different instance/field values than the member row.
      const savedAssignee = UserModel(id: 'b', name: 'Dr B (stale copy)');
      final r = handoffDoctorOptions([a1, b], savedAssignee);
      expect(identical(r.selected, b), isTrue);
    });

    test('returns null when the assignee is no longer a member', () {
      const gone = UserModel(id: 'z', name: 'Dr Gone');
      expect(handoffDoctorOptions([a1, b], gone).selected, isNull);
    });

    testWidgets('dropdown renders with a non-identical assignee',
        (tester) async {
      const savedAssignee = UserModel(id: 'b', name: 'Dr B (stale copy)');
      final r = handoffDoctorOptions([a1, a2, b], savedAssignee);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DropdownButtonFormField<UserModel>(
            value: r.selected,
            items: r.doctors
                .map((u) => DropdownMenuItem(value: u, child: Text(u.name!)))
                .toList(),
            onChanged: (_) {},
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Dr B'), findsOneWidget);
    });
  });

  group('#2 message-request intro dialog', () {
    /// Pumps a host app and opens the dialog. Returned in a list so the
    /// dialog future is not flattened into this async helper.
    Future<List<Future<String?>>> openDialog(WidgetTester tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ));
      final future = showMessageRequestIntroDialog(
        ctx,
        title: 'Send message request',
        explanation: 'They will see your name and this note.',
        hintText: 'Optional',
      );
      await tester.pumpAndSettle();
      return [future];
    }

    testWidgets('send returns trimmed note with no disposed-controller error',
        (tester) async {
      final pending = (await openDialog(tester)).single;
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  need a consult  ');
      await tester.tap(find.text('Send request'));
      // Run the full exit animation; the old code disposed the controller
      // while the TextField was still being rebuilt here.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(await pending, 'need a consult');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('cancel returns null cleanly', (tester) async {
      final pending = (await openDialog(tester)).single;
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await pending, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
