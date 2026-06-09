import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Submits user feature ideas to the `ideas` collection (admin-reviewed).
class IdeaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submit({
    required String idea,
    required String appVersion,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('ideas').add({
      'uid': uid,
      'idea': idea,
      'appVersion': appVersion,
      'platform': Platform.operatingSystem,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
