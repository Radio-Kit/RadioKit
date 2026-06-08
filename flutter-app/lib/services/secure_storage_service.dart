/// Service for persisting sensitive data (device passwords) using
/// flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences on Android).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // ── Keys ────────────────────────────────────────────────────────────────
  // Key format: radiokit_pwd_<device_id>

  static String _pwdKey(String deviceId) => 'radiokit_pwd_$deviceId';

  // ── Password persistence ─────────────────────────────────────────────────

  /// Save a device password to secure storage. Returns true on success.
  static Future<bool> savePassword(String deviceId, String password) async {
    try {
      await _storage.write(key: _pwdKey(deviceId), value: password);
      return true;
    } catch (e) {
      debugPrint('SecureStorage: savePassword failed: $e');
      return false;
    }
  }

  /// Load a previously saved password for [deviceId], or null if none.
  static Future<String?> loadPassword(String deviceId) async {
    try {
      return await _storage.read(key: _pwdKey(deviceId));
    } catch (e) {
      debugPrint('SecureStorage: loadPassword failed: $e');
      return null;
    }
  }

  /// Delete a saved password for [deviceId].
  static Future<void> deletePassword(String deviceId) async {
    try {
      await _storage.delete(key: _pwdKey(deviceId));
    } catch (e) {
      debugPrint('SecureStorage: deletePassword failed: $e');
    }
  }

  /// Delete all stored passwords (e.g. on sign-out or data wipe).
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('SecureStorage: deleteAll failed: $e');
    }
  }
}
