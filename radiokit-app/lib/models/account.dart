import 'dart:math';

class Account {
  final String id;
  final String name;
  final String publicKey;
  final String privateKey;
  final String relay;

  Account({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.privateKey,
    this.relay = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'publicKey': publicKey,
    'privateKey': privateKey,
    'relay': relay,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    publicKey: json['publicKey'] as String,
    privateKey: json['privateKey'] as String,
    relay: json['relay'] as String? ?? '',
  );

  Account copyWith({
    String? name,
    String? relay,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      publicKey: publicKey,
      privateKey: privateKey,
      relay: relay ?? this.relay,
    );
  }

  /// Generate a new account with random key pair.
  static Account generate({String name = 'Account'}) {
    final random = Random.secure();
    final privateKey = List<int>.generate(32, (_) => random.nextInt(256));
    final publicKey = List<int>.generate(32, (_) => random.nextInt(256));

    return Account(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: name,
      privateKey: privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      publicKey: publicKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }
}
