import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/cloud_identity.dart';

/// Provider wrapper around [CloudIdentityService] for Ed25519 keypair management.
///
/// On first launch, generates a new keypair and persists to secure storage.
/// The hex-encoded public key serves as the "account" identifier for relay auth.
///
/// In debug mode, on the first launch EVER (no stored keys), imports a test
/// keypair so the app matches the ESP32 firmware's compile-time account out
/// of the box. Once a new identity is created via [resetIdentity], subsequent
/// launches use the stored identity without overwriting.
class CloudIdentityProvider extends ChangeNotifier {
  final CloudIdentityService _identity;
  final FlutterSecureStorage _storage;

  CloudIdentityProvider({FlutterSecureStorage? storage})
      : _identity = CloudIdentityService(storage: storage),
        _storage = storage ?? const FlutterSecureStorage();

  CloudIdentityService get identityService => _identity;

  /// The hex-encoded Ed25519 public key (64 hex chars).
  String? get account => _identity.account;
  bool get hasIdentity => _identity.hasIdentity;

  /// Load or generate the identity.
  ///
  /// On a fresh device (no stored keys), imports the test keypair in debug
  /// mode so the app matches the ESP32 firmware's compile-time account.
  /// If keys already exist in storage (e.g. after a [resetIdentity] that
  /// was persisted), loads them without overwriting.
  Future<void> initialize() async {
    // Check storage BEFORE calling initialize to distinguish "first launch
    // ever" from "stored identity present" — _identity.hasIdentity is always
    // false on a fresh service instance, so we can't use it to decide.
    final hasStoredKeys = await _storage.containsKey(key: CloudIdentityService.privateKeyStoreKey);

    await _identity.initialize();

    // Debug mode first-launch: import test keypair matching default firmware.
    // Don't overwrite if keys were already in storage (e.g. user created a
    // new identity via POST /api/cloud/account, then the app restarted).
    if (!hasStoredKeys && kDebugMode) {
      await _identity.importKeyPair(
        '6d6a8cca4b7f06d1f41e0bfdcc271fefa546ed7751bd22dea8fc378d8b20e85c',
        'c29abe914b26b6349a299db2e5b9b2755f73ec85df83e3361abe1b1914a85992',
      );
    }
    notifyListeners();
  }

  /// Sign data with the Ed25519 private key.
  Future<List<int>> sign(List<int> data) => _identity.sign(data);

  /// Regenerate a new keypair (resets account).
  /// Bypasses the debug-mode test keypair import to always produce
  /// a truly fresh Ed25519 keypair.
  Future<void> resetIdentity() async {
    await _identity.deleteIdentity();
    // Use CloudIdentityService.initialize() directly to generate a fresh
    // keypair, bypassing the debug-mode test keypair logic in our
    // own initialize() override.
    await _identity.initialize();
    notifyListeners();
  }
}
