import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'sign_in_screen.dart';

/// Create a new email/password account. When [linkGuest] is true an anonymous
/// guest is upgraded in place (same uid — Firestore data carries over). A
/// verification link is sent automatically on success (soft verification).
class SignUpScreen extends ConsumerStatefulWidget {
  final bool linkGuest;

  const SignUpScreen({super.key, this.linkGuest = false});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    try {
      final user = widget.linkGuest
          ? await controller.convertGuest(email, password)
          : await controller.signUp(email, password);
      if (user == null || !mounted) return;

      if (name.isNotEmpty) {
        await ref.read(authServiceProvider).updateProfile(name: name);
      }

      if (widget.linkGuest) {
        // Same uid as the anonymous session — Firestore data carries over.
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created — check your inbox to verify your email'),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'Dashboard'),
              builder: (_) => const DashboardScreen(),
            ),
          );
        }
      }
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

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Save your portfolio, alerts and preferences',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                controller: _nameController,
                label: 'Name (optional)',
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: AppDimens.space16),
              AuthTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: AppDimens.space16),
              AuthTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword,
              ),
              const SizedBox(height: AppDimens.space16),
              AuthTextField(
                controller: _confirmController,
                label: 'Confirm password',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    Validators.confirmPassword(v, _passwordController.text),
                onFieldSubmitted: (_) => isLoading ? null : _submit(),
              ),
            ],
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
              : const Text('Create Account'),
        ),
        const SizedBox(height: AppDimens.space16),
        TextButton(
          onPressed: isLoading
              ? null
              : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'SignIn'),
                      builder: (_) => SignInScreen(linkGuest: widget.linkGuest),
                    ),
                  ),
          child: const Text('Already have an account? Sign In'),
        ),
      ],
    );
  }
}
