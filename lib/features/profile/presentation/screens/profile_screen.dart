import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../shared/design/app_typography.dart';
import '../../../../shared/providers/app_info_provider.dart';
import '../../../../shared/models/local_market_prices.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../core/utils/app_localization.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../features/auth/presentation/screens/welcome_screen.dart';
import '../../../../features/auth/presentation/screens/sign_in_screen.dart';
import '../widgets/verify_email_banner.dart';
import '../../../alerts/presentation/screens/alerts_screen.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../../shared/providers/notification_permission_provider.dart';
import '../../../../core/notifications/notification_permission_ui.dart';
import '../widgets/widget_settings_sheet.dart';
import '../widgets/digest_settings_sheet.dart';
import 'package:share_plus/share_plus.dart';
import '../../../rating/presentation/rate_app_sheet.dart';
import '../../../feedback/presentation/submit_idea_sheet.dart';
import '../../../system/store_launcher.dart';
import 'edit_profile_screen.dart';
import '../../../../core/config/app_remote_config.dart';
import '../../../../shared/providers/app_config_provider.dart';
import '../../../../shared/providers/digest_provider.dart';
import '../../../../shared/providers/watchlist_alerts_provider.dart';
import '../../../../shared/widgets/native_ad_widget.dart';

/// TermsFeed-hosted privacy policy for Gold Signal.
final Uri _privacyPolicyUri = Uri.https(
  'www.termsfeed.com',
  '/live/d95900d3-ad0a-435c-ab8b-e6bdc8bf556f',
);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _shareApp() async {
    final config = ref.read(appRemoteConfigProvider) ?? const AppRemoteConfig();
    final url = storeUrl(config);
    await SharePlus.instance.share(
      ShareParams(
        text: context.tr('profile.share_text', namedArgs: {'url': url}),
        subject: 'GoldSignal',
      ),
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'EditProfile'),
        builder: (_) => const EditProfileScreen(),
      ),
    );
    await FirebaseAuth.instance.currentUser?.reload();
    if (mounted) {
      setState(() => _currentUser = FirebaseAuth.instance.currentUser);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('profile.delete_account')),
        content: Text(context.tr('profile.delete_account_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        await user.delete();
      }
      // Wipe local per-user data + reset in-memory providers post-deletion.
      await ref.read(authControllerProvider.notifier).wipeLocalUserData();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'Welcome'),
            builder: (_) => const WelcomeScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(context.tr('profile.delete_account_failed',
                namedArgs: {'error': '$e'}))));
      }
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('profile.sign_out')),
        content: Text(context.tr('profile.sign_out_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              // Clears Firebase session + wipes local per-user data and resets
              // the in-memory providers so nothing leaks to the next session.
              await ref.read(authControllerProvider.notifier).signOut();
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Welcome'),
                  builder: (_) => const WelcomeScreen(),
                ),
                (route) => false,
              );
            },
            child: Text(context.tr('profile.sign_out'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final ok = await launchUrl(
        _privacyPolicyUri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('profile.privacy_open_failed')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(context.tr('profile.link_open_failed',
                namedArgs: {'error': '$e'}))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCurrency = ref.watch(selectedCurrencyProvider);
    final isLocal = ref.watch(isLocalMarketProvider);
    final priceSide = ref.watch(priceSideProvider);
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('profile.title'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // User Info Card
                    Builder(
                      builder: (context) {
                        final isAnon = _currentUser?.isAnonymous ?? true;
                        final name = _currentUser?.displayName;
                        final hasName = name != null && name.isNotEmpty;
                        final title = isAnon
                            ? context.tr('profile.guest_user')
                            : (hasName
                                  ? name
                                  : (_currentUser?.email ??
                                      context.tr('profile.user')));
                        final subtitle = isAnon
                            ? context.tr('profile.sign_in_to_save')
                            : (hasName
                                  ? context.tr('profile.tap_edit')
                                  : context.tr('profile.tap_complete'));

                        final card = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: VaultColors.goldGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: VaultColors.goldGlow(
                              opacity: 0.28,
                              blur: 26,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                child: Icon(
                                  isAnon ? Icons.person_outline : Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAnon)
                                ElevatedButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                          name: 'SignIn',
                                        ),
                                        builder: (_) =>
                                            const SignInScreen(linkGuest: true),
                                      ),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _currentUser =
                                            FirebaseAuth.instance.currentUser;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: VaultColors.gold,
                                  ),
                                  child: Text(context.tr('sign_in')),
                                )
                              else
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                            ],
                          ),
                        );

                        if (isAnon) return card;
                        return InkWell(
                          onTap: _openEditProfile,
                          borderRadius: BorderRadius.circular(16),
                          child: card,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Soft email-verification nudge (hidden for guests / verified users)
              const VerifyEmailBanner(),

              const Divider(),

              _buildSectionHeader(context.tr('profile.preferences')),

              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(context.tr('profile.price_alerts')),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final count = ref.watch(priceAlertsProvider).activeCount;
                    return Text(
                      count == 0
                          ? context.tr('profile.no_active_alerts')
                          : context.plural('profile.active_alerts', count),
                    );
                  },
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'Alerts'),
                    builder: (_) => const AlertsScreen(),
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final permAsync = ref.watch(notificationPermissionProvider);
                  final isGranted = permAsync.value ?? false;
                  return SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: Text(context.tr('profile.notif_permission')),
                    subtitle: Text(context.tr('profile.notif_permission_sub')),
                    value: isGranted,
                    onChanged: permAsync.isLoading
                        ? null
                        : (value) async {
                            if (value) {
                              await enableNotifications(context, ref);
                            } else {
                              await showDisableInSettingsDialog(context);
                              await ref
                                  .read(notificationPermissionProvider.notifier)
                                  .refresh();
                            }
                          },
                  );
                },
              ),

              // Currency — synced with Prices screen via selectedCurrencyProvider
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text(context.tr('profile.currency')),
                subtitle: Text(
                  isLocal
                      ? context.tr('profile.currency_local_sub',
                          namedArgs: {'currency': selectedCurrency})
                      : selectedCurrency,
                ),
                onTap: _showCurrencySelector,
              ),

              // Language — drives the app-wide locale (en/ar/ur); Arabic flips
              // the UI to RTL automatically.
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.tr('profile.language')),
                subtitle: Text(
                  kLanguageNames[context.locale.languageCode] ?? 'English',
                ),
                onTap: _showLanguageSelector,
              ),

              if (isLocal)
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(context.tr('profile.price_side')),
                  subtitle: Text(
                    priceSide == PriceSide.sell
                        ? context.tr('profile.price_side_sell')
                        : context.tr('profile.price_side_buy'),
                  ),
                  trailing: Switch(
                    value: priceSide == PriceSide.sell,
                    onChanged: (isSell) {
                      ref
                          .read(priceSideProvider.notifier)
                          .setSide(isSell ? PriceSide.sell : PriceSide.buy);
                    },
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: Text(context.tr('profile.home_widget')),
                subtitle: Text(
                  context.tr('profile.home_widget_sub',
                      namedArgs: {'currency': selectedCurrency}),
                ),
                onTap: () => WidgetSettingsSheet.show(context),
              ),

              ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(context.tr('profile.watchlist_alerts')),
                subtitle: Text(context.tr('profile.watchlist_alerts_sub')),
                trailing: Switch(
                  value: ref.watch(watchlistAlertsProvider).enabled,
                  onChanged: (v) => ref
                      .read(watchlistAlertsProvider.notifier)
                      .setEnabled(v),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: Text(context.tr('profile.digest')),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final digest = ref.watch(digestProvider);
                    return Text(
                      digest.enabled
                          ? context.tr('profile.digest_on',
                              namedArgs: {'time': digest.formattedTime})
                          : context.tr('profile.digest_off'),
                    );
                  },
                ),
                onTap: () => DigestSettingsSheet.show(context),
              ),

              const Divider(),

              _buildSectionHeader(context.tr('profile.data_privacy')),

              // Privacy Policy — https://www.termsfeed.com/live/d95900d3-ad0a-435c-ab8b-e6bdc8bf556f
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text(context.tr('profile.privacy_policy')),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: _openPrivacyPolicy,
              ),

              const Divider(),

              _buildSectionHeader(context.tr('profile.about')),

              // Version — PackageInfo loaded in main() before runApp
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(context.tr('profile.version')),
                subtitle: Text(
                  '${packageInfo.version} (build ${packageInfo.buildNumber})',
                ),
              ),

              // Rate App
              ListTile(
                leading: const Icon(Icons.star_rate),
                title: Text(context.tr('profile.rate_app')),
                subtitle: Text(context.tr('profile.rate_app_sub')),
                onTap: () => RateAppSheet.show(context),
              ),

              // Share your idea
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(context.tr('profile.share_idea')),
                subtitle: Text(context.tr('profile.share_idea_sub')),
                onTap: () => SubmitIdeaSheet.show(context),
              ),

              // Share App
              ListTile(
                leading: const Icon(Icons.share),
                title: Text(context.tr('profile.share_app')),
                subtitle: Text(context.tr('profile.share_app_sub')),
                onTap: _shareApp,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: NativeAdWidget(),
              ),

              const SizedBox(height: 16),

              // Sign Out Button
              if (!(_currentUser?.isAnonymous ?? true))
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.tr('profile.sign_out'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Delete Account Button
              if (!(_currentUser?.isAnonymous ?? true))
                Center(
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: Text(
                      context.tr('profile.delete_account'),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.microLabel(
          VaultColors.of(Theme.of(context).brightness),
          languageCode: context.locale.languageCode,
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    final currentCode = context.locale.languageCode;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return ListView(
          shrinkWrap: true,
          children: kSupportedLocales.map((locale) {
            final code = locale.languageCode;
            return ListTile(
              title: Text(kLanguageNames[code] ?? code),
              trailing: currentCode == code
                  ? const Icon(Icons.check, color: VaultColors.gold)
                  : null,
              onTap: () {
                // setLocale persists the choice (easy_localization saveLocale)
                // and rebuilds the app, flipping to RTL for Arabic.
                context.setLocale(locale);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showCurrencySelector() {
    final currencies = ref.read(availableCurrenciesProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: currencies.length,
          itemBuilder: (context, index) {
            final currency = currencies[index];
            return ListTile(
              title: Text(currency),
              trailing: ref.watch(selectedCurrencyProvider) == currency
                  ? const Icon(Icons.check, color: VaultColors.gold)
                  : null,
              onTap: () {
                ref
                    .read(selectedCurrencyProvider.notifier)
                    .setCurrency(currency);
                ref.read(marketPricesControllerProvider.notifier).refresh();
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
