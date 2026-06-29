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
import '../widgets/widget_settings_sheet.dart';
import '../widgets/digest_settings_sheet.dart';
import 'package:share_plus/share_plus.dart';
import '../../../rating/presentation/rate_app_sheet.dart';
import '../../../feedback/presentation/submit_idea_sheet.dart';
import '../../../system/store_launcher.dart';
import '../../../../shared/providers/purchase_provider.dart';
import '../widgets/paywall_sheet.dart';
import 'edit_profile_screen.dart';
import '../../../../core/config/app_remote_config.dart';
import '../../../../shared/providers/app_config_provider.dart';
import '../../../../shared/providers/digest_provider.dart';

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
        text: 'Track live gold & silver prices, alerts and your portfolio '
            'with GoldSignal: $url',
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
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
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
          const SnackBar(
            content: Text('Could not open the privacy policy link.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
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
                      'Profile',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // User Info Card
                    Builder(builder: (context) {
                      final isAnon = _currentUser?.isAnonymous ?? true;
                      final name = _currentUser?.displayName;
                      final hasName = name != null && name.isNotEmpty;
                      final title = isAnon
                          ? 'Guest User'
                          : (hasName ? name : (_currentUser?.email ?? 'User'));
                      final subtitle = isAnon
                          ? 'Sign in to save your data'
                          : (hasName
                              ? 'Tap to edit your profile'
                              : 'Tap to complete your profile');

                      final card = Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: VaultColors.goldGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: VaultColors.goldGlow(opacity: 0.28, blur: 26),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
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
                                          name: 'SignIn'),
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
                                child: const Text('Sign In'),
                              )
                            else
                              const Icon(Icons.chevron_right,
                                  color: Colors.white),
                          ],
                        ),
                      );

                      if (isAnon) return card;
                      return InkWell(
                        onTap: _openEditProfile,
                        borderRadius: BorderRadius.circular(16),
                        child: card,
                      );
                    }),
                  ],
                ),
              ),

              // Soft email-verification nudge (hidden for guests / verified users)
              const VerifyEmailBanner(),

              const SizedBox(height: 8),

              // Pro upgrade / status
              Consumer(
                builder: (context, ref, _) {
                  final isPro = ref.watch(isProProvider);
                  if (isPro) {
                    return const ListTile(
                      leading: Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
                      title: Text('GoldSignal Pro'),
                      subtitle: Text('Ad-free experience active'),
                    );
                  }
                  return ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
                    title: const Text('GoldSignal Pro'),
                    subtitle: const Text('Temporarily unavailable'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => PaywallSheet.show(context),
                  );
                },
              ),

              const Divider(),

              _buildSectionHeader('Preferences'),

              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Price Alerts'),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final count = ref.watch(priceAlertsProvider).activeCount;
                    return Text(count == 0
                        ? 'No active alerts'
                        : '$count active alert${count == 1 ? '' : 's'}');
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
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification Permission'),
                subtitle: const Text('Required for price alert pop-ups'),
                onTap: () async {
                  await ref
                      .read(priceAlertsProvider.notifier)
                      .requestNotificationPermission();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification permission updated')),
                    );
                  }
                },
              ),

              // Currency — synced with Prices screen via selectedCurrencyProvider
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Currency'),
                subtitle: Text(
                  isLocal
                      ? '$selectedCurrency — Egypt local market (iSagha)'
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
                  title: const Text('Price Side'),
                  subtitle: Text(
                    priceSide == PriceSide.sell
                        ? 'Sell — price when buying from jeweler'
                        : 'Buy — price when selling to jeweler',
                  ),
                  trailing: Switch(
                    value: priceSide == PriceSide.sell,
                    onChanged: (isSell) {
                      ref.read(priceSideProvider.notifier).setSide(
                            isSell ? PriceSide.sell : PriceSide.buy,
                          );
                    },
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Home Screen Widget'),
                subtitle: Text(
                  'Metal & karat · currency follows $selectedCurrency',
                ),
                onTap: () => WidgetSettingsSheet.show(context),
              ),

              ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Daily Price Digest'),
                subtitle: Consumer(
                  builder: (context, ref, _) {
                    final digest = ref.watch(digestProvider);
                    return Text(digest.enabled
                        ? 'On · daily at ${digest.formattedTime}'
                        : 'Off');
                  },
                ),
                onTap: () => DigestSettingsSheet.show(context),
              ),

              const Divider(),

              _buildSectionHeader('Data & Privacy'),

              // Privacy Policy — https://www.termsfeed.com/live/d95900d3-ad0a-435c-ab8b-e6bdc8bf556f
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: _openPrivacyPolicy,
              ),

              const Divider(),

              _buildSectionHeader('About'),

              // Version — PackageInfo loaded in main() before runApp
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Version'),
                subtitle: Text(
                  '${packageInfo.version} (build ${packageInfo.buildNumber})',
                ),
              ),

              // Rate App
              ListTile(
                leading: const Icon(Icons.star_rate),
                title: const Text('Rate App'),
                subtitle: const Text('Help us improve'),
                onTap: () => RateAppSheet.show(context),
              ),

              // Share your idea
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Share Your Idea'),
                subtitle: const Text('Suggest a feature'),
                onTap: () => SubmitIdeaSheet.show(context),
              ),

              // Share App
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share App'),
                subtitle: const Text('Tell your friends'),
                onTap: _shareApp,
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
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
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
                    child: const Text(
                      'Delete Account',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
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
                ref.read(selectedCurrencyProvider.notifier).setCurrency(currency);
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
