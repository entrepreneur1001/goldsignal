import 'package:flutter/material.dart';
import '../../../../shared/design/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/portfolio_item.dart';
import '../../../../shared/models/savings_goal.dart';
import '../../../../shared/providers/portfolio_provider.dart';
import '../../../../shared/providers/savings_goals_provider.dart';
import '../../../../shared/widgets/ad_list_builder.dart';
import '../../../../shared/widgets/empty_state_with_ad.dart';
import '../../../../shared/widgets/native_ad_widget.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import 'package:easy_localization/easy_localization.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  /// Total grams of [metal] held across [items] (all karats).
  static double heldGrams(List<PortfolioItem> items, String metal) {
    double grams = 0;
    for (final item in items) {
      if (item.metal == metal) grams += item.weight;
    }
    return grams;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('savings.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!await requireAccount(context, 'savings_goals')) return;
          if (context.mounted) _AddGoalSheet.show(context);
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('savings.new_goal')),
      ),
      body: goals.isEmpty
          ? _buildEmpty(context)
          : _buildGoalsList(goals),
    );
  }

  Widget _buildGoalsList(List<SavingsGoal> goals) {
    final itemCount = adListItemCount(goals.length);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (adListIndexIsAd(index, goals.length)) {
          return const NativeAdWidget.list();
        }
        return _GoalCard(goal: goals[adListContentIndex(index, goals.length)]);
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWithAd(
      icon: Icons.savings_outlined,
      title: context.tr('savings.empty_title'),
      message: context.tr('savings.empty_msg'),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final SavingsGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(portfolioProvider).asData?.value ?? const [];
    final held = SavingsGoalsScreen.heldGrams(items, goal.metal);
    final ratio =
        goal.targetGrams > 0 ? (held / goal.targetGrams).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();
    final remaining = (goal.targetGrams - held).clamp(0.0, double.infinity);
    final isGold = goal.metal == 'Gold';
    final accent = isGold ? VaultColors.gold : const Color(0xFF9E9E9E);
    final complete = held >= goal.targetGrams;

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          ref.read(savingsGoalsProvider.notifier).deleteGoal(goal.id),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isGold ? Icons.diamond : Icons.circle, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.note?.isNotEmpty == true
                          ? goal.note!
                          : context.tr('savings.metal_savings', namedArgs: {
                              'metal': goal.metal == 'Gold'
                                  ? context.tr('charts.gold')
                                  : context.tr('charts.silver'),
                            }),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (complete)
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: accent.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('savings.progress', namedArgs: {
                      'held': _g(held),
                      'target': _g(goal.targetGrams),
                    }),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text('$percent%', style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                complete
                    ? context.tr('savings.goal_reached')
                    : context.tr('savings.to_go', namedArgs: {'grams': _g(remaining)}),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _g(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('savings.delete_title')),
        content: Text(context.tr('savings.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _AddGoalSheet(),
      ),
    );
  }

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  String _metal = 'Gold';
  final _targetController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  bool get _canSave => (double.tryParse(_targetController.text.trim()) ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    _targetController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    final target = double.tryParse(_targetController.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await ref.read(savingsGoalsProvider.notifier).addGoal(
            metal: _metal,
            targetGrams: target,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('savings.save_error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('savings.new_goal_title'),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'Gold', label: Text(context.tr('charts.gold'))),
                ButtonSegment(value: 'Silver', label: Text(context.tr('charts.silver'))),
              ],
              selected: {_metal},
              onSelectionChanged: (s) => setState(() => _metal = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('savings.target_label'),
                prefixIcon: const Icon(Icons.flag_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: context.tr('savings.name_label'),
                hintText: context.tr('savings.name_hint'),
                prefixIcon: const Icon(Icons.edit_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_canSave && !_saving) ? _save : null,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('savings.save_goal')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
