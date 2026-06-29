import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';
import 'package:easy_localization/easy_localization.dart';

/// Email + password sign-in. When [linkGuest] is true the screen is reached
/// from a guest upgrading their account; on success it simply pops back so the
/// gated action can continue (data lives in Firestore under the user's uid).
class SignInScreen extends ConsumerStatefulWidget {
  final bool linkGuest;

  const SignInScreen({super.key, this.linkGuest = false});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    try {
      final user = await controller.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (user == null || !mounted) return;

      if (widget.linkGuest) {
        // Reached from a gated action — pop back so it can continue.
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'Dashboard'),
            builder: (_) => const DashboardScreen(),
          ),
        );
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
      title: widget.linkGuest
          ? context.tr('auth.link_title')
          : context.tr('auth.welcome_back'),
      subtitle: widget.linkGuest
          ? context.tr('auth.link_subtitle')
          : context.tr('auth.signin_subtitle'),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                controller: _emailController,
                label: context.tr('email'),
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: AppDimens.space16),
              AuthTextField(
                controller: _passwordController,
                label: context.tr('password'),
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.password,
                onFieldSubmitted: (_) => isLoading ? null : _submit(),
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: isLoading
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'ForgotPassword'),
                        builder: (_) => ForgotPasswordScreen(
                          initialEmail: _emailController.text.trim(),
                        ),
                      ),
                    ),
            child: Text(context.tr('forgot_password')),
          ),
        ),
        const SizedBox(height: AppDimens.space8),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('sign_in')),
        ),
        const SizedBox(height: AppDimens.space16),
        TextButton(
          onPressed: isLoading
              ? null
              : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: 'SignUp'),
                      builder: (_) => SignUpScreen(linkGuest: widget.linkGuest),
                    ),
                  ),
          child: Text(context.tr('auth.no_account')),
        ),
      ],
    );
  }
}
