import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';

class AccountProvider extends ChangeNotifier {
  static const _key = 'accounts';
  List<Account> _accounts = [];

  List<Account> get accounts => List.unmodifiable(_accounts);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      final List decoded = jsonDecode(jsonStr);
      _accounts = decoded.map((e) => Account.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _persist();
  }

  Future<void> updateAccount(String id, {String? name, String? relay}) async {
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _accounts[idx] = _accounts[idx].copyWith(name: name, relay: relay);
    await _persist();
  }

  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await prefs.setString(_key, jsonStr);
    notifyListeners();
  }
}
