// F5: typing into a filled OTP box replaces its digit.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/storage/secure_storage_service.dart';
import 'package:medcollab_app/features/auth/data/repositories/auth_repository.dart';
import 'package:medcollab_app/features/auth/data/repositories/user_repository.dart';
import 'package:medcollab_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:medcollab_app/features/auth/presentation/pages/otp_verification_page.dart';

import 'fakes/chat_fakes.dart';

void main() {
  testWidgets('F5: overwrite a filled box without backspacing first',
      (tester) async {
    final socket = FakeSocketClient();
    final auth = AuthBloc(
      authRepository: AuthRepository(
        apiClient: isolatedApiClient(),
        storage: SecureStorageService(),
        socketClient: socket,
      ),
      userRepository: UserRepository(apiClient: isolatedApiClient()),
    );
    addTearDown(() async {
      await auth.close();
      await socket.disposeFake();
    });

    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: auth,
      child: const MaterialApp(home: OtpVerificationPage()),
    ));
    await tester.pump();

    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(6));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '${i + 1}');
      await tester.pump();
    }
    String box(int i) =>
        (tester.widget<TextField>(boxes.at(i)).controller!).text;
    expect([for (var i = 0; i < 6; i++) box(i)].join(), '123456');

    // Doctor taps box 3 (holds "3") and types 9: the box becomes "9".
    await tester.enterText(boxes.at(2), '39');
    await tester.pump();
    expect(box(2), '9');
    expect([for (var i = 0; i < 6; i++) box(i)].join(), '129456');

    // Same in the first box, which also accepts full SMS autofill.
    await tester.enterText(boxes.at(0), '17');
    await tester.pump();
    expect(box(0), '7');

    // Full 6-digit autofill still fills every box.
    await tester.enterText(boxes.at(0), '654321');
    await tester.pump();
    expect([for (var i = 0; i < 6; i++) box(i)].join(), '654321');
  });
}
