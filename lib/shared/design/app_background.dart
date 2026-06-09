import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Layered obsidian background with a soft radial gold glow at the top — the
/// signature "vault" backdrop. Wrap a screen body (under a transparent AppBar).
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showGlow;

  const AppBackground({super.key, required this.child, this.showGlow = true});

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final glowOpacity = c.brightness == Brightness.dark ? 0.12 : 0.06;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.bgSurface, c.bgBase],
          stops: const [0.0, 0.55],
        ),
      ),
      child: Stack(
        children: [
          if (showGlow)
            Positioned(
              top: -140,
              left: -60,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  height: 360,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.9,
                      colors: [
                        VaultColors.gold.withValues(alpha: glowOpacity),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
