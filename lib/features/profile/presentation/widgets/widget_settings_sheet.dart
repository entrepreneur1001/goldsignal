import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widget/home_widget_service.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/widget_preferences_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class WidgetSettingsSheet extends ConsumerStatefulWidget {
  const WidgetSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: WidgetSettingsSheet(),
      ),
    );
  }

  @override
  ConsumerState<WidgetSettingsSheet> createState() =>
      _WidgetSettingsSheetState();
}

class _WidgetSettingsSheetState extends ConsumerState<WidgetSettingsSheet> {
  bool? _pinSupported;

  @override
  void initState() {
    super.initState();
    HomeWidgetService.instance.isPinSupported().then((supported) {
      if (mounted) setState(() => _pinSupported = supported);
    });
  }

  Future<void> _syncWidget() async {
    ref.read(marketPricesControllerProvider.notifier).applyCurrentPrices();
  }

  Future<void> _requestPin() async {
    await HomeWidgetService.instance.requestPin();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('profile.widget_pin_confirm')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(selectedCurrencyProvider);
    final prefs = ref.watch(widgetPreferencesProvider);
    final notifier = ref.read(widgetPreferencesProvider.notifier);
    final board = ref.watch(widgetBoardProvider);
    final goldOptions = karatOptionsFor(metal: 'gold', currency: currency);
    final silverOptions = karatOptionsFor(metal: 'silver', currency: currency);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('profile.widget_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.attach_money),
              title: Text(context.tr('profile.widget_currency',
                  namedArgs: {'currency': currency})),
              subtitle: Text(context.tr('profile.widget_currency_sub')),
            ),
            const SizedBox(height: 12),
            _KaratPicker(
              label: context.tr('profile.widget_gold_karat'),
              options: goldOptions,
              selected: prefs.goldKarat,
              labelFor: (k) => '${k}K',
              onSelected: (k) async {
                await notifier.setGoldKarat(k);
                await _syncWidget();
              },
            ),
            const SizedBox(height: 12),
            _KaratPicker(
              label: context.tr('profile.widget_silver_karat'),
              options: silverOptions,
              selected: prefs.silverKarat,
              labelFor: (k) => k,
              onSelected: (k) async {
                await notifier.setSilverKarat(k);
                await _syncWidget();
              },
            ),
            if (board != null && !board.isEmpty) ...[
              const SizedBox(height: 16),
              _WidgetPreviewCard(board: board),
            ],
            const SizedBox(height: 12),
            Text(
              currency == 'EGP'
                  ? context.tr('profile.widget_egp_note')
                  : context.tr('profile.widget_global_note',
                      namedArgs: {'currency': currency}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_pinSupported == true) ...[
              FilledButton.icon(
                onPressed: _requestPin,
                icon: const Icon(Icons.add_to_home_screen),
                label: Text(context.tr('profile.widget_add_home')),
              ),
              const SizedBox(height: 8),
            ],
            if (_pinSupported != true)
              Text(
                context.tr('profile.widget_add_manual'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _KaratPicker extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final String Function(String) labelFor;
  final ValueChanged<String> onSelected;

  const _KaratPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.map((k) {
            return ChoiceChip(
              label: Text(labelFor(k)),
              selected: selected == k,
              onSelected: (_) => onSelected(k),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// A faithful preview of the home-screen widget rendered inside the sheet.
class _WidgetPreviewCard extends StatelessWidget {
  final WidgetBoardData board;

  const _WidgetPreviewCard({required this.board});

  static const _cardColor = Color(0xFF161618);
  static const _muted = Color(0xFF9A9AA2);
  static const _green = Color(0xFF2EBD85);
  static const _red = Color(0xFFF6465D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'GoldSignal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                board.currency,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const Spacer(),
              const Icon(Icons.refresh, color: _muted, size: 16),
              const SizedBox(width: 10),
              const Icon(Icons.settings, color: _muted, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: Color(0xFF2A2A2E), height: 16),
          if (board.gold != null) _row(board.gold!, board.currency),
          if (board.gold != null && board.silver != null)
            const SizedBox(height: 12),
          if (board.silver != null) _row(board.silver!, board.currency),
        ],
      ),
    );
  }

  Widget _row(WidgetMetalRow row, String currency) {
    final isGold = row.metal == 'gold';
    final changeColor = row.isPositive ? _green : _red;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGold ? const Color(0xFFF5B301) : const Color(0xFFB9BDC6),
          ),
          child: Icon(
            isGold ? Icons.star : Icons.circle,
            size: 16,
            color: isGold ? const Color(0xFF3A2B00) : const Color(0xFF3A3C42),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              '$currency / gram',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              row.formattedPrice,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              '${row.formattedChange}  ${row.formattedChangePercent}',
              style: TextStyle(color: changeColor, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
