import 'package:flutter/material.dart';
import '../design/app_dimens.dart';

/// Animates (count-up / odometer) to [value] whenever it changes, formatting
/// the interpolated number via [formatter]. Great for prices / totals.
class AnimatedValue extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  const AnimatedValue({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = AppDimens.medium,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(
        formatter(v),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}
