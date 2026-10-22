import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/core/di/app_dependencies.dart';
import 'package:medcollab_app/core/error/app_exception.dart';
import 'package:medcollab_app/core/router/app_routes.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/models/update_profile_request.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:medcollab_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:medcollab_app/features/profile/presentation/pages/profile_page.dart';

import 'fakes/chat_fakes.dart';

class _Session extends AuthRepository {
  _Session(FakeSocketClient socket) : super(
    apiClient: isolatedApiClient(), storage: SecureStorageService(), socketClient: socket,
  );

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<void> restoreSocketConnection() async {}
}

class _Profiles extends UserRepository {
  _Profiles() : super(apiClient: isolatedApiClient());

  UserModel persisted = const UserModel(
    id: 'doctor-synthetic', name: 'Doctor Original',
    role: UserRole.intern, institution: 'Original Hospital', isOnboarded: true,
  );
  int reads = 0;
  final writes = <UpdateProfileRequest>[];
  bool failNext = true;

  @override
  Future<UserModel> getMe() async {
    reads++;
    return persisted;
  }

  @override
  Future<UserModel> updateMe(UpdateProfileRequest request) async {
    writes.add(request);
    if (failNext) {
      failNext = false;
      throw const ServerException('Synthetic profile save failed');
    }
    persisted = persisted.copyWith(
      name: request.name, role: request.role,
      speciality: request.speciality, institution: request.institution,
    );
    return persisted;
  }
}

void main() {
  testWidgets('FR-PRO-05: cancel, failed save, retry and reload profile', (tester) async {
    final socket = FakeSocketClient();
    final profiles = _Profiles();
    AppDependencies.instance.userRepository = profiles;
    final auth = AuthBloc(authRepository: _Session(socket), userRepository: profiles);
    addTearDown(() async {
      await auth.close();
      await socket.disposeFake();
    });
    auth.add(const AuthStarted());
    await auth.stream.firstWhere((s) => s.status == AuthStatus.authenticated);
    expect(profiles.reads, 1);

    final router = GoRouter(initialLocation: AppRoutes.profile, routes: [
      GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfilePage()),
      GoRoute(path: AppRoutes.editProfile, builder: (_, __) => const EditProfilePage()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth, child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Doctor Original'), findsOneWidget);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextFormField, 'Full name');
    final institution = find.widgetWithText(TextFormField, 'Medical college / hospital');
    await tester.enterText(name, 'Cancelled Name');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(profiles.writes, isEmpty, reason: 'Cancel must not submit a request');
    expect(profiles.persisted.name, 'Doctor Original');

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(name, 'Doctor Revised');
    await tester.enterText(institution, 'Synthetic Hospital');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(profiles.writes, hasLength(1));
    expect(profiles.writes.single.name, 'Doctor Revised');
    expect(profiles.writes.single.institution, 'Synthetic Hospital');
    expect(profiles.persisted.name, 'Doctor Original',
        reason: 'Failed save must leave persisted profile unchanged');
    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(tester.widget<TextFormField>(name).controller!.text, 'Doctor Revised');
    expect(tester.widget<TextFormField>(institution).controller!.text,
        'Synthetic Hospital');
    expect(find.text('Synthetic profile save failed'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(profiles.writes, hasLength(2));
    expect(profiles.writes[1], profiles.writes[0],
        reason: 'Retry must submit the retained form values');
    expect(find.byType(EditProfilePage), findsNothing);
    expect(profiles.persisted.name, 'Doctor Revised');
    expect(profiles.persisted.institution, 'Synthetic Hospital');
    expect(auth.state.user?.name, 'Doctor Revised');
    expect(find.text('Doctor Revised'), findsOneWidget);

    final reloaded = await profiles.getMe();
    auth.add(AuthUserUpdated(reloaded));
    await tester.pumpAndSettle();
    expect(profiles.reads, 2);
    expect(reloaded.name, 'Doctor Revised');
    expect(find.text('Doctor Revised'), findsOneWidget);
    expect(find.text('Synthetic Hospital'), findsOneWidget);
  });
}
