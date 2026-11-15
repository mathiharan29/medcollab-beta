// Issue 14 (beta 11-14): built-in voice command parser (private, on-device).
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_actions.dart';
import 'package:medcollab_app/features/voice_bot/domain/voice_command_parser.dart';

const _arjun = VoiceTarget(id: 'p:a', name: 'Dr Arjun Rao', username: 'arjunrao', speciality: 'Surgery');
const _bala = VoiceTarget(id: 'p:b', name: 'Dr Bala Krishnan', username: 'bala', speciality: 'Anaesthesia');
const _asha1 = VoiceTarget(id: 'p:1', name: 'Dr Asha Rao', username: 'asharao', speciality: 'Cardiology');
const _asha2 = VoiceTarget(id: 'p:2', name: 'Dr Asha Rao', username: 'asharao2', speciality: 'Nephrology');
const _ward = VoiceTarget(id: 'c:w', name: 'Ward 5 #general', kind: 'group', spaceId: 's');
const _needl = VoiceTarget(id: 'c:n', name: 'Dr Arjun Rao, Dr Bala Krishnan', kind: 'needl');

const _parser = VoiceCommandParser(VoiceDirectory(
  people: [_arjun, _bala, _asha1, _asha2],
  chats: [_ward, _needl],
));

VoiceAction _one(String s) {
  final r = _parser.parse(s);
  expect(r.understood, isTrue, reason: s);
  expect(r.actions, hasLength(1), reason: s);
  return r.actions.single;
}

void main() {
  group('send message', () {
    final cases = {
      'Send Bala that bed 7 is stable': ('p:b', 'Bed 7 is stable'),
      'tell Dr Arjun, BP is 90/60 in bed 12': ('p:a', 'BP is 90/60 in bed 12'),
      'message arjun saying starting fluids now': ('p:a', 'Starting fluids now'),
      'tell Bala bed 7 is stable': ('p:b', 'Bed 7 is stable'),
      'please text @bala: call me': ('p:b', 'Call me'),
      'ask Arjun to review the ECG': ('p:a', 'Can you review the ECG?'),
      'tell ward 5 general that rounds start at 8': ('c:w', 'Rounds start at 8'),
      // Found on device: the comma belongs to the message, not the name.
      'tell Arjun bed 7 is stable, BP 120/80': ('p:a', 'Bed 7 is stable, BP 120/80'),
      'tell Bala the family said that he is fine': ('p:b', 'The family said that he is fine'),
      'message Bala Krishnan: K 3.1, repeat at 6': ('p:b', 'K 3.1, repeat at 6'),
    };
    cases.forEach((said, want) {
      test(said, () {
        final a = _one(said) as SendMessageAction;
        expect(a.to.id, want.$1);
        expect(a.text, want.$2);
      });
    });
  });

  test('a person beats the Needl chats named after them (found on device)', () {
    expect((_one('tell Arjun bed 7 is stable') as SendMessageAction).to.id, 'p:a');
    expect((_one('open chat with Bala') as OpenChatAction).to.id, 'p:b');
  });

  test('naming several members picks their Needl', () {
    expect((_one('tell Arjun and Bala, rounds at 8') as SendMessageAction).to.id, 'c:n');
  });

  test('same-name doctors → asks which one, offering both', () {
    final a = _one('tell Asha the echo is ready') as ClarifyAction;
    expect(a.choices.map((c) => c.id), containsAll(['p:1', 'p:2']));
  });

  test('speciality picks the right namesake', () {
    final a = _one('tell cardiology Asha, the echo is ready') as SendMessageAction;
    expect(a.to.id, 'p:1');
  });

  test('unknown person → clarification, never a guess', () {
    final a = _one('tell Rahul that bed 4 is stable') as ClarifyAction;
    expect(a.choices, isEmpty);
  });

  test('handoff with beds to a person', () {
    final a = _one('handoff beds 7 and 12 to Bala, night shift, watch potassium') as HandoffAction;
    expect(a.to.id, 'p:b');
    expect(a.patients.map((p) => p.bed), ['7', '12']);
    expect(a.shift, 'night');
  });

  test('handoff only goes to people, not chats', () {
    expect(_one('hand off bed 3 to ward 5 general'), isA<ClarifyAction>());
  });

  test('open chat / tabs / alerts / availability / search', () {
    expect((_one('open chat with Arjun') as OpenChatAction).to.id, 'p:a');
    expect((_one('open handoffs') as NavigateAction).tab, 'handoffs');
    expect((_one('show notifications') as NavigateAction).tab, 'alerts');
    expect(_one('mark all alerts as read'), isA<MarkAlertsReadAction>());
    expect((_one("I'm in OT") as SetAvailabilityAction).status, 'in_ot');
    expect((_one('set my status to on call') as SetAvailabilityAction).status, 'on_call');
    expect((_one('do not disturb') as SetAvailabilityAction).status, 'do_not_disturb');
    expect((_one('search for potassium') as SearchAction).query, 'potassium');
  });

  test('free-form requests are left to the AI half', () {
    expect(_parser.parse('what did Arjun say about bed 9 yesterday').understood, isFalse);
    expect(_parser.parse('').understood, isFalse);
  });

  test('server actions parse into the same types (hybrid)', () {
    final a = VoiceAction.fromJson({
      'type': 'send_message',
      'to': {'id': 'p:b', 'name': 'Dr Bala Krishnan', 'kind': 'person'},
      'text': 'Bed 7 stable',
    });
    expect(a, isA<SendMessageAction>());
    expect(VoiceAction.fromJson({'type': 'nope'}), isNull);
  });
}
