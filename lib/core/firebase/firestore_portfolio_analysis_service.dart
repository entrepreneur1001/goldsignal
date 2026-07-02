import 'package:cloud_firestore/cloud_firestore.dart';

import '../ai/portfolio_analysis_fingerprint.dart';
import '../crash/crash_reporter.dart';

/// Cached AI portfolio analysis stored per user in Firestore.
class PortfolioAnalysisCache {
  const PortfolioAnalysisCache({
    required this.inputHash,
    required this.analysis,
    required this.priceSnapshot,
    required this.portfolioItemCount,
    this.generatedAt,
  });

  final String inputHash;
  final Map<String, String> analysis;
  final PortfolioPriceSnapshot priceSnapshot;
  final int portfolioItemCount;
  final DateTime? generatedAt;

  String textForLocale(String languageCode) {
    if (analysis.containsKey(languageCode)) {
      return analysis[languageCode]!;
    }
    if (analysis.containsKey('en')) return analysis['en']!;
    if (analysis.isNotEmpty) return analysis.values.first;
    return '';
  }

  Map<String, dynamic> toMap() => {
        'inputHash': inputHash,
        'analysis': analysis,
        'priceSnapshot': priceSnapshot.toMap(),
        'portfolioItemCount': portfolioItemCount,
        'generatedAt': FieldValue.serverTimestamp(),
      };

  factory PortfolioAnalysisCache.fromMap(Map<String, dynamic> map) {
    final rawAnalysis = map['analysis'];
    final analysis = <String, String>{};
    if (rawAnalysis is Map) {
      for (final entry in rawAnalysis.entries) {
        analysis[entry.key.toString()] = entry.value.toString();
      }
    }

    final generatedAt = map['generatedAt'];
    DateTime? parsedAt;
    if (generatedAt is Timestamp) {
      parsedAt = generatedAt.toDate();
    }

    return PortfolioAnalysisCache(
      inputHash: map['inputHash'] as String? ?? '',
      analysis: analysis,
      priceSnapshot: PortfolioPriceSnapshot.fromMap(
        Map<String, dynamic>.from(
          map['priceSnapshot'] as Map? ?? const {},
        ),
      ),
      portfolioItemCount: map['portfolioItemCount'] as int? ?? 0,
      generatedAt: parsedAt,
    );
  }
}

class FirestorePortfolioAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('aiCache')
      .doc('portfolioAnalysis');

  Future<PortfolioAnalysisCache?> load(String uid) async {
    try {
      return await _readDoc(uid, const GetOptions());
    } on FirebaseException catch (e, st) {
      reportNonFatal(e, st, reason: 'portfolio_analysis_load');
      try {
        return await _readDoc(
          uid,
          const GetOptions(source: Source.cache),
        );
      } on FirebaseException catch (e, st) {
        reportNonFatal(e, st, reason: 'portfolio_analysis_load_cache');
        return null;
      }
    }
  }

  Future<PortfolioAnalysisCache?> _readDoc(
    String uid,
    GetOptions options,
  ) async {
    final snap = await _docRef(uid).get(options);
    if (!snap.exists || snap.data() == null) return null;
    return PortfolioAnalysisCache.fromMap(snap.data()!);
  }

  Future<void> save(String uid, PortfolioAnalysisCache cache) async {
    try {
      await _docRef(uid).set(cache.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e, st) {
      reportNonFatal(e, st, reason: 'portfolio_analysis_save');
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'portfolio_analysis_save');
    }
  }
}
