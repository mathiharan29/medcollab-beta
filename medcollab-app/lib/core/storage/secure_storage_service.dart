import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:medcollab_app/core/storage/storage_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted local storage for auth tokens and session data.
///
/// On mobile: [FlutterSecureStorage].
/// On web: [SharedPreferences] — `flutter_secure_storage` throws
/// `OperationError` when multiple keys are written (known web bug).
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;
  SharedPreferences? _prefs;

  static const _webSessionKey = 'medcollab_auth_session';

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveAccessToken(String token) async {
    if (kIsWeb) {
      await _updateWebSession({'accessToken': token});
      return;
    }
    await _safeWrite(StorageKeys.accessToken, token);
  }

  Future<String?> getAccessToken() async {
    if (kIsWeb) {
      return _readWebSessionValue('accessToken');
    }
    return _safeRead(StorageKeys.accessToken);
  }

  Future<void> saveRefreshToken(String token) async {
    if (kIsWeb) {
      await _updateWebSession({'refreshToken': token});
      return;
    }
    await _safeWrite(StorageKeys.refreshToken, token);
  }

  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      return _readWebSessionValue('refreshToken');
    }
    return _safeRead(StorageKeys.refreshToken);
  }

  Future<void> saveUserId(String userId) async {
    if (kIsWeb) {
      await _updateWebSession({'userId': userId});
      return;
    }
    await _safeWrite(StorageKeys.userId, userId);
  }

  Future<String?> getUserId() async {
    if (kIsWeb) {
      return _readWebSessionValue('userId');
    }
    return _safeRead(StorageKeys.userId);
  }

  Future<void> saveFcmToken(String token) async {
    if (kIsWeb) {
      final prefs = await _preferences;
      await prefs.setString(StorageKeys.fcmToken, token);
      return;
    }
    await _safeWrite(StorageKeys.fcmToken, token);
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb) {
      final prefs = await _preferences;
      return prefs.getString(StorageKeys.fcmToken);
    }
    return _safeRead(StorageKeys.fcmToken);
  }

  Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    if (kIsWeb) {
      final prefs = await _preferences;
      await prefs.setString(
        _webSessionKey,
        jsonEncode({
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'userId': userId,
        }),
      );
      return;
    }

    // Sequential writes — parallel secure-storage writes break on some platforms.
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
    await saveUserId(userId);
  }

  Future<void> clearSession() async {
    if (kIsWeb) {
      final prefs = await _preferences;
      await prefs.remove(_webSessionKey);
      await prefs.remove(StorageKeys.fcmToken);
      return;
    }

    await _safeDelete(StorageKeys.accessToken);
    await _safeDelete(StorageKeys.refreshToken);
    await _safeDelete(StorageKeys.userId);
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await _preferences;
      await prefs.clear();
      return;
    }
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Ignore corrupt secure-storage state on web/native.
    }
  }

  Future<Map<String, String>> _readWebSession() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_webSessionKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      await prefs.remove(_webSessionKey);
      return {};
    }
  }

  Future<String?> _readWebSessionValue(String key) async {
    final session = await _readWebSession();
    return session[key];
  }

  Future<void> _updateWebSession(Map<String, String> values) async {
    final session = await _readWebSession();
    session.addAll(values);
    final prefs = await _preferences;
    await prefs.setString(_webSessionKey, jsonEncode(session));
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      await clearAll();
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      await clearAll();
      return null;
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Ignore — key may already be unreadable.
    }
  }
}
