import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/core/api/metalpriceapi_service.dart';
import 'package:goldsignal/core/firebase/firestore_price_service.dart';
import 'package:goldsignal/features/charts/chart_span_label.dart';

void main() {
  group('select24hChange', () {
    const current = 102.0;
    const serverPrev = 100.0;
    final now = DateTime(2026, 7, 8, 12);

    test('uses in-window server baseline', () {
      final result = MetalPriceApiService.select24hChange(
        current: current,
        serverPrev: serverPrev,
        serverPrevAt: now.subtract(const Duration(hours: 24)),
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.changePercent, closeTo(2.0, 1e-9));
      expect(result.change, closeTo(2.0, 1e-9));
    });

    test('rejects 60h-old server baseline, uses history tier', () {
      final result = MetalPriceApiService.select24hChange(
        current: current,
        serverPrev: serverPrev,
        serverPrevAt: now.subtract(const Duration(hours: 60)),
        historyPercent: 1.5,
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.changePercent, 1.5);
    });

    test('returns null when all tiers invalid', () {
      final result = MetalPriceApiService.select24hChange(
        current: current,
        serverPrev: serverPrev,
        serverPrevAt: now.subtract(const Duration(hours: 60)),
        hivePrev: 100,
        hivePrevAt: now.subtract(const Duration(hours: 5)),
        now: now,
      );
      expect(result, isNull);
    });

    test('returns exact-zero history percent, not skipped', () {
      final result = MetalPriceApiService.select24hChange(
        current: current,
        historyPercent: 0,
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.changePercent, 0);
      expect(result.change, 0);
    });

    test('legacy docs without prevRatesAt accept server baseline', () {
      final result = MetalPriceApiService.select24hChange(
        current: current,
        serverPrev: serverPrev,
        serverPrevAt: null,
        now: now,
      );
      expect(result, isNotNull);
      expect(result!.changePercent, closeTo(2.0, 1e-9));
    });
  });

  group('MetalPricesResponse prevRatesAt', () {
    test('parses ISO prevRatesAt', () {
      final resp = MetalPricesResponse.fromJson({
        'rates': {'USDXAU': 2000.0},
        'prevRatesAt': '2026-07-07T12:00:00.000Z',
      });
      expect(resp.previousRatesAt, isNotNull);
      expect(resp.previousRatesAt!.toUtc().hour, 12);
    });

    test('tolerates absent prevRatesAt', () {
      final resp = MetalPricesResponse.fromJson({
        'rates': {'USDXAU': 2000.0},
      });
      expect(resp.previousRatesAt, isNull);
    });
  });

  group('formatChartChangeSpanLabel', () {
    test('20h maps to 24h', () {
      expect(formatChartChangeSpanLabel(const Duration(hours: 20)), '24h');
    });

    test('5d maps to 5d', () {
      expect(formatChartChangeSpanLabel(const Duration(days: 5)), '5d');
    });

    test('90d maps to 3mo', () {
      expect(formatChartChangeSpanLabel(const Duration(days: 90)), '3mo');
    });
  });

  group('local change derivation', () {
    test('derives absolute change from percent when field absent', () {
      final local = FirestorePriceService.localMarketPricesFromFirestore({
        'currency': 'EGP',
        'gold': {
          '24': {
            'sellPerGram': 100,
            'buyPerGram': 99,
            'changePercent': 2,
          },
        },
        'silver': {},
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 7, 8)),
      });
      expect(local.gold.first.change, closeTo(1.9608, 0.001));
    });
  });
}
