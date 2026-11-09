// Sanity F4 / REQ 7: initials skip titles so doctors are distinguishable
// once a profile photo is removed.
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/shared/presentation/widgets/app_avatar.dart';

void main() {
  test('skips Dr/Prof titles and uses first + last initials', () {
    expect(avatarInitials('Dr Asha Rao'), 'AR');
    expect(avatarInitials('Dr. Vikram Shah'), 'VS');
    expect(avatarInitials('Prof Meera K Iyer'), 'MI');
    expect(avatarInitials('dr  ravi'), 'R');
  });

  test('edge cases', () {
    expect(avatarInitials(''), '?');
    expect(avatarInitials('   '), '?');
    expect(avatarInitials('Dr'), 'D', reason: 'title only: keep it');
    expect(avatarInitials('ananya'), 'A');
  });
}
