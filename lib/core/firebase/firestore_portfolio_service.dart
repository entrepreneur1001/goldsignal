import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePortfolioService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _portfolioRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('portfolio');

  /// Save a portfolio item. If [docId] is provided, updates that doc; otherwise creates a new one.
  /// Returns the Firestore document ID.
  Future<String> saveItem(String uid, Map<String, dynamic> data, {String? docId}) async {
    if (docId != null) {
      await _portfolioRef(uid).doc(docId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docId;
    } else {
      final docRef = await _portfolioRef(uid).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    }
  }

  /// Delete a portfolio item by Firestore doc ID.
  Future<void> deleteItem(String uid, String docId) async {
    await _portfolioRef(uid).doc(docId).delete();
  }

  /// Load all portfolio items for a user.
  Future<List<Map<String, dynamic>>> loadAll(String uid) async {
    final snapshot = await _portfolioRef(uid).orderBy('createdAt').get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      data['firestoreId'] = doc.id;
      return data;
    }).toList();
  }

  /// Sync local items to Firestore (used after guest→registered conversion).
  /// Returns a list of Firestore doc IDs in the same order as input items.
  Future<List<String>> syncFromLocal(String uid, List<Map<String, dynamic>> items) async {
    final batch = _firestore.batch();
    final docIds = <String>[];

    for (final item in items) {
      final docRef = _portfolioRef(uid).doc();
      batch.set(docRef, {
        ...item,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      docIds.add(docRef.id);
    }

    await batch.commit();
    return docIds;
  }
}
