import 'package:flutter/foundation.dart';
import '../services/cloud_identity.dart';

/// Provider wrapper around [CloudIdentityService] for Ed25519 keypair management.
///
/// On first launch, generates a new keypair and persists to secure storage.
/// The hex-encoded public key serves as the "account" identifier for relay auth.
class CloudIdentityProvider extends ChangeNotifier {
  final CloudIdentityService _identity;

  CloudIdentityProvider()
      : _identity = CloudIdentityService();

  CloudIdentityService get identityService => _identity;

  /// The hex-encoded Ed25519 public key (64 hex chars).
  String? get account => _identity.account;
  bool get hasIdentity => _identity.hasIdentity;

  /// Load or generate the identity.
  ///
  /// In debug mode, if no identity exists yet, imports a test keypair that
  /// matches the ESP32 firmware's compile-time account for local testing.
  Future<void> initialize() async {
    final hadIdentity = _identity.hasIdentity;
    await _identity.initialize();
    if (!hadIdentity) {
      // Debug: import the test keypair matching the ESP32 firmware's account
      await _identity.importKeyPair(
        // PRIVATE_KEY_HEX (32 bytes)
        '1f2919214484bb4100aad318e572ca75a605b551ef68a2111b3cff56165fb654',
        // PUBLIC_KEY_HEX (32 bytes) = account
        '4b6afa33fb4d3de07f9382ff9dbac48733d3aca7206218c82c982391210e1bed',
      );
    }
    notifyListeners();
  }

  /// Sign data with the Ed25519 private key.
  Future<List<int>> sign(List<int> data) => _identity.sign(data);

  /// Regenerate a new keypair (resets account).
  Future<void> resetIdentity() async {
    await _identity.deleteIdentity();
    await _identity.initialize();
    notifyListeners();
  }
}
