import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/local_market/local_market_config.dart';
import '../../../../shared/models/local_market_prices.dart';
import '../../../../shared/models/price_alert.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import 'package:easy_localization/easy_localization.dart';

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
  bool _use24hPercent = false;
  AlertCondition _condition = AlertCondition.above;
  final _targetController = TextEditingController();
  bool _saving = false;
  bool _autoRepeat = false;
  int _repeatAfterHours = 24;
  bool _initialized = false;

  // Values are translation keys, resolved at render time.
  static const _repeatOptions = <int, String>{
    1: 'alerts.repeat_1h',
    6: 'alerts.repeat_6h',
    24: 'alerts.repeat_24h',
    168: 'alerts.repeat_1w',
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
    _side = LocalMarketConfig.hasBuySellSide(defaults.currency)
        ? defaults.side
        : null;
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
      return LocalMarketConfig.goldKarats(_currency);
    }
    return LocalMarketConfig.silverKarats(_currency);
  }

  PriceAlert get _previewAlert => PriceAlert(
        id: 'preview',
        metal: _metal,
        karat: _karat,
        currency: _currency,
        side: LocalMarketConfig.hasBuySellSide(_currency)
            ? (_side ?? PriceSide.sell)
            : null,
        type: _type,
        condition: _condition,
        targetValue: 0,
        createdAt: DateTime.now(),
      );

  Future<void> _submit() async {
    if (_saving) return;
    if (!await requireAccount(context, 'price_alerts')) return;
    if (!mounted) return;

    final target = double.tryParse(_targetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_type == AlertType.price
              ? context.tr('alerts.snack_invalid_price')
              : context.tr('alerts.snack_invalid_percent')),
        ),
      );
      return;
    }

    if (_type == AlertType.percentChange && target > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('alerts.snack_percent_max'))),
      );
      return;
    }

    setState(() => _saving = true);
    final alertType = _type == AlertType.percentChange && _use24hPercent
        ? AlertType.percentChange24h
        : _type;

    try {
      await ref.read(priceAlertsProvider.notifier).requestNotificationPermission();
      await ref.read(priceAlertsProvider.notifier).createAlert(
            metal: _metal,
            karat: _karat,
            currency: _currency,
            side: _side,
            type: alertType,
            condition: _condition,
            targetValue: target,
            repeatAfterHours: _autoRepeat ? _repeatAfterHours : null,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('alerts.saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('alerts.save_failed'))),
        );
      }
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
          Text(context.tr('alerts.create_alert'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<AlertType>(
            segments: [
              ButtonSegment(
                value: AlertType.price,
                label: Text(context.tr('alerts.type_price')),
                icon: const Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: AlertType.percentChange,
                label: Text(context.tr('alerts.type_percent')),
                icon: const Icon(Icons.trending_up),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type == AlertType.percentChange) {
                _targetController.text = '2';
              } else {
                _use24hPercent = false;
                if (preview != null) {
                  _targetController.text = preview.toStringAsFixed(2);
                }
              }
            }),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'gold', label: Text(context.tr('charts.gold'))),
              ButtonSegment(value: 'silver', label: Text(context.tr('charts.silver'))),
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
          if (LocalMarketConfig.hasBuySellSide(_currency)) ...[
            const SizedBox(height: 12),
            SegmentedButton<PriceSide>(
              segments: [
                ButtonSegment(value: PriceSide.sell, label: Text(context.tr('charts.sell'))),
                ButtonSegment(value: PriceSide.buy, label: Text(context.tr('charts.buy'))),
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
                label: Text(_type == AlertType.price
                    ? context.tr('alerts.cond_above')
                    : context.tr('alerts.cond_up')),
              ),
              ButtonSegment(
                value: AlertCondition.below,
                label: Text(_type == AlertType.price
                    ? context.tr('alerts.cond_below')
                    : context.tr('alerts.cond_down')),
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
                  ? context.tr('alerts.target_price_label',
                      namedArgs: {'currency': _currency})
                  : context.tr('alerts.percent_label'),
              suffixText: _type == AlertType.percentChange ? '%' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_type == AlertType.percentChange) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(context.tr('alerts.from_now'))),
                ButtonSegment(value: true, label: Text(context.tr('alerts.market_24h'))),
              ],
              selected: {_use24hPercent},
              onSelectionChanged: (s) =>
                  setState(() => _use24hPercent = s.first),
            ),
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
              context.tr('alerts.current', namedArgs: {
                'price': preview.toStringAsFixed(2),
                'currency': _currency,
              }),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_type == AlertType.percentChange && !_use24hPercent)
              Text(
                context.tr('alerts.baseline_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_type == AlertType.percentChange && _use24hPercent)
              Text(
                context.tr('alerts.use_24h_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 8),
          Text(
            LocalMarketConfig.isLocalCurrency(_currency)
                ? (_currency == 'INR'
                    ? context.tr('alerts.local_note_india')
                    : context.tr('alerts.egp_note'))
                : context.tr('alerts.global_note',
                    namedArgs: {'currency': _currency}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('alerts.auto_repeat')),
            subtitle: Text(context.tr('alerts.auto_repeat_sub')),
            value: _autoRepeat,
            onChanged: (v) => setState(() => _autoRepeat = v),
          ),
          if (_autoRepeat) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: _repeatOptions.entries.map((entry) {
                return ChoiceChip(
                  label: Text(context.tr(entry.value)),
                  selected: _repeatAfterHours == entry.key,
                  onSelected: (_) =>
                      setState(() => _repeatAfterHours = entry.key),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('alerts.save_alert')),
          ),
          ],
        ),
      ),
    );
  }
}
