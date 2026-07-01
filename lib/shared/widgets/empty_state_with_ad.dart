import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'native_ad_widget.dart';

/// Empty-state placeholder with a native ad slot below the message.
class EmptyStateWithAd extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const EmptyStateWithAd({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 88),
      child: Column(
        children: [
          EmptyState(
            icon: icon,
            title: title,
            message: message,
            action: action,
          ),
          const SizedBox(height: 24),
          const NativeAdWidget(),
        ],
      ),
    );
  }
}
