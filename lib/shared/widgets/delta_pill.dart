import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// Up/down change chip: arrow + signed percentage, tinted green/red, tabular.
/// Null [percent] renders a neutral gray "—" (unknown baseline).
class DeltaPill extends StatelessWidget {
  final double? percent;
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
    final c = VaultColors.of(Theme.of(context).brightness);

    if (percent == null) {
      return _pill(
        c.textTertiary.withValues(alpha: 0.14),
        c.textTertiary,
        '—',
        showArrow: false,
      );
    }

    if (percent == 0) {
      return _pill(
        c.textTertiary.withValues(alpha: 0.14),
        c.textTertiary,
        '0.00%',
        showArrow: false,
      );
    }

    final up = percent! > 0;
    final color = up ? VaultColors.up : VaultColors.down;
    return _pill(
      color.withValues(alpha: 0.14),
      color,
      '${up ? '+' : ''}${percent!.toStringAsFixed(2)}%',
      showArrow: showArrow,
      up: up,
    );
  }

  Widget _pill(
    Color bg,
    Color fg,
    String text, {
    required bool showArrow,
    bool up = true,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showArrow)
            Icon(
              up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: compact ? 11 : 13,
              color: fg,
            ),
          if (showArrow) const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: fg,
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
