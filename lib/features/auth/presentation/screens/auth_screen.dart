import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/firebase/auth_service.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _signInAsGuest() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await _authService.signInAsGuest();
      
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to sign in as guest');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = _isSignUp
          ? await _authService.signUpWithEmail(
              _emailController.text.trim(),
              _passwordController.text,
            )
          : await _authService.signInWithEmail(
              _emailController.text.trim(),
              _passwordController.text,
            );
      
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on,
                  size: 60,
                  color: Colors.white,
                ),
              ).animate().scale(duration: 600.ms),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Welcome to GoldSignal',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 8),
              
              Text(
                'Track precious metals prices with AI insights',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              
              const SizedBox(height: 40),
              
              // Guest mode button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInAsGuest,
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as Guest'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 24),
              
              // Divider with OR
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ).animate().fadeIn(delay: 500.ms),
              
              const SizedBox(height: 24),
              
              // Email auth form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 600.ms),
                    
                    const SizedBox(height: 16),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_isSignUp && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 700.ms),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Sign in/up button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailAuth,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
              ).animate().fadeIn(delay: 800.ms),
              
              const SizedBox(height: 16),
              
              // Toggle sign in/up
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _formKey.currentState?.reset();
                        });
                      },
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign In'
                      : "Don't have an account? Sign Up",
                ),
              ).animate().fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}