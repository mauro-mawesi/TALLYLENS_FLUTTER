import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class ReceiptsCacheEntry {
  final DateTime timestamp;
  final List<dynamic> items;
  final int total; // opcional si backend lo envía
  const ReceiptsCacheEntry({required this.timestamp, required this.items, required this.total});

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'items': items,
        'total': total,
      };

  static ReceiptsCacheEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final ts = DateTime.tryParse((json['ts'] ?? '').toString());
    if (ts == null) return null;
    final items = (json['items'] as List?) ?? const [];
    final total = (json['total'] as int?) ?? items.length;
    return ReceiptsCacheEntry(timestamp: ts, items: items, total: total);
  }
}

class ReceiptsCache {
  static const _boxName = 'receipts_cache';
  static Box<String>? _box;

  static Future<void> _ensureBox() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  static Future<void> put(String key, ReceiptsCacheEntry entry) async {
    await _ensureBox();
    final payload = json.encode(entry.toJson());
    await _box!.put(key, payload);
  }

  static Future<ReceiptsCacheEntry?> get(String key, {Duration? ttl}) async {
    await _ensureBox();
    final raw = _box!.get(key);
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final entry = ReceiptsCacheEntry.fromJson(map);
      if (entry == null) return null;
      if (ttl != null) {
        final age = DateTime.now().difference(entry.timestamp);
        if (age > ttl) return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }

  /// Delete a specific cache entry by key
  static Future<void> delete(String key) async {
    await _ensureBox();
    await _box!.delete(key);
  }

  /// Clear all cached receipts
  static Future<void> clearAll() async {
    await _ensureBox();
    await _box!.clear();
  }

  /// Get all cache keys (useful for debugging)
  static Future<List<String>> getAllKeys() async {
    await _ensureBox();
    return _box!.keys.cast<String>().toList();
  }
}

