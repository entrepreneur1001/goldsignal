import 'package:flutter/material.dart';
import '../../../auth/presentation/screens/splash_screen.dart';

/// Full-screen, non-dismissible maintenance notice shown at launch when
/// `metadata/app.maintenanceEnabled` is true. "Retry" re-runs the launch gate.
class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.engineering_outlined,
                      size: 88, color: Color(0xFFFFB800)),
                  const SizedBox(height: 24),
                  Text(
                    'Under maintenance',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
