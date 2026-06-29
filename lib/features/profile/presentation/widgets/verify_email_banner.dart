import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/providers/auth_provider.dart';
import 'package:easy_localization/easy_localization.dart';

/// Soft-verification nudge shown in Profile for signed-in (non-guest) users
/// whose email is not yet verified. Lets them resend the link or re-check after
/// clicking it. Renders nothing once verified.
class VerifyEmailBanner extends ConsumerStatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  ConsumerState<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends ConsumerState<VerifyEmailBanner> {
  bool _busy = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _verified = ref.read(authServiceProvider).isEmailVerified;
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    // Resolve before the async gap to avoid using context across an await.
    final sentMsg = context.tr('profile.verify_sent');
    try {
      await ref.read(authControllerProvider.notifier).resendVerification();
      _toast(sentMsg);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    // Resolve before the async gap to avoid using context across an await.
    final doneMsg = context.tr('profile.verify_done');
    final notYetMsg = context.tr('profile.verify_not_yet');
    try {
      final verified =
          await ref.read(authControllerProvider.notifier).refreshVerification();
      if (mounted) setState(() => _verified = verified);
      _toast(verified ? doneMsg : notYetMsg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(authServiceProvider);
    final user = service.currentUser;
    // Only relevant for a registered (non-anonymous) user that isn't verified.
    if (user == null || user.isAnonymous || _verified) {
      return const SizedBox.shrink();
    }

    final c = VaultColors.of(Theme.of(context).brightness);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.space16),
      padding: const EdgeInsets.all(AppDimens.space16),
      decoration: BoxDecoration(
        color: VaultColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: VaultColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_outlined,
                  color: VaultColors.goldDeep),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Text(
                  context.tr('profile.verify_email_title'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: c.textPrimary),
                ),
              ),
              if (_busy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.space4),
          Text(
            context.tr('profile.verify_email_body', namedArgs: {
              'email': user.email ?? context.tr('profile.verify_email_default'),
            }),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.space8),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : _check,
                child: Text(context.tr('profile.ive_verified')),
              ),
              TextButton(
                onPressed: _busy ? null : _resend,
                child: Text(context.tr('profile.resend'),
                    style: TextStyle(color: c.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
