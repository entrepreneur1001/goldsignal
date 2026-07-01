import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/auth_service.dart';
import 'chat_history_provider.dart';
import 'portfolio_provider.dart';
import 'price_alerts_provider.dart';
import 'savings_goals_provider.dart';

/// Single shared [AuthService] instance for the app.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Reactive Firebase auth state. Routing and UI watch this instead of reading
/// `currentUser` ad-hoc.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Centralizes every auth action and exposes a loading/error [AsyncValue] the
/// screens watch for spinners. Action methods rethrow so callers can surface a
/// message and decide on navigation.
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthService get _service => ref.read(authServiceProvider);

  Future<T> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      final result = await action();
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Run an auth action and, on success, reset the user-scoped providers so they
  /// re-bootstrap and hydrate from the freshly signed-in account's Firestore
  /// (prevents User A's in-memory data bleeding into User B in one app session).
  Future<User?> _authThenReset(Future<User?> Function() action) async {
    final user = await _run(action);
    _resetUserScopedProviders();
    return user;
  }

  Future<User?> signIn(String email, String password) =>
      _authThenReset(() => _service.signInWithEmail(email, password));

  Future<User?> signUp(String email, String password) =>
      _authThenReset(() => _service.signUpWithEmail(email, password));

  Future<User?> signInAsGuest() =>
      _authThenReset(() => _service.signInAsGuest());

  Future<User?> convertGuest(String email, String password) =>
      _authThenReset(() => _service.convertGuestToEmail(email, password));

  Future<User?> signInWithGoogle({bool linkGuest = false}) => _authThenReset(
        () => linkGuest
            ? _service.convertGuestToGoogle()
            : _service.signInWithGoogle(),
      );

  Future<User?> signInWithApple({bool linkGuest = false}) => _authThenReset(
        () =>
            linkGuest ? _service.convertGuestToApple() : _service.signInWithApple(),
      );

  Future<void> sendReset(String email) =>
      _run(() => _service.resetPassword(email));

  /// Resend the verification link (does not toggle the global loading state so
  /// the Profile banner can manage its own button spinner).
  Future<void> resendVerification() => _service.sendEmailVerification();

  /// Reload the user and report whether the email is now verified.
  Future<bool> refreshVerification() => _service.reloadAndCheckVerified();

  Future<void> signOut() async {
    // Sign out FIRST so currentUser is null, THEN reset the user-scoped stream
    // providers — they re-subscribe and, finding no user, clear their data.
    // Firestore queries are uid-scoped, so the next account never sees this
    // one's data (and security rules enforce it server-side).
    await _service.signOut();
    _resetUserScopedProviders();
  }

  /// Discard in-memory user state after the account has been deleted.
  Future<void> wipeLocalUserData() async {
    _resetUserScopedProviders();
  }

  /// Invalidate providers that cache per-user data so they rebuild from the
  /// (now empty / newly signed-in) sources.
  void _resetUserScopedProviders() {
    ref.invalidate(portfolioProvider);
    ref.invalidate(priceAlertsProvider);
    ref.invalidate(chatHistoryProvider);
    ref.invalidate(savingsGoalsProvider);
  }
}
