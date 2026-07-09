import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../../core/utils/app_localization.dart';
import '../../../../core/utils/app_locale.dart';
import '../../../../core/utils/app_session.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../../shared/design/app_dimens.dart';
import '../../../../shared/models/watchlist_entry.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/digest_provider.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../../shared/providers/watchlist_provider.dart';

/// First-launch setup: language, currency, watchlist seed, notification opt-in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  String? _currency;
  final Set<String> _selectedPins = {'gold:21', 'gold:24'};

  static const _pinOptions = [
    ('gold:21', 'Gold 21K'),
    ('gold:24', 'Gold 24K'),
    ('silver:999', 'Silver 999'),
  ];

  static const _lastPage = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref
        .read(selectedCurrencyProvider.notifier)
        .setCurrency(_currency ?? ref.read(selectedCurrencyProvider));

    for (final pin in _selectedPins) {
      final parts = pin.split(':');
      final entry = WatchlistEntry(metal: parts[0], karat: parts[1]);
      if (!ref.read(watchlistProvider).any((e) => e.id == entry.id)) {
        final result = await ref.read(watchlistProvider.notifier).toggle(entry);
        if (result == WatchlistToggleResult.full) break;
      }
    }

    await markOnboardingComplete();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Dashboard'),
        builder: (_) => const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _enableNotifications() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await ref.read(digestProvider.notifier).setEnabled(true);
      await ref.read(priceAlertsProvider.notifier).requestNotificationPermission();
    }
    await _finish();
  }

  void _next() {
    if (_page < _lastPage) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _selectLanguage(Locale locale) async {
    await setAppLocale(context, locale, ref: ref);
    if (!mounted) return;
    // Reset currency default when language changes so ar → EGP applies.
    setState(() {
      _currency = locale.languageCode == 'ar' ? 'EGP' : 'USD';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencies = ref.watch(availableCurrenciesProvider);
    final locale = context.locale.languageCode;
    _currency ??= locale == 'ar' ? 'EGP' : 'USD';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    context.tr('onboarding.title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text('${_page + 1}/${_lastPage + 1}'),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _step(
                    context,
                    title: context.tr('onboarding.language_title'),
                    body: context.tr('onboarding.language_body'),
                    child: Column(
                      children: kSupportedLocales.map((loc) {
                        final code = loc.languageCode;
                        final selected = context.locale.languageCode == code;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(kLanguageNames[code] ?? code),
                          trailing: selected
                              ? Icon(
                                  Icons.check,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                          onTap: () => _selectLanguage(loc),
                        );
                      }).toList(),
                    ),
                  ),
                  _step(
                    context,
                    title: context.tr('onboarding.currency_title'),
                    body: context.tr('onboarding.currency_body'),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: currencies.map((c) {
                        return ChoiceChip(
                          label: Text(c),
                          selected: _currency == c,
                          onSelected: (_) => setState(() => _currency = c),
                        );
                      }).toList(),
                    ),
                  ),
                  _step(
                    context,
                    title: context.tr('onboarding.watchlist_title'),
                    body: context.tr('onboarding.watchlist_body'),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pinOptions.map((opt) {
                        return FilterChip(
                          label: Text(opt.$2),
                          selected: _selectedPins.contains(opt.$1),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedPins.add(opt.$1);
                            } else {
                              _selectedPins.remove(opt.$1);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  _step(
                    context,
                    title: context.tr('onboarding.notify_title'),
                    body: context.tr('onboarding.notify_body'),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_active_outlined),
                          title: Text(context.tr('onboarding.notify_digest')),
                          subtitle:
                              Text(context.tr('onboarding.notify_digest_sub')),
                        ),
                        ListTile(
                          leading: const Icon(Icons.trending_up),
                          title: Text(context.tr('onboarding.notify_alerts')),
                          subtitle:
                              Text(context.tr('onboarding.notify_alerts_sub')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.space24),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      child: Text(context.tr('onboarding.back')),
                    ),
                  const Spacer(),
                  if (_page < _lastPage)
                    FilledButton(
                      onPressed: _next,
                      child: Text(context.tr('onboarding.next')),
                    )
                  else ...[
                    TextButton(
                      onPressed: _finish,
                      child: Text(context.tr('onboarding.skip')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _enableNotifications,
                      child: Text(context.tr('onboarding.enable')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required String title,
    required String body,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
