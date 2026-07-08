import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groq/groq.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ai/portfolio_analysis_fingerprint.dart';
import '../../core/ai/portfolio_context_builder.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/crash/crash_reporter.dart';
import '../../core/firebase/firestore_portfolio_analysis_service.dart';
import '../../core/utils/api_config.dart';
import '../models/portfolio_item.dart';
import 'auth_provider.dart';
import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';
import 'portfolio_provider.dart';

const _prefsHashKeyPrefix = 'portfolio_analysis_input_hash_';
const _prefsAnalysisPrefixBase = 'portfolio_analysis_text_';
const _prefsSnapshotKeyPrefix = 'portfolio_analysis_price_snapshot_';
const _prefsRefreshCountKeyPrefix = 'portfolio_analysis_refresh_count_';
const _prefsRefreshYmdKeyPrefix = 'portfolio_analysis_refresh_ymd_';
const _maxDailyRefreshes = 5;

String _prefsHashKey(String uid) => '$_prefsHashKeyPrefix$uid';
String _prefsAnalysisPrefix(String uid) => '$_prefsAnalysisPrefixBase${uid}_';
String _prefsSnapshotKey(String uid) => '$_prefsSnapshotKeyPrefix$uid';
String _prefsRefreshCountKey(String uid) => '$_prefsRefreshCountKeyPrefix$uid';
String _prefsRefreshYmdKey(String uid) => '$_prefsRefreshYmdKeyPrefix$uid';

enum PortfolioAnalysisStatus {
  needsHoldings,
  idle,
  loading,
  ready,
  error,
}

class PortfolioAnalysisState {
  const PortfolioAnalysisState({
    this.status = PortfolioAnalysisStatus.idle,
    this.text = '',
    this.errorMessage,
    this.expanded = true,
  });

  final PortfolioAnalysisStatus status;
  final String text;
  final String? errorMessage;
  final bool expanded;

  bool get isLoading =>
      status == PortfolioAnalysisStatus.loading ||
      status == PortfolioAnalysisStatus.idle;

  PortfolioAnalysisState copyWith({
    PortfolioAnalysisStatus? status,
    String? text,
    String? errorMessage,
    bool? expanded,
    bool clearError = false,
  }) {
    return PortfolioAnalysisState(
      status: status ?? this.status,
      text: text ?? this.text,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      expanded: expanded ?? this.expanded,
    );
  }
}

final firestorePortfolioAnalysisServiceProvider =
    Provider<FirestorePortfolioAnalysisService>(
  (ref) => FirestorePortfolioAnalysisService(),
);

final portfolioAnalysisProvider =
    NotifierProvider<PortfolioAnalysisNotifier, PortfolioAnalysisState>(
  PortfolioAnalysisNotifier.new,
);

class PortfolioAnalysisNotifier extends Notifier<PortfolioAnalysisState> {
  bool _loadInFlight = false;
  String _pendingLocale = 'en';

  /// Called by the UI when the app locale is known.
  void bindLocale(String languageCode) {
    if (_pendingLocale == languageCode) return;
    _pendingLocale = languageCode;
    applyLocale(languageCode);
    if (state.status == PortfolioAnalysisStatus.idle ||
        state.status == PortfolioAnalysisStatus.needsHoldings) {
      loadIfNeeded(locale: languageCode);
    }
  }

  @override
  PortfolioAnalysisState build() {
    ref.listen(authStateProvider, (prev, next) {
      final uid = next.asData?.value?.uid;
      final prevUid = prev?.asData?.value?.uid;
      if (uid == null && prevUid != null) {
        state = const PortfolioAnalysisState(
          status: PortfolioAnalysisStatus.needsHoldings,
        );
        return;
      }
      if (uid != null) {
        Future.microtask(() => loadIfNeeded(locale: _pendingLocale));
      }
    });
    ref.listen(portfolioProvider, (_, next) {
      final items = next.asData?.value;
      if (items != null) {
        Future.microtask(() => loadIfNeeded(locale: _pendingLocale));
      }
    });
    ref.listen(selectedCurrencyProvider, (_, _) {
      Future.microtask(() => loadIfNeeded(locale: _pendingLocale));
    });
    Future.microtask(() => loadIfNeeded(locale: _pendingLocale));
    return const PortfolioAnalysisState();
  }

  void toggleExpanded() {
    state = state.copyWith(expanded: !state.expanded);
  }

  Future<void> refresh({String locale = 'en'}) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    final allowed = await _canForceRefresh(uid);
    if (!allowed) {
      state = state.copyWith(
        status: PortfolioAnalysisStatus.error,
        errorMessage: 'refresh_limit',
      );
      return;
    }
    await _recordForceRefresh(uid);
    AnalyticsService.instance.logEvent('portfolio_analysis_refresh');
    await loadIfNeeded(force: true, locale: locale);
  }

  Future<void> retry({String locale = 'en'}) async {
    await loadIfNeeded(force: true, locale: locale);
  }

  Future<void> loadIfNeeded({bool force = false, String locale = 'en'}) async {
    if (_loadInFlight) return;

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final items =
        ref.read(portfolioProvider).asData?.value ?? const <PortfolioItem>[];

    if (items.isEmpty) {
      state = const PortfolioAnalysisState(
        status: PortfolioAnalysisStatus.needsHoldings,
      );
      return;
    }

    if (uid == null) {
      state = const PortfolioAnalysisState(
        status: PortfolioAnalysisStatus.idle,
      );
      return;
    }

    _loadInFlight = true;
    try {
      final currency = ref.read(selectedCurrencyProvider);
      final inputHash = computePortfolioInputHash(items, currency);
      final priceSnapshot = _currentPriceSnapshot(currency);

      if (!force) {
        final localText =
            await _loadLocalCache(uid, inputHash, priceSnapshot, locale);
        if (localText != null) {
          AnalyticsService.instance.logEvent('portfolio_analysis_cache_hit');
          state = PortfolioAnalysisState(
            status: PortfolioAnalysisStatus.ready,
            text: localText,
            expanded: state.expanded,
          );
          return;
        }

        final remote = await ref
            .read(firestorePortfolioAnalysisServiceProvider)
            .load(uid);
        if (remote != null &&
            remote.inputHash == inputHash &&
            !isPriceStale(remote.priceSnapshot, priceSnapshot)) {
          final text = remote.textForLocale(locale);
          if (text.isNotEmpty) {
            await _saveLocalCache(
              uid,
              inputHash,
              remote.analysis,
              remote.priceSnapshot,
            );
            AnalyticsService.instance.logEvent('portfolio_analysis_cache_hit');
            state = PortfolioAnalysisState(
              status: PortfolioAnalysisStatus.ready,
              text: text,
              expanded: state.expanded,
            );
            return;
          }
        }
      }

      if (ApiConfig.groqApiKey.isEmpty) {
        state = state.copyWith(
          status: PortfolioAnalysisStatus.error,
          errorMessage: 'missing_api_key',
          clearError: false,
        );
        return;
      }

      state = state.copyWith(
        status: PortfolioAnalysisStatus.loading,
        clearError: true,
      );

      final analysis = await _generateAnalysis(items, currency, priceSnapshot);
      final cache = PortfolioAnalysisCache(
        inputHash: inputHash,
        analysis: analysis,
        priceSnapshot: priceSnapshot,
        portfolioItemCount: items.length,
      );

      await _saveLocalCache(uid, inputHash, analysis, priceSnapshot);
      await ref.read(firestorePortfolioAnalysisServiceProvider).save(uid, cache);

      AnalyticsService.instance.logEvent('portfolio_analysis_generated');

      state = PortfolioAnalysisState(
        status: PortfolioAnalysisStatus.ready,
        text: cache.textForLocale(locale),
        expanded: state.expanded,
      );
    } on GroqException catch (e, st) {
      reportNonFatal(e, st, reason: 'portfolio_analysis_generate');
      state = state.copyWith(
        status: PortfolioAnalysisStatus.error,
        errorMessage: e.message,
      );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'portfolio_analysis_generate');
      state = state.copyWith(
        status: PortfolioAnalysisStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      _loadInFlight = false;
    }
  }

  PortfolioPriceSnapshot _currentPriceSnapshot(String currency) {
    final gold = ref.read(metalPriceProvider);
    final silver = ref.read(silverPriceProvider);
    final local = ref.read(localMarketPricesProvider);
    return buildPriceSnapshot(
      currency: currency,
      gold: gold,
      silver: silver,
      local: local,
    );
  }

  /// Updates displayed text for the active locale without re-fetching AI.
  Future<void> applyLocale(String languageCode) async {
    if (state.status != PortfolioAnalysisStatus.ready &&
        state.status != PortfolioAnalysisStatus.loading) {
      return;
    }
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    final currency = ref.read(selectedCurrencyProvider);
    final items = ref.read(portfolioProvider).asData?.value ?? const [];
    final inputHash = computePortfolioInputHash(items, currency);
    final priceSnapshot = _currentPriceSnapshot(currency);
    final localText =
        await _loadLocalCache(uid, inputHash, priceSnapshot, languageCode);
    if (localText != null && localText.isNotEmpty) {
      state = state.copyWith(text: localText);
      return;
    }
    final remote =
        await ref.read(firestorePortfolioAnalysisServiceProvider).load(uid);
    if (remote != null) {
      final text = remote.textForLocale(languageCode);
      if (text.isNotEmpty) {
        state = state.copyWith(text: text);
      }
    }
  }

  Future<Map<String, String>> _generateAnalysis(
    List<PortfolioItem> items,
    String currency,
    PortfolioPriceSnapshot priceSnapshot,
  ) async {
    final gold = ref.read(metalPriceProvider);
    final silver = ref.read(silverPriceProvider);
    final local = ref.read(localMarketPricesProvider);
    final side = ref.read(priceSideProvider);
    final rates = ref.read(metalPriceApiProvider).getCachedPrices()?.rates;

    final marketContext = buildMarketPriceContext(
      currency: currency,
      gold: gold,
      silver: silver,
      local: local,
      side: side,
    );
    final portfolioContext = buildPortfolioContext(
      items: items,
      gold: gold,
      silver: silver,
      currency: currency,
      rates: rates,
      local: local,
    );

    final groq = Groq(
      apiKey: ApiConfig.groqApiKey,
      configuration: Configuration(
        model: 'llama-3.3-70b-versatile',
        // The trilingual payload needs ~3000 tokens; a tighter cap truncates
        // the JSON mid-string and the parse fails.
        maxCompletionTokens: 10000,
        temperature: 0.6,
      ),
    );
    groq.startChat();

    final systemPrompt = '''You are a precious metals portfolio analyst for GoldSignal.
Provide educational portfolio insights — not financial advice.

$marketContext
$portfolioContext

Gold 24h change: ${priceSnapshot.goldChange24hPct?.toStringAsFixed(2) ?? 'n/a'}%
Silver 24h change: ${priceSnapshot.silverChange24hPct?.toStringAsFixed(2) ?? 'n/a'}%

Cover briefly:
- Overall performance and allocation (gold vs silver, concentration)
- Notable winners/losers among holdings
- Practical next steps (DCA, rebalancing ideas, zakat awareness if relevant)

Respond with ONLY valid JSON (no markdown fences) in this exact shape:
{"en":"English analysis (3-5 short paragraphs or bullets)","ar":"Arabic translation","ur":"Urdu translation"}
Output the JSON on a single line; escape line breaks inside strings as \\n.''';

    groq.setCustomInstructionsWith(systemPrompt);
    final response = await groq.sendMessage(
      'Analyze my portfolio and return the trilingual JSON.',
    );
    final raw = response.choices.first.message.content.trim();
    return parseTrilingualAnalysisJson(raw);
  }

  Future<String?> _loadLocalCache(
    String uid,
    String inputHash,
    PortfolioPriceSnapshot snapshot,
    String locale,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHash = prefs.getString(_prefsHashKey(uid));
    if (cachedHash != inputHash) return null;

    final snapshotJson = prefs.getString(_prefsSnapshotKey(uid));
    if (snapshotJson != null) {
      final cachedSnapshot = PortfolioPriceSnapshot.fromMap(
        jsonDecode(snapshotJson) as Map<String, dynamic>,
      );
      if (isPriceStale(cachedSnapshot, snapshot)) return null;
    }

    return prefs.getString('${_prefsAnalysisPrefix(uid)}$locale') ??
        prefs.getString('${_prefsAnalysisPrefix(uid)}en');
  }

  Future<void> _saveLocalCache(
    String uid,
    String inputHash,
    Map<String, String> analysis,
    PortfolioPriceSnapshot snapshot,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsHashKey(uid), inputHash);
    await prefs.setString(_prefsSnapshotKey(uid), jsonEncode(snapshot.toMap()));
    for (final entry in analysis.entries) {
      await prefs.setString(
        '${_prefsAnalysisPrefix(uid)}${entry.key}',
        entry.value,
      );
    }
  }

  Future<bool> _canForceRefresh(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final ymd = _todayYmd();
    final storedYmd = prefs.getString(_prefsRefreshYmdKey(uid));
    if (storedYmd != ymd) return true;
    final count = prefs.getInt(_prefsRefreshCountKey(uid)) ?? 0;
    return count < _maxDailyRefreshes;
  }

  Future<void> _recordForceRefresh(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final ymd = _todayYmd();
    final storedYmd = prefs.getString(_prefsRefreshYmdKey(uid));
    if (storedYmd != ymd) {
      await prefs.setString(_prefsRefreshYmdKey(uid), ymd);
      await prefs.setInt(_prefsRefreshCountKey(uid), 1);
      return;
    }
    final count = prefs.getInt(_prefsRefreshCountKey(uid)) ?? 0;
    await prefs.setInt(_prefsRefreshCountKey(uid), count + 1);
  }

  String _todayYmd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
