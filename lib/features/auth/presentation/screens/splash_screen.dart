import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/firebase/auth_service.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));
    
    // Check authentication status
    final User? currentUser = _authService.currentUser;
    
    if (mounted) {
      if (currentUser != null) {
        // User is signed in (guest or registered)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        // No user, show auth screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
    }
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
              'Track Gold & Silver Prices',
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