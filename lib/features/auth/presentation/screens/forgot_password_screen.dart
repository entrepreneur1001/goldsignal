import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';

/// Sends a Firebase password-reset email, then shows a confirmation state.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendReset(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final c = VaultColors.of(Theme.of(context).brightness);

    if (_sent) {
      return AuthScaffold(
        title: 'Check your inbox',
        subtitle:
            'We sent a password reset link to ${_emailController.text.trim()}',
        children: [
          Icon(Icons.mark_email_read_outlined, size: 56, color: VaultColors.gold),
          const SizedBox(height: AppDimens.space24),
          Text(
            'Open the link in the email to choose a new password, then sign in '
            'again. Be sure to check your spam folder.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.space32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Sign In'),
          ),
          TextButton(
            onPressed: isLoading ? null : () => setState(() => _sent = false),
            child: Text('Use a different email', style: TextStyle(color: c.textSecondary)),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Reset password',
      subtitle: "Enter your email and we'll send you a reset link",
      children: [
        Form(
          key: _formKey,
          child: AuthTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onFieldSubmitted: (_) => isLoading ? null : _submit(),
          ),
        ),
        const SizedBox(height: AppDimens.space24),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }
}
