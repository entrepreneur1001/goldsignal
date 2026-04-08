import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePriceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration staleDuration = Duration(minutes: 15);

  /// Read cached prices from Firestore. Returns null if missing or stale.
  Future<Map<String, dynamic>?> getCachedPrices(String currency) async {
    try {
      final doc = await _firestore.collection('prices').doc(currency).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null) return null;

      // Return null if data is older than 15 minutes
      if (DateTime.now().difference(updatedAt) > staleDuration) {
        return null;
      }

      return data['rates'] != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      print('FirestorePriceService.getCachedPrices error: $e');
      return null;
    }
  }

  /// Read cached prices regardless of staleness (for fallback when API is down).
  Future<Map<String, dynamic>?> getStalePrices(String currency) async {
    try {
      final doc = await _firestore.collection('prices').doc(currency).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return data['rates'] != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      return null;
    }
  }

  /// Write fresh API response to Firestore for all users to share.
  Future<void> cachePrices(String currency, Map<String, dynamic> apiResponse) async {
    try {
      await _firestore.collection('prices').doc(currency).set({
        'rates': apiResponse['rates'],
        'base': apiResponse['base'] ?? 'USD',
        'success': apiResponse['success'] ?? true,
        'apiTimestamp': apiResponse['timestamp'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('FirestorePriceService.cachePrices error: $e');
    }
  }

  /// Check if we can still call the API today (< 100 calls).
  /// Returns true if allowed, and atomically increments the counter.
  Future<bool> tryIncrementApiCallCount() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final docRef = _firestore.collection('metadata').doc('apiUsage');

    try {
      return await _firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists || snapshot.data()?['date'] != today) {
          // New day — reset counter
          transaction.set(docRef, {
            'date': today,
            'callCount': 1,
          });
          return true;
        }

        final currentCount = (snapshot.data()?['callCount'] ?? 0) as int;
        if (currentCount >= 100) {
          return false; // Quota exhausted
        }

        transaction.update(docRef, {
          'callCount': currentCount + 1,
        });
        return true;
      });
    } catch (e) {
      print('FirestorePriceService.tryIncrementApiCallCount error: $e');
      // On error, allow the call to avoid blocking users
      return true;
    }
  }

  /// Re-check if another user *just* refreshed Firestore (within 30 seconds)
  /// to avoid duplicate scraper/API calls from concurrent users.
  Future<Map<String, dynamic>?> checkAndLock(String currency) async {
    try {
      final doc = await _firestore.collection('prices').doc(currency).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null) return null;

      // Only use if another user refreshed within the last 30 seconds
      if (DateTime.now().difference(updatedAt).inSeconds <= 30) {
        return Map<String, dynamic>.from(data);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
