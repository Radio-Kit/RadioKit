/// Service for persisting sensitive data (device passwords) using
/// flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences on Android).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // ── Keys ────────────────────────────────────────────────────────────────
  // Key format:
  //   radiokit_pwd_<device_id>        — connection password (user mode)
  //   radiokit_admin_pwd_<device_id>  — admin password (admin mode)

  static String _pwdKey(String deviceId) => 'radiokit_pwd_$deviceId';
  // Admin password methods removed in v5 auth overhaul.
  // The user password (stored via savePassword) replaces the old admin password.

  // ── Connection password persistence ─────────────────────────────────────

  /// Save a device connection password to secure storage.
  static Future<bool> savePassword(String deviceId, String password) async {
    try {
      await _storage.write(key: _pwdKey(deviceId), value: password);
      return true;
    } catch (e) {
      debugPrint('SecureStorage: savePassword failed: $e');
      return false;
    }
  }

  /// Load a previously saved connection password for [deviceId], or null.
  static Future<String?> loadPassword(String deviceId) async {
    try {
      return await _storage.read(key: _pwdKey(deviceId));
    } catch (e) {
      debugPrint('SecureStorage: loadPassword failed: $e');
      return null;
    }
  }

  /// Delete a saved connection password for [deviceId].
  static Future<void> deletePassword(String deviceId) async {
    try {
      await _storage.delete(key: _pwdKey(deviceId));
    } catch (e) {
      debugPrint('SecureStorage: deletePassword failed: $e');
    }
  }

  /// Delete all stored passwords for [deviceId].
  static Future<void> deleteAllForDevice(String deviceId) async {
    await deletePassword(deviceId);
  }

  /// Delete all stored keys (e.g. on sign-out or data wipe).
  static Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('SecureStorage: deleteAll failed: $e');
    }
  }
}
