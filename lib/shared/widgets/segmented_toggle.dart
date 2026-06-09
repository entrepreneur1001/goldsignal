import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_dimens.dart';

class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption(this.value, this.label);
}

/// Gold pill segmented control (Global/Egypt, Buy/Sell, nisab basis, …).
class SegmentedToggle<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o.value),
                child: AnimatedContainer(
                  duration: AppDimens.fast,
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient:
                        o.value == selected ? VaultColors.goldGradient : null,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                  child: Center(
                    child: Text(
                      o.label,
                      style: text.labelMedium?.copyWith(
                        color: o.value == selected
                            ? const Color(0xFF1A1410)
                            : c.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
