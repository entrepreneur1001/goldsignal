import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../widgets/auth_scaffold.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

/// Landing screen for unauthenticated users: Sign In, Create Account, or
/// Continue as Guest. Entry point of the auth flow.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _continueAsGuest(BuildContext context, WidgetRef ref) async {
    try {
      final user = await ref.read(authControllerProvider.notifier).signInAsGuest();
      if (user != null && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to continue as guest')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      showBack: false,
      title: 'Welcome to GoldSignal',
      subtitle: 'Track precious metals prices with AI insights',
      children: [
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  ),
          child: const Text('Sign In'),
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: AppDimens.space12),
        OutlinedButton(
          onPressed: isLoading
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  ),
          child: const Text('Create Account'),
        ).animate().fadeIn(delay: 400.ms),
        const SizedBox(height: AppDimens.space24),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.space16),
              child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: AppDimens.space24),
        TextButton.icon(
          onPressed: isLoading ? null : () => _continueAsGuest(context, ref),
          icon: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_outline),
          label: const Text('Continue as Guest'),
        ).animate().fadeIn(delay: 600.ms),
      ],
    );
  }
}
