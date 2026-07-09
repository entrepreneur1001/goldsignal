import 'package:flutter/material.dart';

import '../../core/utils/app_session.dart';
import '../dashboard/presentation/screens/dashboard_screen.dart';
import 'presentation/screens/onboarding_screen.dart';

/// Routes to onboarding on first launch, otherwise the main dashboard.
Future<void> navigateToHome(BuildContext context) async {
  final complete = await isOnboardingComplete();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      settings: RouteSettings(name: complete ? 'Dashboard' : 'Onboarding'),
      builder: (_) =>
          complete ? const DashboardScreen() : const OnboardingScreen(),
    ),
    (route) => false,
  );
}
