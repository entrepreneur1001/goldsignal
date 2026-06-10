import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_dimens.dart';
import '../screens/sign_in_screen.dart';
import '../screens/sign_up_screen.dart';

/// Ensures the current user is a real (non-anonymous) account before a gated
/// action proceeds. Returns true if already signed in, or if the user signs
/// in / upgrades via the wall. Returns false if they dismiss it.
Future<bool> requireAccount(BuildContext context, String feature) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.isAnonymous) return true;

  await AuthWallSheet.show(context, feature: feature);

  final after = FirebaseAuth.instance.currentUser;
  return after != null && !after.isAnonymous;
}

/// In-context "sign in to continue" sheet shown when a guest taps a data
/// feature. Upgrades the anonymous user in place (same uid) on sign-up.
class AuthWallSheet extends StatelessWidget {
  const AuthWallSheet({super.key, required this.feature});

  /// Human-friendly feature name, e.g. "portfolio", "price alerts".
  final String feature;

  static Future<void> show(BuildContext context, {required String feature}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthWallSheet(feature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    Future<void> go(Widget screen) async {
      final navigator = Navigator.of(context);
      navigator.pop(); // close the sheet first
      await navigator.push(MaterialPageRoute(builder: (_) => screen));
    }

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: AppDimens.sheetRadius,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: VaultColors.goldGradient,
                  shape: BoxShape.circle,
                  boxShadow: VaultColors.goldGlow(opacity: 0.3, blur: 24),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: AppDimens.space16),
              Text(
                'Create a free account',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppDimens.space8),
              Text(
                'Sign in to save your $feature securely and sync it across your '
                'devices. It only takes a moment.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.space24),
              ElevatedButton(
                onPressed: () => go(const SignUpScreen(linkGuest: true)),
                child: const Text('Create Account'),
              ),
              const SizedBox(height: AppDimens.space12),
              OutlinedButton(
                onPressed: () => go(const SignInScreen(linkGuest: true)),
                child: const Text('Sign In'),
              ),
              const SizedBox(height: AppDimens.space8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Not now',
                    style: TextStyle(color: c.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
