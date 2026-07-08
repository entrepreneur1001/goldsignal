/// A pinned metal/karat pair on the Markets watchlist (stored locally).
class WatchlistEntry {
  final String metal; // 'gold' | 'silver'
  final String karat; // e.g. '24', '21', '999'

  const WatchlistEntry({required this.metal, required this.karat});

  String get id => '${metal}_$karat';

  String get label {
    final metalName = metal == 'gold' ? 'Gold' : 'Silver';
    final karatLabel = metal == 'gold' ? '${karat}K' : karat;
    return '$karatLabel $metalName';
  }

  Map<String, dynamic> toJson() => {'metal': metal, 'karat': karat};

  factory WatchlistEntry.fromJson(Map<String, dynamic> json) {
    return WatchlistEntry(
      metal: json['metal'] as String,
      karat: json['karat'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WatchlistEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Live quote resolved for a [WatchlistEntry] in the user's current market.
class WatchlistQuote {
  final WatchlistEntry entry;
  final double pricePerGram;
  final double? changePercent;
  final String currency;

  const WatchlistQuote({
    required this.entry,
    required this.pricePerGram,
    required this.changePercent,
    required this.currency,
  });
}
