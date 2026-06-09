import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/price_alert.dart';

class PriceAlertsService {
  static const boxName = 'userAlerts';

  Box get _box => Hive.box(boxName);

  List<PriceAlert> getAll() {
    return _box.values
        .map((e) => PriceAlert.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PriceAlert> getActive() =>
      getAll().where((a) => a.isActive).toList();

  int get activeCount => getActive().length;

  Future<void> save(PriceAlert alert) async {
    await _box.put(alert.id, alert.toJson());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> update(PriceAlert alert) async {
    await save(alert);
  }

  Future<void> replaceAll(List<PriceAlert> alerts) async {
    await _box.clear();
    for (final alert in alerts) {
      await save(alert);
    }
  }
}
