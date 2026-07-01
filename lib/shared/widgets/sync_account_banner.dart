import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/utils/app_session.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../design/app_colors.dart';

/// One-time banner nudging guests to create an account after the 2nd session.
class SyncAccountBanner extends ConsumerStatefulWidget {
  const SyncAccountBanner({super.key});

  @override
  ConsumerState<SyncAccountBanner> createState() => _SyncAccountBannerState();
}

class _SyncAccountBannerState extends ConsumerState<SyncAccountBanner> {
  bool _visible = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) return;

    final sessions = await sessionCount();
    final dismissed = await isSyncBannerDismissed();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _visible = sessions >= 2 && !dismissed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: VaultColors.goldDeep.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_sync_outlined, color: VaultColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('growth.sync_banner_title'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('growth.sync_banner_body'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'SignUp'),
                          builder: (_) => const SignUpScreen(linkGuest: true),
                        ),
                      ),
                      child: Text(context.tr('auth.create_account')),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18, color: c.textTertiary),
                onPressed: () async {
                  await dismissSyncBanner();
                  if (mounted) setState(() => _visible = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
