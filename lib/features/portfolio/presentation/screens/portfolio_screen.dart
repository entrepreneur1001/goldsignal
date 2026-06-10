import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_typography.dart';
import '../../../../shared/models/portfolio_item.dart';
import '../../../../shared/widgets/animated_value.dart';
import '../../../../shared/widgets/delta_pill.dart';
import '../../../../shared/widgets/shimmer.dart';
import '../../../../shared/widgets/vault_card.dart';
import '../../../../core/utils/currency_conversion.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/portfolio_provider.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import '../../../zakat/zakat.dart';
import '../../../zakat/presentation/screens/zakat_calculator_screen.dart';
import '../../../savings/presentation/screens/savings_goals_screen.dart';

// Re-export so existing importers of this file keep getting PortfolioItem.
export '../../../../shared/models/portfolio_item.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioProvider);
    return portfolioAsync.when(
      loading: () => const _PortfolioLoading(),
      error: (_, _) => const _PortfolioView(items: []),
      data: (items) => _PortfolioView(items: items),
    );
  }
}

class _PortfolioLoading extends StatelessWidget {
  const _PortfolioLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 8),
              ShimmerBox(width: 140, height: 26),
              SizedBox(height: 24),
              ShimmerBox(
                height: 150,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              SizedBox(height: 24),
              ShimmerBox(
                height: 88,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              SizedBox(height: 12),
              ShimmerBox(
                height: 88,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioView extends ConsumerStatefulWidget {
  const _PortfolioView({required this.items});

  final List<PortfolioItem> items;

  @override
  ConsumerState<_PortfolioView> createState() => _PortfolioViewState();
}

class _PortfolioViewState extends ConsumerState<_PortfolioView> {
  List<PortfolioItem> get _items => widget.items;

  Future<void> _showAddItemDialog() async {
    // Gate behind a real account: guests are prompted to sign in / upgrade.
    if (!await requireAccount(context, 'portfolio')) return;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPortfolioItemDialog(
        onSave: (item) => ref.read(portfolioControllerProvider).add(item),
      ),
    );
  }

  void _showEditItemDialog(PortfolioItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPortfolioItemDialog(
        existingItem: item,
        onSave: (updatedItem) {
          updatedItem.firestoreId = item.firestoreId;
          ref.read(portfolioControllerProvider).update(updatedItem);
        },
      ),
    );
  }

  double _itemMarketValue(PortfolioItem item) {
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    final goldPrice = ref.read(metalPriceProvider);
    final silverPrice = ref.read(silverPriceProvider);

    if (isLocal && local != null) {
      if (item.metal == 'Gold') {
        final perGram = localGoldPortfolioPrice(local, item.karat.round());
        if (perGram != null) return perGram * item.weight;
      } else {
        final perGram = localSilverPortfolioPrice(local, item.karat.round());
        if (perGram != null) return perGram * item.weight;
      }
    }

    final price = item.metal == 'Gold' ? goldPrice : silverPrice;
    if (price == null) return 0.0;
    return price.getPricePerGram() * (item.karat / 24) * item.weight;
  }

  /// Current 24K gold price per gram in the selected currency (local-aware).
  double? _gold24PerGram() {
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    if (isLocal && local != null) return localGoldPortfolioPrice(local, 24);
    return ref.read(metalPriceProvider)?.getPricePerGram();
  }

  /// Current silver price per gram in the selected currency (local-aware).
  double? _silverPerGram() {
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    if (isLocal && local != null) return localSilverPortfolioPrice(local, 999);
    return ref.read(silverPriceProvider)?.getPricePerGram();
  }

  /// Compact zakat indicator for the portfolio's current value (silver nisab
  /// basis). Returns null when prices aren't ready or there are no holdings.
  Widget? _buildZakatIndicator(BuildContext context, ThemeData theme) {
    final gold24 = _gold24PerGram();
    final silver = _silverPerGram();
    if (gold24 == null || silver == null) return null;

    final total = _calculateTotalValue();
    if (total <= 0) return null;

    final currency = ref.watch(selectedCurrencyProvider);
    final nisab = Zakat.nisabValue(
      basis: NisabBasis.silver,
      gold24PerGram: gold24,
      silverPerGram: silver,
    );
    final result = Zakat.compute(totalWealth: total, nisabValue: nisab);
    const accent = Color(0xFF2E9E83);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ZakatCalculatorScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.volunteer_activism, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zakat due (2.5%)', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    result.isDue
                        ? formatCurrency(result.amount, currency)
                        : 'Below nisab',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              result.isDue
                  ? 'on ${formatCurrency(total, currency)}'
                  : 'No zakat',
              style: theme.textTheme.bodySmall,
            ),
            const Icon(Icons.chevron_right, color: accent),
          ],
        ),
      ),
    );
  }

  Map<String, double>? _fxRates() {
    return ref.read(metalPriceApiProvider).getCachedPrices()?.rates;
  }

  /// Converts stored purchase total to [displayCurrency] using cached USD-base rates.
  double _purchaseTotalInDisplay(
    PortfolioItem item,
    String displayCurrency,
    Map<String, double>? rates,
  ) {
    final raw = item.purchasePrice * item.weight;
    if (rates == null) return raw;
    final converted = convertWithUsdBaseRates(
      raw,
      item.purchaseCurrency,
      displayCurrency,
      rates,
    );
    return converted ?? raw;
  }

  double _calculateTotalValue() {
    ref.watch(isLocalMarketProvider);
    ref.watch(localMarketPricesProvider);
    ref.watch(metalPriceProvider);
    ref.watch(silverPriceProvider);

    double total = 0.0;
    for (var item in _items) {
      total += _itemMarketValue(item);
    }
    return total;
  }

  double _calculateTotalProfitLoss() {
    ref.watch(isLocalMarketProvider);
    ref.watch(localMarketPricesProvider);
    ref.watch(metalPriceProvider);
    ref.watch(silverPriceProvider);

    final displayCurrency = ref.watch(selectedCurrencyProvider);
    final rates = _fxRates();

    double totalCost = 0.0;
    double totalValue = 0.0;

    for (var item in _items) {
      totalCost += _purchaseTotalInDisplay(item, displayCurrency, rates);
      totalValue += _itemMarketValue(item);
    }

    return totalValue - totalCost;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'My Portfolio',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Savings goals',
                          icon: const Icon(Icons.savings_outlined),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SavingsGoalsScreen(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Zakat calculator',
                          icon: const Icon(Icons.volunteer_activism_outlined),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ZakatCalculatorScreen(),
                            ),
                          ),
                        ),
                        const AlertsNavButton(),
                      ],
                    ),
                    if (ref.watch(isLocalMarketProvider)) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: VaultColors.goldDeep.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Valued at Egypt local buy prices (iSagha)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Net-worth hero + zakat indicator
                    Builder(builder: (_) {
                      final zakatIndicator =
                          _buildZakatIndicator(context, theme);
                      return Column(children: [
                        _buildNetWorthHero()
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(
                              begin: 0.06,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            ),
                        if (zakatIndicator != null) ...[
                          const SizedBox(height: 12),
                          zakatIndicator,
                        ],
                      ]);
                    }),
                    const SizedBox(height: 24),

                    // Holdings Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Holdings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_items.length} items',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Portfolio Items
            if (_items.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No holdings yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first gold or silver holding',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _items[index];
                    return _buildPortfolioItem(item);
                  },
                  childCount: _items.length,
                  addAutomaticKeepAlives: false,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: VaultColors.gold,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Holding',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Sum of current market value split by metal.
  ({double gold, double silver}) _metalSplit() {
    double g = 0, s = 0;
    for (final item in _items) {
      final v = _itemMarketValue(item);
      if (item.metal == 'Gold') {
        g += v;
      } else {
        s += v;
      }
    }
    return (gold: g, silver: s);
  }

  Widget _buildNetWorthHero() {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);
    final currency = ref.watch(selectedCurrencyProvider);

    final total = _calculateTotalValue();
    final pl = _calculateTotalProfitLoss();
    final cost = total - pl;
    final plPercent = cost > 0 ? (pl / cost) * 100 : 0.0;
    final split = _metalSplit();
    final hasHoldings = total > 0;

    return VaultCard(
      glow: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET WORTH', style: AppTypography.microLabel(c)),
          const SizedBox(height: 8),
          AnimatedValue(
            value: total,
            formatter: (v) => formatCurrency(v, currency),
            style: AppTypography.hero(c, size: 40),
          ),
          const SizedBox(height: 12),
          if (hasHoldings)
            Row(
              children: [
                DeltaPill(percent: plPercent),
                const SizedBox(width: 8),
                Text(
                  '${pl >= 0 ? '+' : ''}${formatCurrency(pl, currency)} all-time',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            )
          else
            Text('Add a holding to start tracking',
                style: theme.textTheme.bodySmall),
          if (hasHoldings && (split.gold > 0 || split.silver > 0)) ...[
            const SizedBox(height: 18),
            _allocationBar(c, split.gold, split.silver),
          ],
        ],
      ),
    );
  }

  Widget _allocationBar(VaultColors c, double goldVal, double silverVal) {
    final total = goldVal + silverVal;
    if (total <= 0) return const SizedBox.shrink();
    final goldPct = (goldVal / total * 100).round();
    final silverPct = 100 - goldPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              if (goldVal > 0)
                Expanded(
                  flex: (goldVal / total * 1000).round().clamp(1, 1000),
                  child: Container(height: 8, color: VaultColors.gold),
                ),
              if (silverVal > 0)
                Expanded(
                  flex: (silverVal / total * 1000).round().clamp(1, 1000),
                  child: Container(height: 8, color: VaultColors.silver),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _legend(c, VaultColors.gold, 'Gold $goldPct%'),
            const SizedBox(width: 16),
            _legend(c, VaultColors.silver, 'Silver $silverPct%'),
          ],
        ),
      ],
    );
  }

  Widget _legend(VaultColors c, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPortfolioItem(PortfolioItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.watch(selectedCurrencyProvider);
    final rates = _fxRates();

    double currentValue = 0.0;
    double profitLoss = 0.0;
    double profitLossPercent = 0.0;

    currentValue = _itemMarketValue(item);
    if (currentValue > 0) {
      final totalCostDisplay = _purchaseTotalInDisplay(item, currency, rates);
      profitLoss = currentValue - totalCostDisplay;
      profitLossPercent = totalCostDisplay != 0
          ? (profitLoss / totalCostDisplay) * 100
          : 0.0;
    }

    return Dismissible(
      key: ValueKey(item.firestoreId ?? identityHashCode(item)),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete holding?'),
            content: Text(
              'Remove ${item.weight}g ${item.metal} ${item.karat}K from your portfolio? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (direction) {
        final firestoreId = item.firestoreId;
        if (firestoreId != null) {
          ref.read(portfolioControllerProvider).delete(firestoreId);
        }
      },
      child: GestureDetector(
        onTap: () => _showEditItemDialog(item),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.metal == 'Gold'
                                ? VaultColors.gold.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            item.metal == 'Gold' ? Icons.star : Icons.circle,
                            color: item.metal == 'Gold'
                                ? VaultColors.gold
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.metal} ${item.karat}K',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${item.weight}g • ${_formatDate(item.purchaseDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: profitLoss >= 0
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          profitLoss >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: profitLoss >= 0 ? Colors.green : Colors.red,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profitLoss > 0 ? '+' : ''}${profitLossPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: profitLoss >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildItemDetail(
                      'Purchase',
                      formatCurrency(
                        _purchaseTotalInDisplay(item, currency, rates),
                        currency,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildItemDetail(
                      'Current',
                      formatCurrency(currentValue, currency),
                    ),
                  ),
                  Expanded(
                    child: _buildItemDetail(
                      'P/L',
                      formatCurrency(profitLoss, currency, showSign: true),
                      valueColor: profitLoss >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemDetail(String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Add/Edit Portfolio Item Dialog
class AddPortfolioItemDialog extends ConsumerStatefulWidget {
  final Function(PortfolioItem) onSave;
  final PortfolioItem? existingItem;

  const AddPortfolioItemDialog({
    super.key,
    required this.onSave,
    this.existingItem,
  });

  bool get isEditing => existingItem != null;

  @override
  ConsumerState<AddPortfolioItemDialog> createState() =>
      _AddPortfolioItemDialogState();
}

class _AddPortfolioItemDialogState extends ConsumerState<AddPortfolioItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedMetal = 'Gold';
  int _selectedKarat = 24;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _selectedMetal = item.metal;
      _selectedKarat = item.karat;
      _weightController.text = item.weight.toString();
      _priceController.text = item.purchasePrice.toString();
      _selectedDate = item.purchaseDate;
      _notesController.text = item.notes ?? '';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedCurrency = ref.watch(selectedCurrencyProvider);
    final priceCurrencyLabel = widget.isEditing
        ? widget.existingItem!.purchaseCurrency
        : selectedCurrency;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.isEditing ? 'Edit Holding' : 'Add Holding',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Metal Selection
              RadioGroup<String>(
                groupValue: _selectedMetal,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedMetal = value;
                    if (value == 'Silver') {
                      _selectedKarat = 24; // Silver is always 24K
                    }
                  });
                },
                child: const Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Gold'),
                        value: 'Gold',
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text('Silver'),
                        value: 'Silver',
                      ),
                    ),
                  ],
                ),
              ),

              // Karat Selection (only for gold)
              if (_selectedMetal == 'Gold') ...[
                const SizedBox(height: 16),
                Text(
                  'Karat',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [24, 22, 21, 18].map((karat) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${karat}K'),
                          selected: _selectedKarat == karat,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedKarat = karat;
                              });
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),

              // Weight Input
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Weight (grams)',
                  prefixIcon: Icon(Icons.scale),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Purchase Price Input
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Purchase price per gram ($priceCurrencyLabel)',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter purchase price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Date Selection
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Purchase Date: ${_formatDate(_selectedDate)}'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                },
              ),

              // Notes Input
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final purchaseCurrency = widget.isEditing
                              ? widget.existingItem!.purchaseCurrency
                              : ref.read(selectedCurrencyProvider);
                          final item = PortfolioItem(
                            metal: _selectedMetal,
                            karat: _selectedKarat,
                            weight: double.parse(_weightController.text),
                            purchasePrice: double.parse(_priceController.text),
                            purchaseCurrency: purchaseCurrency,
                            purchaseDate: _selectedDate,
                            notes: _notesController.text.isEmpty
                                ? null
                                : _notesController.text,
                          );
                          widget.onSave(item);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VaultColors.gold,
                      ),
                      child: Text(
                        widget.isEditing ? 'Save' : 'Add',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
