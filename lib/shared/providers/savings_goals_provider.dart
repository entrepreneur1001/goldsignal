import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/firebase/firestore_savings_goals_service.dart';
import '../models/savings_goal.dart';

final firestoreSavingsGoalsServiceProvider =
    Provider<FirestoreSavingsGoalsService>((ref) {
  return FirestoreSavingsGoalsService();
});

final savingsGoalsProvider =
    NotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(() {
  return SavingsGoalsNotifier();
});

/// Stream-backed: Firestore is the source of truth (offline cache included).
/// Mutations write to Firestore; the live subscription updates [state].
class SavingsGoalsNotifier extends Notifier<List<SavingsGoal>> {
  StreamSubscription<List<SavingsGoal>>? _sub;

  FirestoreSavingsGoalsService get _cloud =>
      ref.read(firestoreSavingsGoalsServiceProvider);
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  List<SavingsGoal> build() {
    ref.onDispose(() => _sub?.cancel());
    _subscribe();
    return const [];
  }

  void _subscribe() {
    _sub?.cancel();
    final uid = _uid;
    if (uid == null) {
      state = const [];
      return;
    }
    _sub = _cloud.streamAll(uid).listen((goals) => state = goals);
  }

  Future<void> addGoal({
    required String metal,
    required double targetGrams,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final goal = SavingsGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      metal: metal,
      targetGrams: targetGrams,
      createdAt: DateTime.now(),
      note: note,
    );
    await _cloud.saveGoal(uid, goal);
    await AnalyticsService.instance
        .logEvent('savings_goal_created', parameters: {'metal': metal});
  }

  Future<void> deleteGoal(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _cloud.deleteGoal(uid, id);
  }
}
