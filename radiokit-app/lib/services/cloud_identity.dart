import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages an Ed25519 identity for cloud relay authentication.
///
/// On first launch, generates a new Ed25519 keypair and stores the private key
/// in platform secure storage. The hex-encoded public key serves as the
/// "account" identifier that users set on their ESP32 devices.
///
/// On subsequent launches, restores the keypair from stored bytes.
class CloudIdentityService {
  static const privateKeyStoreKey = 'cloud_ed25519_private';
  static const publicKeyStoreKey = 'cloud_ed25519_public';

  final FlutterSecureStorage _storage;

  SimpleKeyPairData? _keyPairData;
  String? _account; // hex-encoded public key
  String? _privateKeyHex; // hex-encoded private key, cached for sync access

  /// Whether an identity has been loaded or generated.
  bool get hasIdentity => _keyPairData != null;

  /// The hex-encoded Ed25519 public key (64 hex chars = 32 bytes).
  /// This is the "account" identifier shown to the user and set on devices.
  String? get account => _account;

  /// The hex-encoded Ed25519 private key (64 hex chars = 32 bytes).
  /// Used when creating an Account entry for the accounts sheet.
  String? get privateKeyHex => _privateKeyHex;

  CloudIdentityService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Load existing identity from secure storage, or generate a new one.
  Future<void> initialize() async {
    final savedPrivateKey = await _storage.read(key: privateKeyStoreKey);
    if (savedPrivateKey != null) {
      await _loadFromStorage(savedPrivateKey);
    } else {
      await _generateNew();
    }
  }

  /// Generate a fresh Ed25519 keypair and persist to secure storage.
  Future<void> _generateNew() async {
    final ed25519 = Ed25519();
    final keyPair = await ed25519.newKeyPair();
    final keyPairData = await keyPair.extract();
    _keyPairData = keyPairData;

    final pubKeyBytes = keyPairData.publicKey.bytes;
    _account = bytesToHex(pubKeyBytes);

    // Persist both public and private key bytes
    final privKeyBytes = await keyPairData.extractPrivateKeyBytes();
    _privateKeyHex = bytesToHex(privKeyBytes);
    await _storage.write(
      key: privateKeyStoreKey,
      value: _privateKeyHex!,
    );
    await _storage.write(
      key: publicKeyStoreKey,
      value: _account!,
    );
  }

  /// Restore keypair from saved private key bytes.
  Future<void> _loadFromStorage(String privateKeyHex) async {
    final privateKeyBytes = hexToBytes(privateKeyHex);
    final publicKeyHex = await _storage.read(key: publicKeyStoreKey);

    final pubKeyBytes = publicKeyHex != null ? hexToBytes(publicKeyHex) : <int>[];
    final pubKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);

    _keyPairData = SimpleKeyPairData(
      privateKeyBytes,
      publicKey: pubKey,
      type: KeyPairType.ed25519,
    );
    _account = publicKeyHex;
    _privateKeyHex = privateKeyHex;
  }

  /// Sign `data` (e.g., a 32-byte nonce) with the Ed25519 private key.
  ///
  /// Returns the 64-byte signature bytes.
  Future<List<int>> sign(List<int> data) async {
    if (_keyPairData == null) {
      throw StateError('Cloud identity not initialized');
    }
    final ed25519 = Ed25519();
    final signature = await ed25519.sign(data, keyPair: _keyPairData!);
    return signature.bytes;
  }

  /// Import a pre-existing keypair from hex strings (for testing or migration).
  /// Sets the identity to the given keys and persists them to secure storage.
  Future<void> importKeyPair(String privateKeyHex, String publicKeyHex) async {
    final privateKeyBytes = hexToBytes(privateKeyHex);
    final publicKeyBytes = hexToBytes(publicKeyHex);
    final pubKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);

    _keyPairData = SimpleKeyPairData(
      privateKeyBytes,
      publicKey: pubKey,
      type: KeyPairType.ed25519,
    );
    _account = publicKeyHex;
    _privateKeyHex = privateKeyHex;

    // Persist to secure storage
    await _storage.write(
      key: privateKeyStoreKey,
      value: bytesToHex(privateKeyBytes),
    );
    await _storage.write(
      key: publicKeyStoreKey,
      value: publicKeyHex,
    );
  }

  /// Delete the stored identity (for testing / account reset).
  Future<void> deleteIdentity() async {
    await _storage.delete(key: privateKeyStoreKey);
    await _storage.delete(key: publicKeyStoreKey);
    _keyPairData = null;
    _account = null;
    _privateKeyHex = null;
  }

  // ── Hex helpers ───────────────────────────────────────────────────────

  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
