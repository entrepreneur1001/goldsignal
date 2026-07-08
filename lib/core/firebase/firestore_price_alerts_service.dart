import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/price_alert.dart';

class FirestorePriceAlertsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _alertsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('alerts');

  Future<void> saveAlert(String uid, PriceAlert alert) async {
    await _alertsRef(uid).doc(alert.id).set({
      ...alert.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAlert(String uid, String id) async {
    await _alertsRef(uid).doc(id).delete();
  }

  Future<List<PriceAlert>> loadAll(String uid) async {
    final snapshot = await _alertsRef(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      return PriceAlert.fromJson(data);
    }).toList();
  }

  /// Live stream of the user's alerts (Firestore is the source of truth; served
  /// from the offline cache when offline).
  Stream<List<PriceAlert>> streamAll(String uid) {
    return _alertsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PriceAlert.fromJson(Map<String, dynamic>.from(doc.data())))
            .toList());
  }

  Future<void> syncLocalToCloud(String uid, List<PriceAlert> local) async {
    final batch = _firestore.batch();
    for (final alert in local) {
      batch.set(_alertsRef(uid).doc(alert.id), {
        ...alert.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> saveFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': {token: DateTime.now().toUtc().toIso8601String()},
      'fcmToken': token,
      'fcmUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persist the user's daily-digest preferences for the scheduled Cloud
  /// Function to read. Merges so the function's `lastSentYmd` is preserved.
  Future<void> saveDigestPrefs(String uid, Map<String, dynamic> prefs) async {
    await _firestore.collection('users').doc(uid).set({
      'digest': prefs,
    }, SetOptions(merge: true));
  }
}
