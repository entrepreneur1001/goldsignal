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
    final preview = ref.watch(widgetDisplayProvider);
    final karatOptions =
        karatOptionsFor(metal: prefs.metal, currency: currency);

    return Padding(
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
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'gold', label: Text(context.tr('charts.gold'))),
              ButtonSegment(value: 'silver', label: Text(context.tr('charts.silver'))),
            ],
            selected: {prefs.metal},
            onSelectionChanged: (s) async {
              await notifier.setMetal(s.first);
              await _syncWidget();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: karatOptions.map((k) {
              final label = prefs.metal == 'gold' ? '${k}K' : k;
              return ChoiceChip(
                label: Text(label),
                selected: prefs.karat == k,
                onSelected: (_) async {
                  await notifier.setKarat(k);
                  await _syncWidget();
                },
              );
            }).toList(),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('profile.widget_preview', namedArgs: {
                'label': preview.label,
                'price': preview.pricePerGram.toStringAsFixed(2),
                'currency': preview.currency,
                'change': preview.formattedChangePercent,
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
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
    );
  }
}
