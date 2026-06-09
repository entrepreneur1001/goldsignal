import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../prices/presentation/screens/prices_screen.dart';
import '../../../calculator/presentation/screens/calculator_screen.dart';
import '../../../chatbot/presentation/screens/chatbot_screen.dart';
import '../../../portfolio/presentation/screens/portfolio_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../system/store_launcher.dart';
import '../../../../core/config/app_remote_config.dart';
import '../../../../shared/providers/app_config_provider.dart';
import '../../../../shared/providers/app_info_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';
import '../../../../shared/widgets/floating_nav_bar.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  /// Soft "update available" prompt is shown at most once per app launch.
  static bool _softUpdateShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSoftUpdate());
  }

  void _maybeShowSoftUpdate() {
    if (_softUpdateShown || !mounted) return;
    final config = ref.read(appRemoteConfigProvider);
    if (config == null) return;
    final current = ref.read(packageInfoProvider).version;
    // Force-update (below minimum) is already handled at the splash gate; here
    // we only nudge when below the latest available version.
    if (!isVersionLower(current, config.latestVersion)) return;
    _softUpdateShown = true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text(config.updateMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppStore(config);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  final List<Widget> _screens = [
    const PricesScreen(),
    const CalculatorScreen(),
    const ChatbotScreen(),
    const PortfolioScreen(),
    const ProfileScreen(),
  ];
  
  static const List<NavItem> _navItems = [
    NavItem(
      icon: Icons.show_chart_rounded,
      activeIcon: Icons.show_chart_rounded,
      label: 'Markets',
    ),
    NavItem(
      icon: Icons.calculate_outlined,
      activeIcon: Icons.calculate_rounded,
      label: 'Calc',
    ),
    NavItem(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      label: 'AI',
    ),
    NavItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
    ),
    NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    // Bootstrap central price orchestrator for all tabs
    ref.watch(marketPricesControllerProvider);

    ref.listen<PriceAlertsState>(priceAlertsProvider, (prev, next) {
      final msg = next.snackbarMessage;
      if (msg == null || msg == prev?.snackbarMessage) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => AlertsNavButton.open(context),
          ),
        ),
      );
      ref.read(priceAlertsProvider.notifier).clearSnackbar();
    });

    return Scaffold(
      // Note: extendBody is intentionally false so each tab's own Scaffold
      // (and its FloatingActionButton, e.g. Portfolio) sits above the floating
      // nav rather than behind it.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: FloatingNavBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}