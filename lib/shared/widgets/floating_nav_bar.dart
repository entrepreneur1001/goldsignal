import 'dart:ui';
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_dimens.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem({required this.icon, required this.activeIcon, required this.label});
}

/// Floating, translucent (blurred) bottom navigation with an animated gold
/// active pill. Replaces the stock BottomNavigationBar.
class FloatingNavBar extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: AppDimens.navBlur, sigmaY: AppDimens.navBlur),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: c.bgElevated.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                border: Border.all(color: c.hairline),
                boxShadow: VaultColors.softShadow(c.brightness),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavCell(
                        item: items[i],
                        selected: i == currentIndex,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavCell({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimens.medium,
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          gradient: selected ? VaultColors.goldGradient : null,
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.05 : 1.0,
              duration: AppDimens.medium,
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: selected ? const Color(0xFF1A1410) : c.textTertiary,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 2),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1410),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
