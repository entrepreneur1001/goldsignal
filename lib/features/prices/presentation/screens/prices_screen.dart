import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/metalpriceapi_service.dart';
import '../../../../core/utils/share_price.dart';
import '../../../../shared/models/local_market_prices.dart';
import '../../../../shared/models/metal_price.dart';
import '../../../../shared/models/watchlist_entry.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../../shared/providers/watchlist_provider.dart';
import '../../../../shared/widgets/price_card.dart';
import '../../../../shared/widgets/shimmer.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/currency_selector.dart';
import '../../../../shared/widgets/watchlist_strip.dart';
import '../../../alerts/presentation/widgets/create_alert_sheet.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import '../../../charts/presentation/screens/price_chart_screen.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';

class PricesScreen extends ConsumerWidget {
  const PricesScreen({super.key});

  Future<void> _toggleWatchlist(
    BuildContext context,
    WidgetRef ref,
    WatchlistEntry entry,
  ) async {
    final result = await ref.read(watchlistProvider.notifier).toggle(entry);
    if (!context.mounted || result != WatchlistToggleResult.full) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Watchlist full — remove a pin first (max 8)')),
    );
  }

  void _sharePrice({
    required String label,
    required double pricePerGram,
    required String currency,
    required double changePercent,
  }) {
    shareMetalPrice(
      label: label,
      pricePerGram: pricePerGram,
      currency: currency,
      changePercent: changePercent,
    );
  }

  bool _isWatchlisted(WidgetRef ref, WatchlistEntry entry) =>
      ref.watch(watchlistProvider).any((e) => e.id == entry.id);

  Future<void> _openAlertSheet(
    BuildContext context, {
    required String metal,
    required String karat,
    required String currency,
    required double pricePerGram,
    PriceSide? side,
  }) async {
    // Price alerts are a saved/data feature — require a real account.
    if (!await requireAccount(context, 'price alerts')) return;
    if (!context.mounted) return;
    CreateAlertSheet.show(
      context,
      draft: AlertDraft(
        metal: metal,
        karat: karat,
        currency: currency,
        side: side,
        pricePerGram: pricePerGram,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCurrency = ref.watch(selectedCurrencyProvider);
    final isLocal = ref.watch(isLocalMarketProvider);
    final marketState = ref.watch(marketPricesControllerProvider);
    final localPrices = ref.watch(localMarketPricesProvider);
    final priceSide = ref.watch(priceSideProvider);
    final goldPrice = ref.watch(metalPriceProvider);
    final silverPrice = ref.watch(silverPriceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gold & Silver Prices'),
        actions: [
          const AlertsNavButton(),
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: "Price history",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: 'PriceChart'),
                builder: (_) => const PriceChartScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh prices',
            onPressed: marketState.isRefreshing
                ? null
                : () => ref.read(marketPricesControllerProvider.notifier).refresh(),
            icon: AnimatedRotation(
              turns: marketState.isRefreshing ? 1 : 0,
              duration: const Duration(seconds: 1),
              child: const Icon(Icons.refresh),
            ),
          ),
          CurrencySelector(
            selectedCurrency: selectedCurrency,
            onCurrencyChanged: (currency) {
              ref.read(selectedCurrencyProvider.notifier).setCurrency(currency);
            },
          ),
        ],
      ),
      body: _buildBody(
        context,
        ref,
        marketState,
        isLocal,
        localPrices,
        goldPrice,
        silverPrice,
        selectedCurrency,
        priceSide,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    MarketPricesState marketState,
    bool isLocal,
    LocalMarketPrices? localPrices,
    MetalPrice? goldPrice,
    MetalPrice? silverPrice,
    String selectedCurrency,
    PriceSide priceSide,
  ) {
    final hasData = (isLocal && localPrices != null) ||
        marketState.globalData != null ||
        goldPrice != null;

    if (marketState.isRefreshing && !hasData) {
      return const PriceListSkeleton();
    }

    if (marketState.error != null && !hasData) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Can't load prices",
        message: 'Check your connection and try again.',
        action: FilledButton.icon(
          onPressed: () =>
              ref.read(marketPricesControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(marketPricesControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isLocal) ...[
            _buildBuySellToggle(context, ref, priceSide),
            const SizedBox(height: 16),
          ],
          _buildUpdatedRow(context, marketState.lastUpdated, localPrices),
          const SizedBox(height: 16),
          const WatchlistStrip(),
          if (ref.watch(watchlistProvider).isNotEmpty)
            const SizedBox(height: 16),
          if (isLocal && localPrices != null)
            ..._buildLocalContent(context, ref, localPrices, priceSide)
          else if (marketState.globalData != null)
            ..._buildGlobalContent(
              context,
              ref,
              marketState.globalData!,
              selectedCurrency,
            )
          else if (goldPrice != null)
            ..._buildFromProviders(
              context,
              ref,
              goldPrice,
              silverPrice,
              side: isLocal ? priceSide : null,
            ),
        ],
      ),
    );
  }

  Widget _buildBuySellToggle(
    BuildContext context,
    WidgetRef ref,
    PriceSide side,
  ) {
    return SegmentedButton<PriceSide>(
      segments: const [
        ButtonSegment(
          value: PriceSide.sell,
          label: Text('Sell'),
          icon: Icon(Icons.shopping_bag_outlined),
        ),
        ButtonSegment(
          value: PriceSide.buy,
          label: Text('Buy'),
          icon: Icon(Icons.sell_outlined),
        ),
      ],
      selected: {side},
      onSelectionChanged: (selection) {
        ref.read(priceSideProvider.notifier).setSide(selection.first);
      },
    );
  }

  Widget _buildUpdatedRow(
    BuildContext context,
    DateTime? lastUpdated,
    LocalMarketPrices? local,
  ) {
    final time = local?.updatedAt ?? lastUpdated ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16),
          const SizedBox(width: 8),
          Text(
            'Updated: ${DateFormat('MMM dd, HH:mm').format(time)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  List<Widget> _buildLocalContent(
    BuildContext context,
    WidgetRef ref,
    LocalMarketPrices local,
    PriceSide side,
  ) {
    final headline = local.headlineGold;
    final silverHeadline = local.headlineSilver;
    const goldEntry = WatchlistEntry(metal: 'gold', karat: '21');
    const silverEntry = WatchlistEntry(metal: 'silver', karat: '999');

    return [
      if (headline != null)
        PriceCard(
          metal: 'Gold 21K',
          icon: Icons.monetization_on,
          color: const Color(0xFFFFD700),
          pricePerOunce: headline.priceFor(side) * 31.1034768,
          pricePerGram: headline.priceFor(side),
          currency: 'EGP',
          change24h: headline.change,
          changePercent: headline.changePercent,
          isWatchlisted: _isWatchlisted(ref, goldEntry),
          onToggleWatchlist: () =>
              _toggleWatchlist(context, ref, goldEntry),
          onShare: () => _sharePrice(
            label: goldEntry.label,
            pricePerGram: headline.priceFor(side),
            currency: 'EGP',
            changePercent: headline.changePercent,
          ),
          onSetAlert: () => _openAlertSheet(
            context,
            metal: 'gold',
            karat: '21',
            currency: 'EGP',
            pricePerGram: headline.priceFor(side),
            side: side,
          ),
        ).animate().slideX(begin: -1, duration: 600.ms),
      const SizedBox(height: 16),
      if (silverHeadline != null)
        PriceCard(
          metal: 'Silver 999',
          icon: Icons.paid,
          color: const Color(0xFFC0C0C0),
          pricePerOunce: silverHeadline.priceFor(side) * 31.1034768,
          pricePerGram: silverHeadline.priceFor(side),
          currency: 'EGP',
          change24h: silverHeadline.change,
          changePercent: silverHeadline.changePercent,
          isWatchlisted: _isWatchlisted(ref, silverEntry),
          onToggleWatchlist: () =>
              _toggleWatchlist(context, ref, silverEntry),
          onShare: () => _sharePrice(
            label: silverEntry.label,
            pricePerGram: silverHeadline.priceFor(side),
            currency: 'EGP',
            changePercent: silverHeadline.changePercent,
          ),
          onSetAlert: () => _openAlertSheet(
            context,
            metal: 'silver',
            karat: '999',
            currency: 'EGP',
            pricePerGram: silverHeadline.priceFor(side),
            side: side,
          ),
        ).animate().slideX(begin: 1, duration: 600.ms),
      const SizedBox(height: 24),
      _buildLocalKaratCard(context, ref, 'Gold Prices (per gram)', local.gold, side, isGold: true),
      const SizedBox(height: 16),
      _buildLocalKaratCard(context, ref, 'Silver Prices (per gram)', local.silver, side, isGold: false),
      if (local.fxRates.isNotEmpty) ...[
        const SizedBox(height: 16),
        _buildFxCard(context, local),
      ],
    ];
  }

  Widget _buildLocalKaratCard(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<LocalKaratPrice> rows,
    PriceSide side, {
    required bool isGold,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final row in rows)
              _buildLocalKaratRow(context, ref, row, side, isGold: isGold),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildLocalKaratRow(
    BuildContext context,
    WidgetRef ref,
    LocalKaratPrice row,
    PriceSide side, {
    required bool isGold,
  }) {
    final label = _karatLabel(row.karat);
    final price = row.priceFor(side);
    final gap = side == PriceSide.sell ? row.globalGapSell : row.globalGapBuy;
    final entry = entryForLocalRow(row.karat, isGold: isGold);
    final pinned = _isWatchlisted(ref, entry);
    final canPin = !row.isPerUnit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (gap > 0)
                  Text(
                    'Gap vs global: +${gap.toStringAsFixed(2)} EGP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade600,
                        ),
                  ),
              ],
            ),
          ),
          Text(
            'EGP ${price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            tooltip: 'Share',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            onPressed: () => _sharePrice(
              label: entry.label,
              pricePerGram: price,
              currency: 'EGP',
              changePercent: row.changePercent,
            ),
          ),
          if (canPin)
            IconButton(
              tooltip: pinned ? 'Remove from watchlist' : 'Add to watchlist',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                pinned ? Icons.star_rounded : Icons.star_border_rounded,
                size: 20,
                color: pinned ? const Color(0xFFFFD700) : null,
              ),
              onPressed: () => _toggleWatchlist(context, ref, entry),
            ),
        ],
      ),
    );
  }

  String _karatLabel(String karat) {
    switch (karat) {
      case 'gold_pound':
        return 'Gold Pound';
      case 'silver_pound':
        return 'Silver Pound';
      default:
        return '${karat}K';
    }
  }

  Widget _buildFxCard(BuildContext context, LocalMarketPrices local) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FX Rates (EGP)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final fx in local.fxRates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fx.code),
                    Text(
                      'Sell ${fx.sell.toStringAsFixed(2)} / Buy ${fx.buy.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGlobalContent(
    BuildContext context,
    WidgetRef ref,
    MetalPricesResponse data,
    String currency,
  ) {
    final api = ref.read(metalPriceApiProvider);
    final history = ref.read(priceHistoryServiceProvider);
    final goldPrice = data.goldPriceIn(currency) ?? 0;
    final goldDelta = api.change24hFor(
      response: data,
      metal: 'gold',
      currency: currency,
      historyPercent:
          history.globalChange24hPercent(currency: currency, metal: 'gold'),
    );
    final silverPrice = data.silverPriceIn(currency) ?? 0;
    final silverDelta = api.change24hFor(
      response: data,
      metal: 'silver',
      currency: currency,
      historyPercent:
          history.globalChange24hPercent(currency: currency, metal: 'silver'),
    );

    return [
      PriceCard(
        metal: 'Gold',
        icon: Icons.monetization_on,
        color: const Color(0xFFFFD700),
        pricePerOunce: goldPrice,
        pricePerGram: goldPrice / 31.1034768,
        currency: currency,
        change24h: goldDelta.change,
        changePercent: goldDelta.changePercent,
        isWatchlisted: _isWatchlisted(ref, const WatchlistEntry(metal: 'gold', karat: '24')),
        onToggleWatchlist: () => _toggleWatchlist(
          context,
          ref,
          const WatchlistEntry(metal: 'gold', karat: '24'),
        ),
        onShare: () => _sharePrice(
          label: '24K Gold',
          pricePerGram: goldPrice / 31.1034768,
          currency: currency,
          changePercent: goldDelta.changePercent,
        ),
        onSetAlert: () => _openAlertSheet(
          context,
          metal: 'gold',
          karat: '24',
          currency: currency,
          pricePerGram: goldPrice / 31.1034768,
        ),
      ).animate().slideX(begin: -1, duration: 600.ms),
      const SizedBox(height: 16),
      PriceCard(
        metal: 'Silver',
        icon: Icons.paid,
        color: const Color(0xFFC0C0C0),
        pricePerOunce: silverPrice,
        pricePerGram: silverPrice / 31.1034768,
        currency: currency,
        change24h: silverDelta.change,
        changePercent: silverDelta.changePercent,
        isWatchlisted: _isWatchlisted(ref, const WatchlistEntry(metal: 'silver', karat: '999')),
        onToggleWatchlist: () => _toggleWatchlist(
          context,
          ref,
          const WatchlistEntry(metal: 'silver', karat: '999'),
        ),
        onShare: () => _sharePrice(
          label: '999 Silver',
          pricePerGram: silverPrice / 31.1034768,
          currency: currency,
          changePercent: silverDelta.changePercent,
        ),
        onSetAlert: () => _openAlertSheet(
          context,
          metal: 'silver',
          karat: '999',
          currency: currency,
          pricePerGram: silverPrice / 31.1034768,
        ),
      ).animate().slideX(begin: 1, duration: 600.ms),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gold Karat Prices (per gram)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final entry in [
                ('24K', '24', 1.0),
                ('22K', '22', 0.916),
                ('21K', '21', 0.875),
                ('18K', '18', 0.75),
              ])
                _buildGlobalKaratRow(
                  context,
                  ref,
                  entry.$1,
                  entry.$2,
                  entry.$3,
                  goldPrice / 31.1034768,
                  currency,
                  goldDelta.changePercent,
                ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: 300.ms),
    ];
  }

  List<Widget> _buildFromProviders(
    BuildContext context,
    WidgetRef ref,
    MetalPrice gold,
    MetalPrice? silver, {
    PriceSide? side,
  }) {
    final goldKarat = gold.currency == 'EGP' ? '21' : '24';
    final goldEntry = WatchlistEntry(metal: 'gold', karat: goldKarat);
    const silverEntry = WatchlistEntry(metal: 'silver', karat: '999');

    return [
      PriceCard(
        metal: gold.metal,
        icon: Icons.monetization_on,
        color: const Color(0xFFFFD700),
        pricePerOunce: gold.pricePerOunce,
        pricePerGram: gold.pricePerGram,
        currency: gold.currency,
        change24h: gold.change24h,
        changePercent: gold.changePercent24h,
        isWatchlisted: _isWatchlisted(ref, goldEntry),
        onToggleWatchlist: () => _toggleWatchlist(context, ref, goldEntry),
        onShare: () => _sharePrice(
          label: goldEntry.label,
          pricePerGram: gold.pricePerGram,
          currency: gold.currency,
          changePercent: gold.changePercent24h,
        ),
        onSetAlert: () => _openAlertSheet(
          context,
          metal: 'gold',
          karat: goldKarat,
          currency: gold.currency,
          pricePerGram: gold.pricePerGram,
          side: side,
        ),
      ),
      if (silver != null) ...[
        const SizedBox(height: 16),
        PriceCard(
          metal: silver.metal,
          icon: Icons.paid,
          color: const Color(0xFFC0C0C0),
          pricePerOunce: silver.pricePerOunce,
          pricePerGram: silver.pricePerGram,
          currency: silver.currency,
          change24h: silver.change24h,
          changePercent: silver.changePercent24h,
          isWatchlisted: _isWatchlisted(ref, silverEntry),
          onToggleWatchlist: () =>
              _toggleWatchlist(context, ref, silverEntry),
          onShare: () => _sharePrice(
            label: silverEntry.label,
            pricePerGram: silver.pricePerGram,
            currency: silver.currency,
            changePercent: silver.changePercent24h,
          ),
          onSetAlert: () => _openAlertSheet(
            context,
            metal: 'silver',
            karat: '999',
            currency: silver.currency,
            pricePerGram: silver.pricePerGram,
            side: side,
          ),
        ),
      ],
    ];
  }

  Widget _buildGlobalKaratRow(
    BuildContext context,
    WidgetRef ref,
    String karatLabel,
    String karatCode,
    double purity,
    double goldPerGram,
    String currency,
    double changePercent,
  ) {
    final karatPrice = goldPerGram * purity;
    final entry = WatchlistEntry(metal: 'gold', karat: karatCode);
    final pinned = _isWatchlisted(ref, entry);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(karatLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '$currency ${karatPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            tooltip: 'Share',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            onPressed: () => _sharePrice(
              label: entry.label,
              pricePerGram: karatPrice,
              currency: currency,
              changePercent: changePercent,
            ),
          ),
          IconButton(
            tooltip: pinned ? 'Remove from watchlist' : 'Add to watchlist',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              pinned ? Icons.star_rounded : Icons.star_border_rounded,
              size: 20,
              color: pinned ? const Color(0xFFFFD700) : null,
            ),
            onPressed: () => _toggleWatchlist(context, ref, entry),
          ),
        ],
      ),
    );
  }
}
