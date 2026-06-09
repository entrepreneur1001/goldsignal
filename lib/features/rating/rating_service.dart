import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_review/in_app_review.dart';

/// Records app ratings and, for 5-star ratings, requests the native store review.
class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppReview _inAppReview = InAppReview.instance;

  /// The user's current/latest rating (or null if they haven't rated yet).
  Future<Map<String, dynamic>?> loadMyRating() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _firestore.collection('ratings').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Saves the rating as the user's current rating (`ratings/{uid}`) and also
  /// appends an immutable history entry (`ratings/{uid}/versions/{autoId}`), so
  /// every version the user submits is kept. When [stars] == 5, also opens the
  /// store review flow.
  Future<void> submit({
    required int stars,
    String? feedback,
    required String appVersion,
    String iosAppStoreId = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final data = {
        'uid': uid,
        'stars': stars,
        'feedback': feedback ?? '',
        'appVersion': appVersion,
        'platform': Platform.operatingSystem,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final ratingRef = _firestore.collection('ratings').doc(uid);
      await ratingRef.set(data); // current rating
      await ratingRef.collection('versions').add(data); // history entry
    }

    if (stars >= 5) {
      await requestStoreReview(iosAppStoreId);
    }
  }

  Future<void> requestStoreReview(String iosAppStoreId) async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else if (iosAppStoreId.isNotEmpty) {
        await _inAppReview.openStoreListing(appStoreId: iosAppStoreId);
      }
    } catch (_) {
      // Store review is best-effort; never surface an error to the user.
    }
  }
}
