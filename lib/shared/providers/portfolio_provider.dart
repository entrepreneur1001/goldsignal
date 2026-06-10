import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/firebase/firestore_portfolio_service.dart';
import '../models/portfolio_item.dart';
import 'auth_provider.dart';

final firestorePortfolioServiceProvider =
    Provider<FirestorePortfolioService>((ref) => FirestorePortfolioService());

/// Live portfolio for the signed-in user, straight from Firestore (offline
/// cache included). `autoDispose` so the listener tears down when the Wallet
/// tab is gone — important before the Firestore cache is wiped on sign-out.
final portfolioProvider =
    StreamProvider.autoDispose<List<PortfolioItem>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const <PortfolioItem>[]);
  return ref
      .watch(firestorePortfolioServiceProvider)
      .streamAll(uid)
      .map((maps) => maps.map(PortfolioItem.fromFirestoreMap).toList());
});

final portfolioControllerProvider =
    Provider<PortfolioController>((ref) => PortfolioController(ref));

/// Write-only controller — mutations go to Firestore and the [portfolioProvider]
/// stream reflects them automatically (no local state to keep in sync).
class PortfolioController {
  PortfolioController(this.ref);
  final Ref ref;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  FirestorePortfolioService get _service =>
      ref.read(firestorePortfolioServiceProvider);

  Future<void> add(PortfolioItem item) async {
    final uid = _uid;
    if (uid == null) return;
    await _service.saveItem(uid, item.toFirestoreMap());
    await AnalyticsService.instance
        .logEvent('portfolio_item_added', parameters: {'metal': item.metal});
  }

  Future<void> update(PortfolioItem item) async {
    final uid = _uid;
    if (uid == null || item.firestoreId == null) return;
    await _service.saveItem(uid, item.toFirestoreMap(),
        docId: item.firestoreId);
  }

  Future<void> delete(String firestoreId) async {
    final uid = _uid;
    if (uid == null) return;
    await _service.deleteItem(uid, firestoreId);
  }
}
