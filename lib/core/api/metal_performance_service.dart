import 'package:dio/dio.dart';

import '../../shared/models/metal_performance.dart';

/// Fetches multi-period gold/silver performance from goldprice.org.
class MetalPerformanceService {
  static const _baseUrl =
      'https://goldprice.org/performance-json';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36';

  final Dio _dio;

  MetalPerformanceService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'User-Agent': _userAgent,
                'Accept': '*/*',
                'Referer': 'https://goldprice.org/',
              },
            ));

  /// Loads gold and silver performance for [currency] in parallel.
  /// If one metal fails, the other is still returned.
  Future<MetalPerformanceData> fetch(String currency) async {
    final code = currency.toUpperCase();
    final results = await Future.wait([
      _fetchMetal('gold', code),
      _fetchMetal('silver', code),
    ]);
    return MetalPerformanceData(
      currency: code,
      gold: results[0],
      silver: results[1],
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<MetalPerformancePeriod>> _fetchMetal(
    String metal,
    String currency,
  ) async {
    try {
      final url = '$_baseUrl/$metal-price-performance-$currency.json';
      final response = await _dio.get<dynamic>(url);
      final data = response.data;
      if (data is! Map) return const [];
      return _parseChange(data['Change']);
    } catch (_) {
      return const [];
    }
  }

  List<MetalPerformancePeriod> _parseChange(dynamic raw) {
    if (raw is! List) return const [];
    final periods = <MetalPerformancePeriod>[];
    for (final item in raw) {
      if (item is! Map) continue;
      if (item.isEmpty) continue;
      final entry = item.entries.first;
      final label = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;
      final amount = value['amount']?.toString() ?? '';
      final percentage = value['percentage']?.toString() ?? '';
      if (amount.isEmpty && percentage.isEmpty) continue;
      periods.add(MetalPerformancePeriod(
        label: label,
        amount: amount,
        percentage: percentage,
        isPositive: !_isNegative(amount) && !_isNegative(percentage),
        percentValue: _parsePercent(percentage),
      ));
    }
    return periods;
  }

  bool _isNegative(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('-');
  }

  double? _parsePercent(String value) {
    final cleaned = value
        .trim()
        .replaceAll('%', '')
        .replaceAll(',', '')
        .replaceAll('+', '');
    return double.tryParse(cleaned);
  }
}
