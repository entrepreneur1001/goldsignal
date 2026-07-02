import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/design/app_colors.dart';
import '../../../../shared/providers/portfolio_analysis_provider.dart';
import '../../../chatbot/presentation/screens/chatbot_screen.dart';

/// AI portfolio analysis card for the Wallet tab.
class PortfolioAnalyzerCard extends ConsumerStatefulWidget {
  const PortfolioAnalyzerCard({
    super.key,
    required this.hasHoldings,
    required this.onAddHolding,
  });

  final bool hasHoldings;
  final VoidCallback onAddHolding;

  @override
  ConsumerState<PortfolioAnalyzerCard> createState() =>
      _PortfolioAnalyzerCardState();
}

class _PortfolioAnalyzerCardState extends ConsumerState<PortfolioAnalyzerCard> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.locale.languageCode;
    ref.read(portfolioAnalysisProvider.notifier).bindLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);
    final analysis = ref.watch(portfolioAnalysisProvider);
    final locale = context.locale.languageCode;

    if (!widget.hasHoldings) {
      return _buildEmptyCard(context, theme, c);
    }

    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(14),
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
                    context.tr('portfolio.ai_analyzer_title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (analysis.status == PortfolioAnalysisStatus.ready)
                  IconButton(
                    tooltip: context.tr('portfolio.ai_analyzer_refresh'),
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: analysis.isLoading
                        ? null
                        : () => ref
                            .read(portfolioAnalysisProvider.notifier)
                            .refresh(locale: locale),
                  ),
                IconButton(
                  icon: Icon(
                    analysis.expanded ? Icons.expand_less : Icons.expand_more,
                    color: c.textTertiary,
                  ),
                  onPressed: analysis.isLoading
                      ? null
                      : () => ref
                          .read(portfolioAnalysisProvider.notifier)
                          .toggleExpanded(),
                ),
              ],
            ),
            if (analysis.isLoading ||
                (analysis.status == PortfolioAnalysisStatus.idle &&
                    widget.hasHoldings)) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 6),
              Text(
                context.tr('portfolio.ai_analyzer_loading'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ] else if (analysis.status == PortfolioAnalysisStatus.error) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage(context, analysis.errorMessage),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: analysis.isLoading
                      ? null
                      : () => ref
                          .read(portfolioAnalysisProvider.notifier)
                          .retry(locale: locale),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(context.tr('common.retry')),
                ),
              ),
            ] else if (analysis.expanded &&
                analysis.status == PortfolioAnalysisStatus.ready) ...[
              const SizedBox(height: 8),
              Text(analysis.text, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                context.tr('portfolio.ai_analyzer_disclaimer'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: c.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'AIChat'),
                        builder: (_) => const ChatbotScreen(),
                      ),
                    );
                  },
                  child: Text(context.tr('portfolio.ai_analyzer_ask_more')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(
    BuildContext context,
    ThemeData theme,
    VaultColors c,
  ) {
    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(14),
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
                    context.tr('portfolio.ai_analyzer_empty_title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('portfolio.ai_analyzer_empty_message'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: widget.onAddHolding,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('portfolio.add_holding')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(BuildContext context, String? code) {
    if (code == 'missing_api_key') {
      return context.tr('portfolio.ai_analyzer_no_api_key');
    }
    if (code == 'refresh_limit') {
      return context.tr('portfolio.ai_analyzer_refresh_limit');
    }
    return context.tr('portfolio.ai_analyzer_error');
  }
}
