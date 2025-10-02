import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FilterPrefs {
  static const _key = 'receipts_filters';

  static Future<Map<String, dynamic>?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return map;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Map<String, dynamic>? filters) async {
    final p = await SharedPreferences.getInstance();
    if (filters == null || filters.isEmpty) {
      await p.remove(_key);
      return;
    }
    await p.setString(_key, json.encode(filters));
  }
}

