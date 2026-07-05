import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/local_market_prices.dart';

/// Read-only access to the shared price cache in Firestore.
///
/// The `prices/*` documents are maintained exclusively by Cloud Functions
/// (see `refreshPricesScheduled`); clients only read them. Firestore rules
/// deny client writes to this collection.
class FirestorePriceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Duration staleDuration = Duration(minutes: 30);

  /// Local EGP/INR markets refresh at most once per hour server-side.
  static const Duration localStaleDuration = Duration(minutes: 65);

  static const _localDocIds = {'EGP': 'local_EGP', 'INR': 'local_INR'};

  /// Read cached global prices from `prices/latest`. Returns null if missing
  /// or older than [maxAge] (defaults to [staleDuration]).
  Future<Map<String, dynamic>?> getCachedPrices(
    String docId, {
    Duration? maxAge,
  }) async {
    try {
      final data = await _readDocIfFresh(docId, maxAge ?? staleDuration);
      if (data == null || data['rates'] == null) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('FirestorePriceService.getCachedPrices error: $e');
      return null;
    }
  }

  /// Read cached local market prices from `prices/local_EGP` or
  /// `prices/local_INR`. Returns null if missing or stale.
  Future<LocalMarketPrices?> getCachedLocalMarketPrices(
    String currency, {
    Duration? maxAge,
  }) async {
    try {
      final docId = _localDocIds[currency];
      if (docId == null) return null;

      final data = await _readDocIfFresh(docId, maxAge ?? localStaleDuration);
      if (data == null) return null;
      return localMarketPricesFromFirestore(data);
    } catch (e) {
      debugPrint('FirestorePriceService.getCachedLocalMarketPrices error: $e');
      return null;
    }
  }

  /// Read cached prices regardless of staleness (for fallback when the
  /// scraper is down).
  Future<Map<String, dynamic>?> getStalePrices(String docId) async {
    try {
      final doc = await _firestore.collection('prices').doc(docId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return data['rates'] != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      return null;
    }
  }

  /// Read local market prices regardless of staleness.
  Future<LocalMarketPrices?> getStaleLocalMarketPrices(String currency) async {
    try {
      final docId = _localDocIds[currency];
      if (docId == null) return null;

      final doc = await _firestore.collection('prices').doc(docId).get();
      if (!doc.exists) return null;
      return localMarketPricesFromFirestore(doc.data()!);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readDocIfFresh(
    String docId,
    Duration maxAge,
  ) async {
    final doc = await _firestore.collection('prices').doc(docId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt == null) return null;

    if (DateTime.now().difference(updatedAt) > maxAge) return null;
    return data;
  }

  /// Converts a Firestore `prices/local_*` document to [LocalMarketPrices].
  static LocalMarketPrices localMarketPricesFromFirestore(
    Map<String, dynamic> data,
  ) {
    final currency = data['currency'] as String? ?? 'EGP';
    final country = currency == 'INR' ? 'IN' : 'EG';

    return LocalMarketPrices(
      country: country,
      currency: currency,
      source: data['source'] as String? ?? 'cloud_function',
      gold: _karatMapToList(data['gold']),
      silver: _karatMapToList(data['silver']),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static List<LocalKaratPrice> _karatMapToList(dynamic raw) {
    if (raw is! Map) return [];
    return raw.entries.map((entry) {
      final karat = entry.key as String;
      final row = Map<String, dynamic>.from(entry.value as Map);
      return LocalKaratPrice(
        karat: karat,
        sellPerGram: (row['sellPerGram'] as num).toDouble(),
        buyPerGram: (row['buyPerGram'] as num).toDouble(),
        changePercent: (row['changePercent'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }
}
