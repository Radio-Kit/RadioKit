import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedDesign {
  final String id;
  final String name;
  final String? jsonContent; // null for file-mode entries
  final int timestamp;
  final String? filePath; // set for file-mode entries, null for Create mode
  final String? appVersion; // cached from appdata

  SavedDesign({
    required this.id,
    required this.name,
    required this.timestamp,
    this.jsonContent,
    this.filePath,
    this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (jsonContent != null) 'jsonContent': jsonContent,
        'timestamp': timestamp,
        if (filePath != null) 'filePath': filePath,
        if (appVersion != null) 'appVersion': appVersion,
      };

  factory SavedDesign.fromJson(Map<String, dynamic> json) => SavedDesign(
        id: json['id'],
        name: json['name'],
        jsonContent: json['jsonContent'] as String?,
        timestamp: json['timestamp'],
        filePath: json['filePath'] as String?,
        appVersion: json['appVersion'] as String?,
      );
}

class DesignsProvider extends ChangeNotifier {
  static const _key = 'saved_designs';
  List<SavedDesign> _designs = [];

  List<SavedDesign> get designs => List.unmodifiable(_designs);

  /// Returns only active designs (file-mode entries whose file still exists).
  List<SavedDesign> get activeDesigns {
    return _designs.where((d) {
      if (d.filePath != null) {
        return File(d.filePath!).existsSync();
      }
      return true;
    }).toList();
  }

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

  Future<void> saveDesign(
    String id,
    String name,
    String? jsonContent, {
    String? filePath,
    int? lastEdit,
    String? appVersion,
  }) async {
    final index = _designs.indexWhere((d) => d.id == id);
    final newDesign = SavedDesign(
      id: id,
      name: name,
      jsonContent: jsonContent,
      timestamp: lastEdit ?? DateTime.now().millisecondsSinceEpoch,
      filePath: filePath,
      appVersion: appVersion,
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

  Future<void> deleteAll() async {
    _designs.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_designs.map((d) => d.toJson()).toList());
    await prefs.setString(_key, jsonStr);
    notifyListeners();
  }
}
