import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../prices/presentation/screens/prices_screen.dart';
import '../../../calculator/presentation/screens/calculator_screen.dart';
import '../../../chatbot/presentation/screens/chatbot_screen.dart';
import '../../../portfolio/presentation/screens/portfolio_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  
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