// Issue 9 (beta 11-14): @mention suggestions must tell people apart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/core/constants/app_enums.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/presentation/widgets/mention_composer.dart';

const _me = UserModel(id: 'me', name: 'Meera Iyer', displayTitle: 'Dr');
const _rao1 = UserModel(
  id: 'u1',
  name: 'Asha Rao',
  displayTitle: 'Dr',
  vocleUsername: 'asharao',
  speciality: 'Cardiology',
  role: UserRole.pgResident,
);
const _rao2 = UserModel(
  id: 'u2',
  name: 'Asha Rao',
  displayTitle: 'Dr',
  vocleUsername: 'asharao2',
  speciality: 'Anaesthesia',
  role: UserRole.consultant,
);
const _bala = UserModel(id: 'u3', name: 'Bala Krishnan', vocleUsername: 'bala');
const _raj = UserModel(id: 'u4', name: 'Rajesh Kumar', vocleUsername: 'rk');

void main() {
  final all = [_me, _rao1, _rao2, _bala, _raj, _rao1 /* duplicate */];

  test('prefix matches first, self excluded, one row per person', () {
    final r = rankMentionCandidates(all, 'ra', excludeSelfId: 'me');
    expect(r.map((u) => u.id), ['u4', 'u1', 'u2'],
        reason: 'Rajesh (name starts with "ra") before the Raos (later word)');
    expect(rankMentionCandidates(all, '', excludeSelfId: 'me').length, 4);
  });

  test('matches @username too', () {
    expect(rankMentionCandidates(all, 'asharao2').single.id, 'u2');
    expect(rankMentionCandidates(all, 'rk').single.id, 'u4');
  });

  test('same-name doctors get different subtitles and colours', () {
    expect(mentionSubtitle(_rao1), '@asharao · Cardiology · PG Resident');
    expect(mentionSubtitle(_rao2), '@asharao2 · Anaesthesia · Consultant');
    expect(mentionAvatarColor('u1'), isNot(mentionAvatarColor('u2')));
    expect(mentionAvatarColor('u1'), mentionAvatarColor('u1'), reason: 'stable');
  });

  testWidgets('typing @ shows the panel; picking inserts the mention',
      (tester) async {
    final controller = TextEditingController();
    List<String>? sentIds;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MentionAwareComposer(
            controller: controller,
            mentionCandidates: all,
            excludeSelfId: 'me',
            onSend: (_, ids) => sentIds = ids,
          ),
        ),
      ),
    ));
    controller.value = const TextEditingValue(
      text: 'Please see @asha',
      selection: TextSelection.collapsed(offset: 16),
    );
    await tester.pump();
    expect(find.byKey(const Key('mention-suggestions')), findsOneWidget);
    expect(find.text('@asharao · Cardiology · PG Resident'), findsOneWidget);
    expect(find.text('@asharao2 · Anaesthesia · Consultant'), findsOneWidget);
    expect(find.text('Meera Iyer'), findsNothing);

    await tester.tap(find.byKey(const Key('mention-row-u2')));
    await tester.pump();
    expect(controller.text, 'Please see @Asha Rao ');
    expect(find.byKey(const Key('mention-suggestions')), findsNothing);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sentIds, ['u2'],
        reason: 'only the picked Dr Asha Rao, not her namesake');
  });
}
