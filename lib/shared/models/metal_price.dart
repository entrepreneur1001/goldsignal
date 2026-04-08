class MetalPrice {
  final String metal;
  final double pricePerOunce;
  final double pricePerGram;
  final String currency;
  final DateTime timestamp;
  final double change24h;
  final double changePercent24h;
  
  MetalPrice({
    required this.metal,
    required this.pricePerOunce,
    required this.pricePerGram,
    required this.currency,
    required this.timestamp,
    required this.change24h,
    required this.changePercent24h,
  });
  
  factory MetalPrice.fromJson(Map<String, dynamic> json) {
    final pricePerOunce = (json['pricePerOunce'] ?? 0.0).toDouble();
    return MetalPrice(
      metal: json['metal'] ?? '',
      pricePerOunce: pricePerOunce,
      pricePerGram: pricePerOunce / 31.1034768, // Convert ounce to gram
      currency: json['currency'] ?? 'USD',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      change24h: (json['change24h'] ?? 0.0).toDouble(),
      changePercent24h: (json['changePercent24h'] ?? 0.0).toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'metal': metal,
    'pricePerOunce': pricePerOunce,
    'pricePerGram': pricePerGram,
    'currency': currency,
    'timestamp': timestamp.toIso8601String(),
    'change24h': change24h,
    'changePercent24h': changePercent24h,
  };
  
  // Price per gram (already in the selected currency from provider push)
  double getPricePerGram() => pricePerGram;
  
  // Calculate price for specific karat
  double getPriceForKarat(String karat) {
    final karatValues = {
      '24K': 1.0,
      '22K': 0.916,
      '21K': 0.875,
      '18K': 0.75,
    };
    
    return pricePerGram * (karatValues[karat] ?? 1.0);
  }
  
  bool get isPositiveChange => change24h >= 0;
  
  String get formattedChange => isPositiveChange ? '+$change24h' : '$change24h';
  
  String get formattedChangePercent => 
      isPositiveChange ? '+${changePercent24h.toStringAsFixed(2)}%' : '${changePercent24h.toStringAsFixed(2)}%';
}