import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_remote_config.dart';
import '../../../../core/firebase/auth_service.dart';
import '../../../../shared/providers/app_config_provider.dart';
import '../../../../shared/providers/app_info_provider.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import '../../../system/presentation/screens/force_update_screen.dart';
import '../../../system/presentation/screens/maintenance_screen.dart';
import 'welcome_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Let the splash animation play (package info is loaded synchronously in main()).
    await Future.delayed(const Duration(seconds: 2));

    // Fetch remote config (fails open) and gate the launch on it.
    final config = await ref.read(remoteConfigServiceProvider).fetch();
    ref.read(appRemoteConfigProvider.notifier).set(config);
    if (!mounted) return;

    if (config.maintenanceEnabled) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'Maintenance'),
          builder: (_) =>
              MaintenanceScreen(message: config.maintenanceMessage),
        ),
      );
      return;
    }

    final currentVersion = ref.read(packageInfoProvider).version;
    if (isVersionLower(currentVersion, config.minimumVersion)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'ForceUpdate'),
          builder: (_) => ForceUpdateScreen(config: config),
        ),
      );
      return;
    }

    final User? currentUser = _authService.currentUser;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: currentUser != null ? 'Dashboard' : 'Welcome',
        ),
        builder: (_) => currentUser != null
            ? const DashboardScreen()
            : const WelcomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gold coin icon with animation
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.monetization_on,
                size: 80,
                color: Color(0xFFFFD700),
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack)
                .then()
                .shake(duration: 300.ms, hz: 3, rotation: 0.02),

            const SizedBox(height: 24),

            // App name
            Text(
              'GoldSignal',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

            const SizedBox(height: 8),

            // Tagline
            Text(
              context.tr('auth.app_tagline_splash'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

            const SizedBox(height: 48),

            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.8),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
