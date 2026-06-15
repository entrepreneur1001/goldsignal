import 'package:flutter/material.dart';
import '../../../../shared/design/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/ad_service.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/portfolio_provider.dart';
import '../../zakat.dart';
import '../../../../core/utils/currency_format.dart';

class ZakatCalculatorScreen extends ConsumerStatefulWidget {
  const ZakatCalculatorScreen({super.key});

  @override
  ConsumerState<ZakatCalculatorScreen> createState() =>
      _ZakatCalculatorScreenState();
}

class _ZakatCalculatorScreenState extends ConsumerState<ZakatCalculatorScreen> {
  final _extraGoldController = TextEditingController();
  final _extraSilverController = TextEditingController();
  final _cashController = TextEditingController();

  int _extraGoldKarat = 24;
  bool _includePortfolio = true;
  NisabBasis _nisabBasis = NisabBasis.silver;

  @override
  void dispose() {
    _extraGoldController.dispose();
    _extraSilverController.dispose();
    _cashController.dispose();
    AdService.instance.showInterstitial();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0.0;

  /// Current 24K gold price per gram in the selected currency (local-aware).
  double? _gold24PerGram() {
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    if (isLocal && local != null) {
      return localGoldPortfolioPrice(local, 24);
    }
    return ref.read(metalPriceProvider)?.getPricePerGram();
  }

  /// Current silver price per gram in the selected currency (local-aware).
  double? _silverPerGram() {
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    if (isLocal && local != null) {
      return localSilverPortfolioPrice(local, 999);
    }
    return ref.read(silverPriceProvider)?.getPricePerGram();
  }

  /// Sum of current market value of portfolio holdings, split by metal.
  ({double gold, double silver}) _portfolioValues(
    double? gold24,
    double? silver,
  ) {
    if (!_includePortfolio) {
      return (gold: 0.0, silver: 0.0);
    }
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    final items = ref.read(portfolioProvider).asData?.value ?? const [];

    double goldValue = 0;
    double silverValue = 0;
    for (final item in items) {
      if (item.metal == 'Gold') {
        double? perGram;
        if (isLocal && local != null) {
          perGram = localGoldPortfolioPrice(local, item.karat.round());
        } else if (gold24 != null) {
          perGram = gold24 * (item.karat / 24);
        }
        if (perGram != null) goldValue += perGram * item.weight;
      } else {
        double? perGram;
        if (isLocal && local != null) {
          perGram = localSilverPortfolioPrice(local, item.karat.round());
        } else if (silver != null) {
          perGram = silver; // silver priced at .999, weight already in grams
        }
        if (perGram != null) silverValue += perGram * item.weight;
      }
    }
    return (gold: goldValue, silver: silverValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(selectedCurrencyProvider);

    // Watch price sources so the result recomputes when they change.
    ref.watch(metalPriceProvider);
    ref.watch(silverPriceProvider);
    ref.watch(localMarketPricesProvider);

    final gold24 = _gold24PerGram();
    final silver = _silverPerGram();
    // Gold price is required; silver is optional (some markets only quote gold).
    final pricesReady = gold24 != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Zakat Calculator'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: pricesReady
            ? _buildContent(theme, currency, gold24, silver)
            : _buildPricesUnavailable(theme),
      ),
    );
  }

  Widget _buildPricesUnavailable(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.price_change_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Live prices not loaded yet',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Zakat is calculated from current gold and silver prices. '
              'Refresh prices and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(marketPricesControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh prices'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    String currency,
    double gold24,
    double? silver,
  ) {
    final silverPrice = silver ?? 0.0;
    final portfolio = _portfolioValues(gold24, silver);

    final extraGoldValue = gold24 * (_extraGoldKarat / 24) * _parse(_extraGoldController);
    final extraSilverValue = silverPrice * _parse(_extraSilverController);
    final cash = _parse(_cashController);

    final totalGold = portfolio.gold + extraGoldValue;
    final totalSilver = portfolio.silver + extraSilverValue;
    final total = totalGold + totalSilver + cash;

    // Without a silver price, fall back to the gold nisab basis.
    final effectiveBasis =
        silver == null ? NisabBasis.gold : _nisabBasis;
    final nisabValue = Zakat.nisabValue(
      basis: effectiveBasis,
      gold24PerGram: gold24,
      silverPerGram: silverPrice,
    );
    final nisabGrams = Zakat.nisabGrams(effectiveBasis);
    final result = Zakat.compute(totalWealth: total, nisabValue: nisabValue);
    final isDue = result.isDue;
    final zakat = result.amount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildInfoCard(theme),
        const SizedBox(height: 16),

        // Result
        _buildResultCard(
          theme,
          currency: currency,
          total: total,
          nisabValue: nisabValue,
          isDue: isDue,
          zakat: zakat,
        ),
        const SizedBox(height: 24),

        // Holdings source
        Text('Assets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: _includePortfolio,
                onChanged: (v) => setState(() => _includePortfolio = v),
                title: const Text('Include my portfolio'),
                subtitle: Text(
                  'Gold ${formatCurrency(portfolio.gold, currency)} · '
                  'Silver ${formatCurrency(portfolio.silver, currency)}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Manual additions
        Text('Add other assets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildGoldRow(theme),
        const SizedBox(height: 12),
        _buildNumberField(
          controller: _extraSilverController,
          label: 'Other silver (grams)',
          icon: Icons.circle_outlined,
        ),
        const SizedBox(height: 12),
        _buildNumberField(
          controller: _cashController,
          label: 'Cash / savings ($currency)',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: 24),

        // Nisab basis
        Text('Nisab threshold', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<NisabBasis>(
          segments: const [
            ButtonSegment(
              value: NisabBasis.silver,
              label: Text('Silver (595g)'),
            ),
            ButtonSegment(
              value: NisabBasis.gold,
              label: Text('Gold (85g)'),
            ),
          ],
          selected: {_nisabBasis},
          onSelectionChanged: (s) => setState(() => _nisabBasis = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          'Nisab = ${nisabGrams.toStringAsFixed(0)}g '
          '${effectiveBasis == NisabBasis.silver ? 'silver' : 'gold'} '
          '≈ ${formatCurrency(nisabValue, currency)}. '
          'Silver basis is recommended when combining assets.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildResultCard(
    ThemeData theme, {
    required String currency,
    required double total,
    required double nisabValue,
    required bool isDue,
    required double zakat,
  }) {
    final shortfall = nisabValue - total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VaultColors.gold,
            VaultColors.gold.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: VaultColors.gold.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDue ? 'Zakat due (2.5%)' : 'No zakat due',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDue ? formatCurrency(zakat, currency) : formatCurrency(0, currency),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _resultRow('Zakatable wealth', formatCurrency(total, currency)),
          const SizedBox(height: 4),
          _resultRow('Nisab threshold', formatCurrency(nisabValue, currency)),
          if (!isDue && shortfall > 0) ...[
            const SizedBox(height: 4),
            _resultRow('Below nisab by', formatCurrency(shortfall, currency)),
          ],
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildGoldRow(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildNumberField(
            controller: _extraGoldController,
            label: 'Other gold (grams)',
            icon: Icons.diamond_outlined,
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: _extraGoldKarat,
          items: const [
            DropdownMenuItem(value: 24, child: Text('24K')),
            DropdownMenuItem(value: 22, child: Text('22K')),
            DropdownMenuItem(value: 21, child: Text('21K')),
            DropdownMenuItem(value: 18, child: Text('18K')),
          ],
          onChanged: (v) => setState(() => _extraGoldKarat = v ?? 24),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Zakat of 2.5% is due on gold, silver and cash once their combined '
              'value reaches the nisab and a full lunar year (hawl) has passed. '
              'This is an estimate for guidance — consult a scholar for rulings, '
              'including on personal-use jewelry.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

}
