import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../design/app_colors.dart';
import '../providers/daily_insight_provider.dart';
import '../../features/chatbot/presentation/screens/chatbot_screen.dart';

/// Collapsible daily market summary at the top of Markets.
class DailyInsightCard extends ConsumerWidget {
  const DailyInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(dailyInsightProvider);
    if (!insight.isLoading && insight.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: insight.isLoading ? null : () => ref.read(dailyInsightProvider.notifier).toggleExpanded(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: VaultColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('growth.todays_move'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    insight.expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: c.textTertiary,
                  ),
                ],
              ),
              if (insight.isLoading) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ] else if (insight.expanded) ...[
                const SizedBox(height: 8),
                Text(insight.text, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () {
                      // Switch to AI tab is handled by parent nav; open AI with prompt.
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'AIChat'),
                          builder: (_) => const ChatbotScreen(),
                        ),
                      );
                    },
                    child: Text(context.tr('growth.ask_ai_more')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
