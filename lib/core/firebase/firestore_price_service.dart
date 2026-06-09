import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only access to the shared price cache in Firestore.
///
/// The `prices/*` documents are maintained exclusively by Cloud Functions
/// (see `refreshPricesScheduled`); clients only read them. Firestore rules
/// deny client writes to this collection.
class FirestorePriceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration staleDuration = Duration(minutes: 15);

  /// Read cached prices from Firestore. Returns null if missing or older than
  /// [maxAge] (defaults to [staleDuration]).
  Future<Map<String, dynamic>?> getCachedPrices(
    String currency, {
    Duration? maxAge,
  }) async {
    try {
      final doc = await _firestore.collection('prices').doc(currency).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null) return null;

      if (DateTime.now().difference(updatedAt) > (maxAge ?? staleDuration)) {
        return null;
      }

      return data['rates'] != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      print('FirestorePriceService.getCachedPrices error: $e');
      return null;
    }
  }

  /// Read cached prices regardless of staleness (for fallback when the
  /// scraper is down).
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
}
