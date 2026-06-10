import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/chat_conversation.dart';

/// Cloud backup for AI chat history under `users/{uid}/chatHistory`. Mirrors
/// [FirestorePriceAlertsService]; nested message maps are Firestore-compatible.
class FirestoreChatHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _chatRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('chatHistory');

  Future<void> saveConversation(String uid, ChatConversation conversation) async {
    await _chatRef(uid).doc(conversation.id).set({
      ...conversation.toJson(),
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteConversation(String uid, String id) async {
    await _chatRef(uid).doc(id).delete();
  }

  Future<List<ChatConversation>> loadAll(String uid) async {
    final snapshot = await _chatRef(uid).orderBy('updatedAt', descending: true).get();
    return snapshot.docs
        .map((doc) =>
            ChatConversation.fromJson(Map<String, dynamic>.from(doc.data())))
        .toList();
  }

  Stream<List<ChatConversation>> streamAll(String uid) {
    return _chatRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                ChatConversation.fromJson(Map<String, dynamic>.from(doc.data())))
            .toList());
  }

  Future<void> syncLocalToCloud(String uid, List<ChatConversation> local) async {
    final batch = _firestore.batch();
    for (final conversation in local) {
      batch.set(_chatRef(uid).doc(conversation.id), {
        ...conversation.toJson(),
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
