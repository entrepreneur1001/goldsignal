import '../../core/utils/currency_conversion.dart';
import '../../shared/local_market/local_market_config.dart';
import '../../shared/models/local_market_prices.dart';
import '../../shared/models/metal_price.dart';
import '../../shared/models/portfolio_item.dart';
import '../../shared/providers/market_prices_provider.dart';

/// Builds a human-readable portfolio summary for AI prompts (chatbot + analyzer).
String buildPortfolioContext({
  required List<PortfolioItem> items,
  required MetalPrice? gold,
  required MetalPrice? silver,
  required String currency,
  required Map<String, double>? rates,
  required LocalMarketPrices? local,
}) {
  if (items.isEmpty) return 'User has no portfolio holdings yet.';

  final isLocal = LocalMarketConfig.isLocalCurrency(currency);

  try {
    double purchaseInDisplay(PortfolioItem item) {
      final raw = item.purchasePrice * item.weight;
      if (rates == null) return raw;
      return convertWithUsdBaseRates(
            raw,
            item.purchaseCurrency,
            currency,
            rates,
          ) ??
          raw;
    }

    double totalCurrentValue = 0;
    double totalPurchaseCost = 0;
    final holdings = <String>[];

    for (final item in items) {
      final price = item.metal == 'Gold' ? gold : silver;
      final purchaseCost = purchaseInDisplay(item);
      totalPurchaseCost += purchaseCost;

      double currentValue = 0;
      if (isLocal && local != null) {
        if (item.metal == 'Gold') {
          final perGram = localGoldPortfolioPrice(local, item.karat.round());
          if (perGram != null) currentValue = perGram * item.weight;
        } else {
          final perGram = localSilverPortfolioPrice(local, item.karat.round());
          if (perGram != null) currentValue = perGram * item.weight;
        }
        totalCurrentValue += currentValue;
      } else if (price != null) {
        final karatMultiplier = item.karat / 24;
        currentValue = price.getPricePerGram() * karatMultiplier * item.weight;
        totalCurrentValue += currentValue;
      }

      final pl = currentValue - purchaseCost;
      final plPercent = purchaseCost > 0 ? (pl / purchaseCost * 100) : 0.0;
      holdings.add(
        '${item.weight}g ${item.metal} ${item.karat}K '
        '(bought at ${item.purchasePrice.toStringAsFixed(2)}/'
        '${item.purchaseCurrency}/g, current value in $currency: '
        '${currentValue.toStringAsFixed(2)}, P/L: '
        '${plPercent >= 0 ? '+' : ''}${plPercent.toStringAsFixed(1)}%)',
      );
    }

    final totalPL = totalCurrentValue - totalPurchaseCost;
    final totalPLPercent =
        totalPurchaseCost > 0 ? (totalPL / totalPurchaseCost * 100) : 0.0;

    return """User's portfolio (${items.length} holding${items.length > 1 ? 's' : ''}):
${holdings.map((h) => '- $h').join('\n')}
Total purchase cost: $currency ${totalPurchaseCost.toStringAsFixed(2)}
Total current value: $currency ${totalCurrentValue.toStringAsFixed(2)}
Total P/L: ${totalPLPercent >= 0 ? '+' : ''}${totalPLPercent.toStringAsFixed(1)}% ($currency ${totalPL.toStringAsFixed(2)})""";
  } catch (_) {
    return '';
  }
}

/// Market price context for AI portfolio analysis prompts.
String buildMarketPriceContext({
  required String currency,
  required MetalPrice? gold,
  required MetalPrice? silver,
  required LocalMarketPrices? local,
  required PriceSide side,
}) {
  final isLocal = LocalMarketConfig.isLocalCurrency(currency);
  final buffer = StringBuffer();

  if (isLocal && local != null) {
    buffer.write(buildLocalMarketPrompt(local, side));
    final headlineKarat = local.headlineGoldKarat;
    buffer.write(
      ' Headline ${headlineKarat}K gold ${LocalMarketConfig.hasBuySellSide(currency) ? side.name : 'indicative'} price: '
      '${local.headlineGold?.priceFor(side).toStringAsFixed(2) ?? 'N/A'} $currency/g. ',
    );
    final silver = local.headlineSilver;
    if (silver != null) {
      buffer.write(
        'Silver 999: ${silver.sellPerGram.toStringAsFixed(2)} $currency/g. ',
      );
    }
  } else {
    if (gold != null) {
      buffer.write(
        'Current gold price: $currency ${gold.pricePerOunce.toStringAsFixed(2)}/oz '
        '($currency ${gold.pricePerGram.toStringAsFixed(2)}/g). '
        '24h change: ${gold.formattedChangePercent}. ',
      );
    }
    if (silver != null) {
      buffer.write(
        'Current silver price: $currency ${silver.pricePerOunce.toStringAsFixed(2)}/oz '
        '($currency ${silver.pricePerGram.toStringAsFixed(2)}/g). '
        '24h change: ${silver.formattedChangePercent}. ',
      );
    }
  }

  return buffer.toString();
}
