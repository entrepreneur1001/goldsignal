import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_dimens.dart';

/// Shared chrome for the auth screens: a gold "vault" coin badge, a title +
/// subtitle, then the screen's body. Keeps Welcome / Sign In / Sign Up /
/// Forgot Password visually consistent with the rest of the Vault UI.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: c.textPrimary),
            )
          : null,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(child: _coinBadge()),
              const SizedBox(height: AppDimens.space24),
              Text(
                title,
                style: theme.textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: AppDimens.space8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: AppDimens.space32),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _coinBadge() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        gradient: VaultColors.goldGradient,
        shape: BoxShape.circle,
        boxShadow: VaultColors.goldGlow(opacity: 0.3, blur: 28),
      ),
      child: const Icon(Icons.monetization_on, size: 52, color: Colors.white),
    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack);
  }
}
