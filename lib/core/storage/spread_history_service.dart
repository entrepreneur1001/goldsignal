import 'package:hive_flutter/hive_flutter.dart';

class SpreadPoint {
  final DateTime timestamp;
  final double spread;

  const SpreadPoint({required this.timestamp, required this.spread});
}

/// Records daily 21K gold buy-sell spread (EGP) for the spread dashboard.
class SpreadHistoryService {
  SpreadHistoryService._();
  static final SpreadHistoryService instance = SpreadHistoryService._();

  static const boxName = 'spreadHistory';
  static const _maxPoints = 90;

  Future<Box> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return Hive.openBox(boxName);
  }

  Future<void> record(double spread, DateTime ts) async {
    final box = await _box();
    final key = _ymd(ts);
    final lastKey = box.get('_lastKey') as String?;
    if (lastKey == key) {
      // Update today's point if spread changed materially.
      final existing = (box.get(key) as num?)?.toDouble();
      if (existing != null && (existing - spread).abs() < 0.01) return;
    }
    await box.put(key, spread);
    await box.put('_lastKey', key);
    await _prune(box);
  }

  Future<List<SpreadPoint>> last7Days() async {
    final box = await _box();
    final now = DateTime.now();
    final points = <SpreadPoint>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final v = box.get(_ymd(day));
      if (v is num) {
        points.add(SpreadPoint(timestamp: day, spread: v.toDouble()));
      }
    }
    return points;
  }

  Future<void> _prune(Box box) async {
    final keys = box.keys
        .where((k) => k is String && k != '_lastKey')
        .cast<String>()
        .toList()
      ..sort();
    while (keys.length > _maxPoints) {
      await box.delete(keys.removeAt(0));
    }
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
