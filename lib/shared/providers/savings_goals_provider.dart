import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/savings_goals_service.dart';
import '../models/savings_goal.dart';

final savingsGoalsServiceProvider = Provider<SavingsGoalsService>((ref) {
  return SavingsGoalsService();
});

final savingsGoalsProvider =
    NotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(() {
  return SavingsGoalsNotifier();
});

class SavingsGoalsNotifier extends Notifier<List<SavingsGoal>> {
  SavingsGoalsService get _service => ref.read(savingsGoalsServiceProvider);

  @override
  List<SavingsGoal> build() => _service.getAll();

  Future<void> addGoal({
    required String metal,
    required double targetGrams,
    String? note,
  }) async {
    final goal = SavingsGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      metal: metal,
      targetGrams: targetGrams,
      createdAt: DateTime.now(),
      note: note,
    );
    await _service.save(goal);
    state = _service.getAll();
  }

  Future<void> deleteGoal(String id) async {
    await _service.delete(id);
    state = _service.getAll();
  }
}
