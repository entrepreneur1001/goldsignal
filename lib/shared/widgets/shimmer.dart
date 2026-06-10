import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../design/app_colors.dart';
import '../design/app_dimens.dart';

/// A shimmering placeholder block for skeleton loading states.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.bgSurface, borderRadius: borderRadius),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1200.ms,
          color: VaultColors.gold.withValues(alpha: 0.08),
        );
  }
}

/// Skeleton placeholder shaped like a [PriceCard] / metal card.
class PriceCardSkeleton extends StatelessWidget {
  const PriceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerBox(
                width: 38,
                height: 38,
                borderRadius: BorderRadius.all(Radius.circular(19)),
              ),
              SizedBox(width: 12),
              ShimmerBox(width: 90, height: 12),
              Spacer(),
              ShimmerBox(
                width: 56,
                height: 22,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
          SizedBox(height: 18),
          ShimmerBox(width: 160, height: 32),
          SizedBox(height: 10),
          ShimmerBox(width: 64, height: 12),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 30)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(height: 30)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A vertical stack of [PriceCardSkeleton]s for a loading list.
class PriceListSkeleton extends StatelessWidget {
  final int count;
  const PriceListSkeleton({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, _) => const PriceCardSkeleton(),
    );
  }
}
