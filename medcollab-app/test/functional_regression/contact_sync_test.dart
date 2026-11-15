// REQ 5: contact sync — which phone contacts are doctors on Vocle.
import 'package:flutter_test/flutter_test.dart';
import 'package:medcollab_app/features/contacts/contact_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/chat_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('permission denied: nothing is read or sent', () async {
    var read = false;
    var sent = false;
    final s = ContactSyncService(
      apiClient: isolatedApiClient(),
      requestPermission: () async => false,
      readPhoneBook: () async {
        read = true;
        return {};
      },
      match: (_) async {
        sent = true;
        return [];
      },
    );
    final r = await s.sync();
    expect(r.status, ContactSyncStatus.permissionDenied);
    expect(read, isFalse);
    expect(sent, isFalse);
    expect(await s.hasOptedIn, isFalse);
  });

  test('matches keep the phone-book name and are de-duplicated', () async {
    List<String>? sentPhones;
    final s = ContactSyncService(
      apiClient: isolatedApiClient(),
      requestPermission: () async => true,
      readPhoneBook: () async => {
        '+91 98765 43210': 'Vikram (ICU)',
        '09876543210': 'Vikram duplicate',
        '+919000000000': 'Not on Vocle',
      },
      match: (phones) async {
        sentPhones = phones;
        return [
          {
            'contactPhone': '+91 98765 43210',
            'user': {'_id': 'u2', 'name': 'Vikram Shah', 'displayTitle': 'Dr'},
            'canMessage': true,
          },
          {
            'contactPhone': '09876543210',
            'user': {'_id': 'u2', 'name': 'Vikram Shah'},
          },
        ];
      },
    );
    final r = await s.sync();
    expect(r.status, ContactSyncStatus.ok);
    expect(sentPhones, hasLength(3));
    expect(r.matches, hasLength(1));
    expect(r.matches.single.contactName, 'Vikram (ICU)');
    expect(r.matches.single.canMessage, isTrue);
    expect(s.lastMatches, hasLength(1));
    expect(await s.hasOptedIn, isTrue, reason: 'later opens refresh quietly');
  });

  test('big address books are sent in chunks of 3000', () async {
    final calls = <int>[];
    final book = {
      for (var i = 0; i < 7001; i++) '98${i.toString().padLeft(8, '0')}': 'C$i',
    };
    final s = ContactSyncService(
      apiClient: isolatedApiClient(),
      requestPermission: () async => true,
      readPhoneBook: () async => book,
      match: (phones) async {
        calls.add(phones.length);
        return [];
      },
    );
    await s.sync();
    expect(calls, [3000, 3000, 1001]);
  });

  test('network failure reports failed, not a crash', () async {
    final s = ContactSyncService(
      apiClient: isolatedApiClient(),
      requestPermission: () async => true,
      readPhoneBook: () async => {'9876543210': 'X'},
      match: (_) async => throw Exception('offline'),
    );
    expect((await s.sync()).status, ContactSyncStatus.failed);
  });
}
