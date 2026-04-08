import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/firebase/auth_service.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../features/auth/presentation/screens/auth_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  
  String _preferredUnit = 'gram';
  String _preferredKarat = '24K';
  String _selectedLanguage = 'en';
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _currentUser = FirebaseAuth.instance.currentUser;
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredUnit = prefs.getString('preferred_unit') ?? 'gram';
      _preferredKarat = prefs.getString('preferred_karat') ?? '24K';
      _selectedLanguage = prefs.getString('selected_language') ?? 'en';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
    });
  }
  
  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
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
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedCurrency = ref.watch(selectedCurrencyProvider);

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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFB800),
                            const Color(0xFFFFB800).withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Icon(
                              _currentUser?.isAnonymous ?? true
                                  ? Icons.person_outline
                                  : Icons.person,
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
                                  _currentUser?.isAnonymous ?? true
                                      ? 'Guest User'
                                      : _currentUser?.email ?? 'User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentUser?.isAnonymous ?? true
                                      ? 'Sign in to save your data'
                                      : 'Premium Member',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_currentUser?.isAnonymous ?? true)
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AuthScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFFFB800),
                              ),
                              child: const Text('Sign In'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Settings Sections
              _buildSectionHeader('Preferences'),
              
              // Currency Selection
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Currency'),
                subtitle: Text(selectedCurrency),
                onTap: () {
                  _showCurrencySelector();
                },
              ),
              
              // Unit Selection
              ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Weight Unit'),
                subtitle: Text(_preferredUnit),
                onTap: () {
                  _showUnitSelector();
                },
              ),
              
              // Default Karat
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Default Karat'),
                subtitle: Text(_preferredKarat),
                onTap: () {
                  _showKaratSelector();
                },
              ),
              
              // Language Selection
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: Text(_getLanguageName(_selectedLanguage)),
                onTap: () {
                  _showLanguageSelector();
                },
              ),
              
              const Divider(),
              
              _buildSectionHeader('App Settings'),
              
              // Dark Mode
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme'),
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                  _savePreference('dark_mode_enabled', value);
                },
              ),
              
              // Notifications
              SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                subtitle: const Text('Price alerts and updates'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _savePreference('notifications_enabled', value);
                },
              ),
              
              const Divider(),
              
              _buildSectionHeader('Data & Privacy'),
              
              // Export Data
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Portfolio'),
                subtitle: const Text('Download your data as CSV'),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting portfolio...')),
                  );
                },
              ),
              
              // Clear Cache
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Clear Cache'),
                subtitle: const Text('Free up storage space'),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                  }
                },
              ),
              
              // Privacy Policy
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                onTap: () {
                  // Open privacy policy
                },
              ),
              
              const Divider(),
              
              _buildSectionHeader('About'),
              
              // Version
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
              
              // Rate App
              ListTile(
                leading: const Icon(Icons.star_rate),
                title: const Text('Rate App'),
                subtitle: const Text('Help us improve'),
                onTap: () {
                  // Open app store
                },
              ),
              
              // Share App
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share App'),
                subtitle: const Text('Tell your friends'),
                onTap: () {
                  // Share app link
                },
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
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white60
              : Colors.black54,
        ),
      ),
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
                  ? const Icon(Icons.check, color: Color(0xFFFFB800))
                  : null,
              onTap: () {
                ref.read(selectedCurrencyProvider.notifier).setCurrency(currency);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
  
  void _showUnitSelector() {
    final units = ['gram', 'ounce', 'kilogram'];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: units.length,
          itemBuilder: (context, index) {
            final unit = units[index];
            return ListTile(
              title: Text(unit),
              trailing: _preferredUnit == unit
                  ? const Icon(Icons.check, color: Color(0xFFFFB800))
                  : null,
              onTap: () {
                setState(() {
                  _preferredUnit = unit;
                });
                _savePreference('preferred_unit', unit);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
  
  void _showKaratSelector() {
    final karats = ['24K', '22K', '21K', '18K'];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: karats.length,
          itemBuilder: (context, index) {
            final karat = karats[index];
            return ListTile(
              title: Text(karat),
              trailing: _preferredKarat == karat
                  ? const Icon(Icons.check, color: Color(0xFFFFB800))
                  : null,
              onTap: () {
                setState(() {
                  _preferredKarat = karat;
                });
                _savePreference('preferred_karat', karat);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
  
  void _showLanguageSelector() {
    final languages = {
      'en': 'English',
      'ar': 'العربية',
      'ur': 'اردو',
    };
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: languages.entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              trailing: _selectedLanguage == entry.key
                  ? const Icon(Icons.check, color: Color(0xFFFFB800))
                  : null,
              onTap: () {
                setState(() {
                  _selectedLanguage = entry.key;
                });
                _savePreference('selected_language', entry.key);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }
  
  String _getLanguageName(String code) {
    switch (code) {
      case 'ar':
        return 'العربية';
      case 'ur':
        return 'اردو';
      default:
        return 'English';
    }
  }
}