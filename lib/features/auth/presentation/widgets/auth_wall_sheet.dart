import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_dimens.dart';
import '../screens/sign_in_screen.dart';
import '../screens/sign_up_screen.dart';
import 'social_sign_in_buttons.dart';

/// Ensures the current user is a real (non-anonymous) account before a gated
/// action proceeds. [featureKey] is a translation key under `auth.features.*`.
Future<bool> requireAccount(BuildContext context, String featureKey) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.isAnonymous) return true;

  await AuthWallSheet.show(context, featureKey: featureKey);

  final after = FirebaseAuth.instance.currentUser;
  return after != null && !after.isAnonymous;
}

/// In-context "sign in to continue" sheet shown when a guest taps a data
/// feature. Upgrades the anonymous user in place (same uid) on sign-up.
class AuthWallSheet extends StatelessWidget {
  const AuthWallSheet({super.key, required this.featureKey});

  /// Key under `auth.features.*`, e.g. `portfolio`, `price_alerts`.
  final String featureKey;

  static Future<void> show(BuildContext context, {required String featureKey}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuthWallSheet(featureKey: featureKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    Future<void> go(String routeName, Widget screen) async {
      final navigator = Navigator.of(context);
      navigator.pop(); // close the sheet first
      await navigator.push(MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (_) => screen,
      ));
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
                context.tr('auth.wall_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppDimens.space8),
              Text(
                context.tr(
                  'auth.wall_message',
                  namedArgs: {
                    'feature': context.tr('auth.features.$featureKey'),
                  },
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.space24),
              ElevatedButton(
                onPressed: () => go('SignUp', const SignUpScreen(linkGuest: true)),
                child: Text(context.tr('auth.create_account')),
              ),
              const SizedBox(height: AppDimens.space12),
              OutlinedButton(
                onPressed: () => go('SignIn', const SignInScreen(linkGuest: true)),
                child: Text(context.tr('sign_in')),
              ),
              const SizedBox(height: AppDimens.space16),
              Row(
                children: [
                  Expanded(child: Divider(color: c.hairline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space16,
                    ),
                    child: Text(
                      context.tr('auth.or'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(child: Divider(color: c.hairline)),
                ],
              ),
              const SizedBox(height: AppDimens.space16),
              SocialSignInButtons(
                linkGuest: true,
                onSuccess: (_) => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppDimens.space8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('auth.not_now'),
                    style: TextStyle(color: c.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
