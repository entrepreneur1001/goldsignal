import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_dimens.dart';

/// Base surface for the Vault UI: elevated color, hairline border, soft shadow
/// (or gold glow), rounded corners, and a subtle press-scale when tappable.
class VaultCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool glow;
  final Gradient? gradient;
  final BorderRadius borderRadius;

  const VaultCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.space16),
    this.onTap,
    this.glow = false,
    this.gradient,
    this.borderRadius = AppDimens.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? c.bgElevated : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(color: c.hairline),
        boxShadow:
            glow ? VaultColors.goldGlow() : VaultColors.softShadow(c.brightness),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return PressableScale(
      onTap: onTap!,
      borderRadius: borderRadius,
      child: content,
    );
  }
}

/// Wraps a child with a quick scale-down on press for tactile feedback.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = AppDimens.cardRadius,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? AppDimens.pressScale : 1.0,
        duration: AppDimens.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
