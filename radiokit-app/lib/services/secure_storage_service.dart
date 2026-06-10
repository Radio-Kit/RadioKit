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
  static String _adminPwdKey(String deviceId) => 'radiokit_admin_pwd_$deviceId';

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

  // ── Admin password persistence ──────────────────────────────────────────

  /// Save an admin password to secure storage.
  static Future<bool> saveAdminPassword(String deviceId, String password) async {
    try {
      await _storage.write(key: _adminPwdKey(deviceId), value: password);
      return true;
    } catch (e) {
      debugPrint('SecureStorage: saveAdminPassword failed: $e');
      return false;
    }
  }

  /// Load a previously saved admin password for [deviceId], or null.
  static Future<String?> loadAdminPassword(String deviceId) async {
    try {
      return await _storage.read(key: _adminPwdKey(deviceId));
    } catch (e) {
      debugPrint('SecureStorage: loadAdminPassword failed: $e');
      return null;
    }
  }

  /// Delete a saved admin password for [deviceId].
  static Future<void> deleteAdminPassword(String deviceId) async {
    try {
      await _storage.delete(key: _adminPwdKey(deviceId));
    } catch (e) {
      debugPrint('SecureStorage: deleteAdminPassword failed: $e');
    }
  }

  /// Delete all stored passwords for [deviceId] (both connection and admin).
  static Future<void> deleteAllForDevice(String deviceId) async {
    await deletePassword(deviceId);
    await deleteAdminPassword(deviceId);
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
