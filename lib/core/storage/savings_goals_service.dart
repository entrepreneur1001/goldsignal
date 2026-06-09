import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/models/savings_goal.dart';

class SavingsGoalsService {
  static const boxName = 'savingsGoals';

  Box get _box => Hive.box(boxName);

  List<SavingsGoal> getAll() {
    return _box.values
        .map((e) => SavingsGoal.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> save(SavingsGoal goal) async {
    await _box.put(goal.id, goal.toJson());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
