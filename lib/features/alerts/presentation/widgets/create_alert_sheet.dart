import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/local_market_prices.dart';
import '../../../../shared/models/price_alert.dart';
import '../../../../shared/providers/price_alerts_provider.dart';

class CreateAlertSheet extends ConsumerStatefulWidget {
  final AlertDraft? draft;

  const CreateAlertSheet({super.key, this.draft});

  static Future<void> show(BuildContext context, {AlertDraft? draft}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: CreateAlertSheet(draft: draft),
      ),
    );
  }

  @override
  ConsumerState<CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends ConsumerState<CreateAlertSheet> {
  String _metal = 'gold';
  String _karat = '24';
  String _currency = 'USD';
  PriceSide? _side;
  AlertType _type = AlertType.price;
  AlertCondition _condition = AlertCondition.above;
  final _targetController = TextEditingController();
  bool _autoRepeat = false;
  int _repeatAfterHours = 24;
  bool _initialized = false;

  static const _repeatOptions = <int, String>{
    1: '1 hour',
    6: '6 hours',
    24: '24 hours',
    168: '1 week',
  };

  void _initFromDraftOrDefaults() {
    if (_initialized) return;
    _initialized = true;

    final draft = widget.draft;
    if (draft != null) {
      _metal = draft.metal;
      _karat = draft.karat;
      _currency = draft.currency;
      _side = draft.side;
      _targetController.text = draft.pricePerGram.toStringAsFixed(2);
      return;
    }

    final defaults = ref.read(alertFormDefaultsProvider);
    _metal = defaults.metal;
    _karat = defaults.karat;
    _currency = defaults.currency;
    _side = defaults.currency == 'EGP' ? defaults.side : null;
    if (defaults.currentPerGram != null) {
      _targetController.text = defaults.currentPerGram!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  List<String> get _karatOptions {
    if (_metal == 'gold') {
      return ['24', '22', '21', '18'];
    }
    return _currency == 'EGP' ? ['999', '925', '900', '800'] : ['999'];
  }

  PriceAlert get _previewAlert => PriceAlert(
        id: 'preview',
        metal: _metal,
        karat: _karat,
        currency: _currency,
        side: _currency == 'EGP' ? (_side ?? PriceSide.sell) : null,
        type: _type,
        condition: _condition,
        targetValue: 0,
        createdAt: DateTime.now(),
      );

  Future<void> _submit() async {
    final target = double.tryParse(_targetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_type == AlertType.price
              ? 'Enter a valid target price per gram'
              : 'Enter a valid percent change'),
        ),
      );
      return;
    }

    if (_type == AlertType.percentChange && target > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percent change must be 100% or less')),
      );
      return;
    }

    await ref.read(priceAlertsProvider.notifier).requestNotificationPermission();
    await ref.read(priceAlertsProvider.notifier).createAlert(
          metal: _metal,
          karat: _karat,
          currency: _currency,
          side: _side,
          type: _type,
          condition: _condition,
          targetValue: target,
          repeatAfterHours: _autoRepeat ? _repeatAfterHours : null,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert saved')),
      );
    }
  }

  void _setPercentPreset(double value) {
    setState(() => _targetController.text = value.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    _initFromDraftOrDefaults();
    final preview = ref.read(priceAlertsProvider.notifier).resolveCurrentPrice(
          _previewAlert,
        );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text('Create alert', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<AlertType>(
            segments: const [
              ButtonSegment(
                value: AlertType.price,
                label: Text('Price'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: AlertType.percentChange,
                label: Text('% Change'),
                icon: Icon(Icons.trending_up),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type == AlertType.percentChange) {
                _targetController.text = '2';
              } else if (preview != null) {
                _targetController.text = preview.toStringAsFixed(2);
              }
            }),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'gold', label: Text('Gold')),
              ButtonSegment(value: 'silver', label: Text('Silver')),
            ],
            selected: {_metal},
            onSelectionChanged: (s) => setState(() {
              _metal = s.first;
              if (!_karatOptions.contains(_karat)) _karat = _karatOptions.first;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _karatOptions.map((k) {
              final label = _metal == 'gold' ? '${k}K' : k;
              return ChoiceChip(
                label: Text(label),
                selected: _karat == k,
                onSelected: (_) => setState(() => _karat = k),
              );
            }).toList(),
          ),
          if (_currency == 'EGP') ...[
            const SizedBox(height: 12),
            SegmentedButton<PriceSide>(
              segments: const [
                ButtonSegment(value: PriceSide.sell, label: Text('Sell')),
                ButtonSegment(value: PriceSide.buy, label: Text('Buy')),
              ],
              selected: {_side ?? PriceSide.sell},
              onSelectionChanged: (s) => setState(() => _side = s.first),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<AlertCondition>(
            segments: [
              ButtonSegment(
                value: AlertCondition.above,
                label: Text(_type == AlertType.price ? 'Above' : 'Up'),
              ),
              ButtonSegment(
                value: AlertCondition.below,
                label: Text(_type == AlertType.price ? 'Below' : 'Down'),
              ),
            ],
            selected: {_condition},
            onSelectionChanged: (s) => setState(() => _condition = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == AlertType.price
                  ? 'Target price per gram ($_currency)'
                  : 'Percent change from current price',
              suffixText: _type == AlertType.percentChange ? '%' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_type == AlertType.percentChange) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in [1.0, 2.0, 5.0, 10.0])
                  ActionChip(
                    label: Text('${preset.toStringAsFixed(0)}%'),
                    onPressed: () => _setPercentPreset(preset),
                  ),
              ],
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 8),
            Text(
              'Current: ${preview.toStringAsFixed(2)} $_currency/g',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_type == AlertType.percentChange)
              Text(
                'Baseline is set to the current price when you save',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 8),
          Text(
            _currency == 'EGP'
                ? 'Uses Egypt local iSagha prices'
                : 'Uses global spot prices in $_currency',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-repeat'),
            subtitle: const Text(
              'Re-arm this alert automatically after it triggers',
            ),
            value: _autoRepeat,
            onChanged: (v) => setState(() => _autoRepeat = v),
          ),
          if (_autoRepeat) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: _repeatOptions.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _repeatAfterHours == entry.key,
                  onSelected: (_) =>
                      setState(() => _repeatAfterHours = entry.key),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('Save alert'),
          ),
          ],
        ),
      ),
    );
  }
}
