import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/providers/auth_provider.dart';

/// Google (and Apple on iOS) sign-in buttons shared across auth screens.
class SocialSignInButtons extends ConsumerWidget {
  const SocialSignInButtons({
    super.key,
    this.linkGuest = false,
    required this.onSuccess,
  });

  final bool linkGuest;
  final void Function(User user) onSuccess;

  Future<void> _handleSocialSignIn(
    BuildContext context,
    WidgetRef ref,
    Future<User?> Function({bool linkGuest}) action,
    String failureKey,
  ) async {
    try {
      final user = await action(linkGuest: linkGuest);
      if (user == null || !context.mounted) return;
      onSuccess(user);
    } catch (e) {
      if (!context.mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? context.tr(failureKey) : message,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final showApple = Platform.isIOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: isLoading
              ? null
              : () => _handleSocialSignIn(
                    context,
                    ref,
                    ref.read(authControllerProvider.notifier).signInWithGoogle,
                    'auth.google_failed',
                  ),
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: Text(context.tr('auth.continue_google')),
        ),
        if (showApple) ...[
          const SizedBox(height: AppDimens.space12),
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : () => _handleSocialSignIn(
                      context,
                      ref,
                      ref.read(authControllerProvider.notifier).signInWithApple,
                      'auth.apple_failed',
                    ),
            icon: const Icon(Icons.apple),
            label: Text(context.tr('auth.continue_apple')),
          ),
        ],
      ],
    );
  }
}
