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
  
  final List<BottomNavigationBarItem> _bottomNavItems = const [
    BottomNavigationBarItem(
      icon: Icon(Icons.show_chart),
      label: 'Prices',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calculate),
      label: 'Calculator',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat),
      label: 'AI Chat',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet),
      label: 'Portfolio',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: _bottomNavItems,
      ),
    );
  }
}