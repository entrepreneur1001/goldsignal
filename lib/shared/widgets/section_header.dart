import 'package:flutter/material.dart';
import '../design/app_typography.dart';
import '../design/app_colors.dart';

/// Consistent uppercase section label with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final languageCode = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTypography.microLabel(c, languageCode: languageCode),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
