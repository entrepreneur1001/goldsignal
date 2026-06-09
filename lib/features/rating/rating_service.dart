import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_review/in_app_review.dart';

/// Records app ratings and, for 5-star ratings, requests the native store review.
class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InAppReview _inAppReview = InAppReview.instance;

  /// Saves the rating to `ratings/{uid}` and, when [stars] == 5, opens the
  /// store review flow. Ratings below 5 are kept in Firebase only.
  Future<void> submit({
    required int stars,
    String? feedback,
    required String appVersion,
    String iosAppStoreId = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('ratings').doc(uid).set({
        'uid': uid,
        'stars': stars,
        'feedback': feedback ?? '',
        'appVersion': appVersion,
        'platform': Platform.operatingSystem,
        'createdAt': FieldValue.serverTimestamp(),
      });
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
