import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// Up/down change chip: arrow + signed percentage, tinted green/red, tabular.
class DeltaPill extends StatelessWidget {
  final double percent;
  final bool showArrow;
  final bool compact;

  const DeltaPill({
    super.key,
    required this.percent,
    this.showArrow = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final up = percent >= 0;
    final color = up ? VaultColors.up : VaultColors.down;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showArrow)
            Icon(
              up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: compact ? 11 : 13,
              color: color,
            ),
          const SizedBox(width: 2),
          Text(
            '${up ? '+' : ''}${percent.toStringAsFixed(2)}%',
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
