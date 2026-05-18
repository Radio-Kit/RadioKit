import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedDesign {
  final String id;
  final String name;
  final String jsonContent;
  final int timestamp;

  SavedDesign({
    required this.id,
    required this.name,
    required this.jsonContent,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'jsonContent': jsonContent,
        'timestamp': timestamp,
      };

  factory SavedDesign.fromJson(Map<String, dynamic> json) => SavedDesign(
        id: json['id'],
        name: json['name'],
        jsonContent: json['jsonContent'],
        timestamp: json['timestamp'],
      );
}

class DesignsProvider extends ChangeNotifier {
  static const _key = 'saved_designs';
  List<SavedDesign> _designs = [];

  List<SavedDesign> get designs => List.unmodifiable(_designs);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null) {
      final List decoded = jsonDecode(jsonStr);
      _designs = decoded.map((e) => SavedDesign.fromJson(e)).toList();
      _designs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    notifyListeners();
  }

  Future<void> saveDesign(String id, String name, String jsonContent) async {
    final index = _designs.indexWhere((d) => d.id == id);
    final newDesign = SavedDesign(
      id: id,
      name: name,
      jsonContent: jsonContent,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    if (index >= 0) {
      _designs[index] = newDesign;
    } else {
      _designs.insert(0, newDesign);
    }
    await _persist();
  }

  Future<void> deleteDesign(String id) async {
    _designs.removeWhere((d) => d.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_designs.map((d) => d.toJson()).toList());
    await prefs.setString(_key, jsonStr);
    notifyListeners();
  }
}
