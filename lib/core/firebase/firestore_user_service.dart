import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes lightweight activity metadata to the user's Firestore doc.
///
/// `lastActiveAt` is the activity signal the scheduled re-engagement Cloud
/// Function reads to decide whether a user has lapsed. All writes merge into
/// `users/{uid}` so they sit alongside `fcmToken`/`digest`/`reengage` without
/// clobbering them.
class FirestoreUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record that the signed-in user (anonymous or linked) just used the app.
  /// Callers should throttle this — the lifecycle tracker writes at most once
  /// per hour so a foreground bounce doesn't spam Firestore.
  Future<void> recordActivity(
    String uid, {
    required String appVersion,
    required String locale,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'platform': Platform.isIOS ? 'ios' : 'android',
      'appVersion': appVersion,
      'locale': locale,
    }, SetOptions(merge: true));
  }

  /// Persist the user's re-engagement opt-out preference for the Cloud Function
  /// to honor. Merges so server-written `reengage.lastSentAt`/`lastTier` and the
  /// rest of the user doc are preserved.
  Future<void> setReengageEnabled(String uid, bool enabled) async {
    await _firestore.collection('users').doc(uid).set({
      'reengage': {'enabled': enabled},
    }, SetOptions(merge: true));
  }
}
