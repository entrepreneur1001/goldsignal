import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/local_market_prices.dart';
import '../../shared/models/price_snapshot.dart';
import '../api/metalpriceapi_service.dart';
import '../crash/crash_reporter.dart';

class FirestorePriceHistoryService {
  static const _collection = 'priceHistory';
  static const _ounceToGram = 31.1034768;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _hourBucket(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h';
  }

  DateTime _parseHourBucket(String bucket) {
    final parts = bucket.split('T');
    final dateParts = parts[0].split('-');
    return DateTime.utc(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(parts[1]),
    );
  }

  String _docId(String marketType, String currency, String hourBucket) =>
      '${marketType}_${currency}_$hourBucket';

  String _prefsKey(String marketType, String currency) =>
      'lastFirestoreHistory_${marketType}_$currency';

  Future<bool> _shouldUpload(String marketType, String currency) async {
    if (FirebaseAuth.instance.currentUser == null) return false;

    final bucket = _hourBucket(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final lastBucket = prefs.getString(_prefsKey(marketType, currency));
    return lastBucket != bucket;
  }

  Future<void> _markUploaded(String marketType, String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey(marketType, currency),
      _hourBucket(DateTime.now()),
    );
  }

  Future<void> _createHourlyDoc({
    required String marketType,
    required String currency,
    required String source,
    required Map<String, dynamic> gold,
    required Map<String, dynamic> silver,
    Map<String, double>? spotPerOunce,
  }) async {
    if (!await _shouldUpload(marketType, currency)) return;

    final hourBucket = _hourBucket(DateTime.now());
    final docId = _docId(marketType, currency, hourBucket);
    final docRef = _firestore.collection(_collection).doc(docId);

    final data = <String, dynamic>{
      'marketType': marketType,
      'currency': currency,
      'source': source,
      'hourBucket': hourBucket,
      'recordedAt': FieldValue.serverTimestamp(),
      'gold': gold,
      'silver': silver,
    };
    if (spotPerOunce != null && spotPerOunce.isNotEmpty) {
      data['spotPerOunce'] = spotPerOunce;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(docRef);
        if (existing.exists) return;
        transaction.set(docRef, data);
      });
      await _markUploaded(marketType, currency);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'priceHistory hourly upload failed');
    }
  }

  Future<void> tryRecordHourlyLocal(LocalMarketPrices local) async {
    final gold = <String, dynamic>{};
    for (final row in local.gold) {
      if (row.isPerUnit) continue;
      gold[row.karat] = {
        'sellPerGram': row.sellPerGram,
        'buyPerGram': row.buyPerGram,
      };
    }

    final silver = <String, dynamic>{};
    for (final row in local.silver) {
      if (row.isPerUnit || row.karat == 'silver_ounce') continue;
      silver[row.karat] = {
        'sellPerGram': row.sellPerGram,
        'buyPerGram': row.buyPerGram,
      };
    }

    if (gold.isEmpty && silver.isEmpty) return;

    await _createHourlyDoc(
      marketType: 'local',
      currency: 'EGP',
      source: 'isagha',
      gold: gold,
      silver: silver,
    );
  }

  Future<void> tryRecordHourlyGlobal(
    MetalPricesResponse response,
    String currency,
  ) async {
    final goldOunce = response.goldPriceIn(currency);
    final silverOunce = response.silverPriceIn(currency);

    final gold = <String, dynamic>{};
    if (goldOunce != null) {
      final perGram24 = goldOunce / _ounceToGram;
      for (final karat in ['24', '22', '21', '18']) {
        final purity = int.parse(karat) / 24;
        gold[karat] = {'sellPerGram': perGram24 * purity};
      }
    }

    final silver = <String, dynamic>{};
    if (silverOunce != null) {
      silver['999'] = {'sellPerGram': silverOunce / _ounceToGram};
    }

    if (gold.isEmpty && silver.isEmpty) return;

    final spot = <String, double>{};
    if (goldOunce != null) spot['gold'] = goldOunce;
    if (silverOunce != null) spot['silver'] = silverOunce;

    await _createHourlyDoc(
      marketType: 'global',
      currency: currency,
      source: 'livepriceofgold',
      gold: gold,
      silver: silver,
      spotPerOunce: spot.isEmpty ? null : spot,
    );
  }

  Future<List<ChartDataPoint>> getChartPoints({
    required String currency,
    required String metal,
    required String karat,
    required ChartRange range,
    required PriceSide side,
  }) async {
    if (FirebaseAuth.instance.currentUser == null) return [];

    final marketType = currency == 'EGP' ? 'local' : 'global';
    final startBucket = _hourBucket(
      DateTime.now().subtract(Duration(days: range.days)),
    );
    final endBucket = _hourBucket(DateTime.now());

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('marketType', isEqualTo: marketType)
          .where('currency', isEqualTo: currency)
          .where('hourBucket', isGreaterThanOrEqualTo: startBucket)
          .where('hourBucket', isLessThanOrEqualTo: endBucket)
          .orderBy('hourBucket')
          .get();

      final points = <ChartDataPoint>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final value = _extractValue(data, metal: metal, karat: karat, side: side);
        if (value == null) continue;

        final bucket = data['hourBucket'] as String?;
        if (bucket == null) continue;

        points.add(ChartDataPoint(
          date: _parseHourBucket(bucket),
          value: value,
        ));
      }

      return points;
    } catch (_) {
      return [];
    }
  }

  double? _extractValue(
    Map<String, dynamic> data, {
    required String metal,
    required String karat,
    required PriceSide side,
  }) {
    final metalMap = (data[metal] as Map<String, dynamic>?) ?? {};
    final karatData = metalMap[karat] as Map<String, dynamic>?;
    if (karatData == null) return null;

    final sell = (karatData['sellPerGram'] as num?)?.toDouble();
    final buy = (karatData['buyPerGram'] as num?)?.toDouble();

    if (side == PriceSide.buy && buy != null) return buy;
    if (sell != null) return sell;
    return buy;
  }
}
