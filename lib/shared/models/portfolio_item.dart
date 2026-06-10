/// A single precious-metal holding. Persisted in Firestore under
/// `users/{uid}/portfolio/{docId}` (Firestore is the single source of truth —
/// no local Hive copy).
class PortfolioItem {
  String? firestoreId;
  final String metal;
  final int karat;
  final double weight;

  /// ISO currency code for [purchasePrice] (per gram), as when the holding was saved.
  final double purchasePrice;
  final String purchaseCurrency;
  final DateTime purchaseDate;
  final String? notes;

  PortfolioItem({
    this.firestoreId,
    required this.metal,
    required this.karat,
    required this.weight,
    required this.purchasePrice,
    required this.purchaseCurrency,
    required this.purchaseDate,
    this.notes,
  });

  Map<String, dynamic> toFirestoreMap() => {
        'metal': metal,
        'karat': karat,
        'weight': weight,
        'purchasePrice': purchasePrice,
        'purchaseCurrency': purchaseCurrency,
        'purchaseDate': purchaseDate.millisecondsSinceEpoch,
        'notes': notes ?? '',
      };

  factory PortfolioItem.fromFirestoreMap(Map<String, dynamic> data) {
    return PortfolioItem(
      firestoreId: data['firestoreId'] as String?,
      metal: data['metal'] ?? 'Gold',
      karat: data['karat'] ?? 24,
      weight: (data['weight'] as num).toDouble(),
      purchasePrice: (data['purchasePrice'] as num).toDouble(),
      purchaseCurrency: data['purchaseCurrency'] as String? ?? 'SAR',
      purchaseDate:
          DateTime.fromMillisecondsSinceEpoch(data['purchaseDate'] as int),
      notes: data['notes'] == '' ? null : data['notes'] as String?,
    );
  }
}
