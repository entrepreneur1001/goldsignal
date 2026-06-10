import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/savings_goal.dart';

/// Cloud backup for savings goals under `users/{uid}/savingsGoals`. Mirrors
/// [FirestorePriceAlertsService] so goals survive sign-out and restore on the
/// user's next login.
class FirestoreSavingsGoalsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _goalsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('savingsGoals');

  Future<void> saveGoal(String uid, SavingsGoal goal) async {
    await _goalsRef(uid).doc(goal.id).set({
      ...goal.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGoal(String uid, String id) async {
    await _goalsRef(uid).doc(id).delete();
  }

  Future<List<SavingsGoal>> loadAll(String uid) async {
    final snapshot = await _goalsRef(uid).orderBy('createdAt').get();
    return snapshot.docs
        .map((doc) => SavingsGoal.fromJson(Map<String, dynamic>.from(doc.data())))
        .toList();
  }

  Stream<List<SavingsGoal>> streamAll(String uid) {
    return _goalsRef(uid).orderBy('createdAt').snapshots().map((snap) => snap.docs
        .map((doc) => SavingsGoal.fromJson(Map<String, dynamic>.from(doc.data())))
        .toList());
  }

  Future<void> syncLocalToCloud(String uid, List<SavingsGoal> local) async {
    final batch = _firestore.batch();
    for (final goal in local) {
      batch.set(_goalsRef(uid).doc(goal.id), {
        ...goal.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
