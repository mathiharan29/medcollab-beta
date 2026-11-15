import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:medcollab_app/core/constants/api_endpoints.dart';
import 'package:medcollab_app/core/network/api_client.dart';
import 'package:medcollab_app/features/auth/data/models/user_model.dart';
import 'package:medcollab_app/features/messages/data/models/user_lookup_result.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One phone contact who is on Vocle.
class ContactMatch {
  const ContactMatch({
    required this.user,
    required this.contactName,
    this.canMessage = false,
    this.pendingRequest,
  });

  final UserModel user;

  /// Name saved in the phone's address book (may differ from Vocle name).
  final String contactName;
  final bool canMessage;
  final PendingRequestHint? pendingRequest;
}

enum ContactSyncStatus { ok, permissionDenied, failed }

class ContactSyncResult {
  const ContactSyncResult(this.status, [this.matches = const []]);
  final ContactSyncStatus status;
  final List<ContactMatch> matches;
}

/// Reads the device's contacts → which are doctors on Vocle (REQ 5).
///
/// Only phone numbers are sent, over HTTPS, and the server does not store
/// them. Contacts are read only after the doctor opts in.
class ContactSyncService {
  ContactSyncService({
    required ApiClient apiClient,
    Future<Map<String, String>> Function()? readPhoneBook,
    Future<bool> Function()? requestPermission,
    Future<List<Map<String, dynamic>>> Function(List<String> phones)? match,
  })  : _api = apiClient,
        _readPhoneBook = readPhoneBook ?? _devicePhoneBook,
        _requestPermission = requestPermission ??
            (() => FlutterContacts.requestPermission(readonly: true)),
        _match = match;

  final ApiClient _api;
  final Future<Map<String, String>> Function() _readPhoneBook;
  final Future<bool> Function() _requestPermission;
  final Future<List<Map<String, dynamic>>> Function(List<String>)? _match;

  Future<List<Map<String, dynamic>>> _postMatches(List<String> phones) async {
    if (_match != null) return _match(phones);
    final res = await _api.post<List<Map<String, dynamic>>>(
      ApiEndpoints.matchContacts,
      data: {'phones': phones},
      parser: (json) {
        final raw = json['matches'];
        if (raw is! List) return const [];
        return raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  static const _optInKey = 'contacts_sync_opt_in_v1';
  static const chunkSize = 3000;

  List<ContactMatch>? _last;
  List<ContactMatch>? get lastMatches => _last;

  Future<bool> get hasOptedIn async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_optInKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Phone number → contact name, for every number in the address book.
  static Future<Map<String, String>> _devicePhoneBook() async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final book = <String, String>{};
    for (final c in contacts) {
      final name = c.displayName.trim();
      for (final p in c.phones) {
        final number = p.normalizedNumber.isNotEmpty ? p.normalizedNumber : p.number;
        if (number.replaceAll(RegExp(r'\D'), '').length >= 10) {
          book.putIfAbsent(number, () => name);
        }
      }
    }
    return book;
  }

  static String _last10(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<ContactSyncResult> sync() async {
    final granted = await _requestPermission();
    if (!granted) return const ContactSyncResult(ContactSyncStatus.permissionDenied);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_optInKey, true);
    } catch (_) {}

    try {
      final book = await _readPhoneBook();
      final nameByLast10 = <String, String>{};
      book.forEach((number, name) {
        nameByLast10.putIfAbsent(_last10(number), () => name);
      });
      final numbers = book.keys.toList();
      final matches = <String, ContactMatch>{};
      for (var i = 0; i < numbers.length; i += chunkSize) {
        final chunk = numbers.sublist(
          i,
          i + chunkSize > numbers.length ? numbers.length : i + chunkSize,
        );
        for (final map in await _postMatches(chunk)) {
          final user = UserModel.fromJson(
            Map<String, dynamic>.from(map['user'] as Map),
          );
          final phone = map['contactPhone'] as String? ?? '';
          final pending = map['pendingRequest'];
          matches.putIfAbsent(
            user.id,
            () => ContactMatch(
              user: user,
              contactName: nameByLast10[_last10(phone)] ?? user.displayName,
              canMessage: map['canMessage'] == true,
              pendingRequest: pending is Map
                  ? PendingRequestHint.fromJson(
                      Map<String, dynamic>.from(pending),
                    )
                  : null,
            ),
          );
        }
      }
      final list = matches.values.toList()
        ..sort((a, b) => a.contactName.toLowerCase().compareTo(
              b.contactName.toLowerCase(),
            ));
      _last = list;
      return ContactSyncResult(ContactSyncStatus.ok, list);
    } catch (_) {
      return const ContactSyncResult(ContactSyncStatus.failed);
    }
  }
}
