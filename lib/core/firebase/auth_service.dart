import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../analytics/analytics_service.dart';

class AuthService {
  AuthService();

  static const _googleWebClientId =
      '180716366944-7q85p48jf2km4q4t311pfvug2o36a97v.apps.googleusercontent.com';

  static bool _googleInitialized = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether the signed-in user has verified their email address.
  /// Anonymous (guest) users and social-login users are treated as verified.
  bool get isEmailVerified {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    if (_usesSocialProvider(user)) return true;
    return user.emailVerified;
  }

  /// Send (or resend) the email-verification link to the current user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null ||
        user.isAnonymous ||
        user.emailVerified ||
        _usesSocialProvider(user)) {
      return;
    }
    try {
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('Send email verification failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  /// Refresh the user from the server and report the latest verified state.
  /// Used by the "I've verified" action to pick up a link the user just clicked.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return isEmailVerified;
  }

  /// Load the current user's Firestore profile document (or null).
  Future<Map<String, dynamic>?> loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Save profile details: updates FirebaseAuth displayName and merges the
  /// extra fields into the user's Firestore document.
  Future<void> updateProfile({
    required String name,
    String? country,
    String? city,
    DateTime? dob,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
    }

    await _firestore.collection('users').doc(user.uid).set({
      'displayName': trimmedName,
      'country': country,
      'city': city,
      'dob': dob?.toIso8601String(),
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Sign in as guest (anonymous)
  Future<User?> signInAsGuest() async {
    try {
      final UserCredential credential = await _auth.signInAnonymously();
      final User? user = credential.user;

      if (user != null) {
        // Create initial guest profile in Firestore
        await _createUserProfile(user.uid, isGuest: true);
        await AnalyticsService.instance.setUser(user.uid);
        await AnalyticsService.instance.logLogin('guest');
      }

      return user;
    } catch (e) {
      debugPrint('Guest sign in failed: $e');
      return null;
    }
  }

  // Sign in with email
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await AnalyticsService.instance.setUser(credential.user!.uid);
        await AnalyticsService.instance.logLogin('password');
      }
      return credential.user;
    } catch (e) {
      debugPrint('Email sign in failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  // Sign up with email
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user profile in Firestore
        await _createUserProfile(
          credential.user!.uid,
          email: email,
          isGuest: false,
        );
        // Fire off the email-verification link (soft verification: the user is
        // let into the app immediately and nudged to verify from Profile).
        await _trySendEmailVerification(credential.user!);
        await AnalyticsService.instance.setUser(credential.user!.uid);
        await AnalyticsService.instance.logSignUp('password');
      }

      return credential.user;
    } catch (e) {
      debugPrint('Email sign up failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  // Convert guest account to email account
  Future<User?> convertGuestToEmail(String email, String password) async {
    try {
      final User? user = currentUser;

      if (user != null && user.isAnonymous) {
        // Create email credential
        final AuthCredential credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );

        // Link anonymous account with email credential
        final UserCredential userCredential =
            await user.linkWithCredential(credential);

        // Update user profile in Firestore
        await _updateUserProfileToRegistered(user.uid, email);

        // Send the verification link now that the guest has a real email.
        if (userCredential.user != null) {
          await _trySendEmailVerification(userCredential.user!);
          // Same uid as the guest session — keep the analytics association and
          // record the upgrade as a sign-up.
          await AnalyticsService.instance.setUser(userCredential.user!.uid);
          await AnalyticsService.instance.logSignUp('guest_upgrade');
        }

        return userCredential.user;
      }

      return null;
    } catch (e) {
      debugPrint('Account conversion failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  /// Sign in with Google. Returns null if the user cancels the picker.
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _pickGoogleAccount();
      if (googleUser == null) return null;

      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _ensureSocialUserProfile(user);
        await AnalyticsService.instance.setUser(user.uid);
        await AnalyticsService.instance.logLogin('google');
      }

      return user;
    } catch (e) {
      debugPrint('Google sign in failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  /// Link the current anonymous guest account to Google (same uid).
  Future<User?> convertGuestToGoogle() async {
    try {
      final user = currentUser;
      if (user == null || !user.isAnonymous) return null;

      final googleUser = await _pickGoogleAccount();
      if (googleUser == null) return null;

      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await user.linkWithCredential(credential);
      final linkedUser = userCredential.user;

      if (linkedUser != null) {
        await _updateUserProfileToRegistered(
          linkedUser.uid,
          linkedUser.email ?? '',
        );
        await _mergeDisplayNameFromUser(linkedUser);
        await AnalyticsService.instance.setUser(linkedUser.uid);
        await AnalyticsService.instance.logSignUp('guest_upgrade_google');
      }

      return linkedUser;
    } catch (e) {
      debugPrint('Guest Google link failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  /// Sign in with Apple. Returns null if the user cancels.
  Future<User?> signInWithApple() async {
    try {
      final appleCredential = await _getAppleCredential();
      if (appleCredential == null) return null;

      final rawNonce = appleCredential.rawNonce;
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.credential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user != null) {
        await _applyAppleDisplayName(user, appleCredential.credential);
        await _ensureSocialUserProfile(user);
        await AnalyticsService.instance.setUser(user.uid);
        await AnalyticsService.instance.logLogin('apple');
      }

      return user;
    } catch (e) {
      debugPrint('Apple sign in failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  /// Link the current anonymous guest account to Apple (same uid).
  Future<User?> convertGuestToApple() async {
    try {
      final user = currentUser;
      if (user == null || !user.isAnonymous) return null;

      final appleCredential = await _getAppleCredential();
      if (appleCredential == null) return null;

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.credential.identityToken,
        rawNonce: appleCredential.rawNonce,
      );

      final userCredential = await user.linkWithCredential(oauthCredential);
      final linkedUser = userCredential.user;

      if (linkedUser != null) {
        await _applyAppleDisplayName(linkedUser, appleCredential.credential);
        await _updateUserProfileToRegistered(
          linkedUser.uid,
          linkedUser.email ?? appleCredential.credential.email ?? '',
        );
        await AnalyticsService.instance.setUser(linkedUser.uid);
        await AnalyticsService.instance.logSignUp('guest_upgrade_apple');
      }

      return linkedUser;
    } catch (e) {
      debugPrint('Guest Apple link failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await Future.wait([
        _auth.signOut(),
        GoogleSignIn.instance.signOut(),
      ]);
      await AnalyticsService.instance.setUser(null);
    } catch (e) {
      debugPrint('Sign out failed: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }

  // Best-effort verification email — never block account creation if it fails.
  Future<void> _trySendEmailVerification(User user) async {
    if (user.isAnonymous || user.emailVerified || _usesSocialProvider(user)) {
      return;
    }
    try {
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('Auto send email verification failed: $e');
    }
  }

  Future<({AuthorizationCredentialAppleID credential, String rawNonce})?>
      _getAppleCredential() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      return (credential: credential, rawNonce: rawNonce);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleWebClientId,
    );
    _googleInitialized = true;
  }

  Future<GoogleSignInAccount?> _pickGoogleAccount() async {
    await _ensureGoogleInitialized();
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _ensureSocialUserProfile(User user) async {
    await _createUserProfile(
      user.uid,
      email: user.email,
      isGuest: false,
    );
    await _mergeDisplayNameFromUser(user);
  }

  Future<void> _mergeDisplayNameFromUser(User user) async {
    final displayName = user.displayName?.trim();
    if (displayName == null || displayName.isEmpty) return;

    await _firestore.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _applyAppleDisplayName(
    User user,
    AuthorizationCredentialAppleID credential,
  ) async {
    final given = credential.givenName?.trim();
    final family = credential.familyName?.trim();
    if (given == null || given.isEmpty) return;

    final name = family == null || family.isEmpty ? given : '$given $family';
    await user.updateDisplayName(name);
    await _firestore.collection('users').doc(user.uid).set({
      'displayName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _usesSocialProvider(User user) {
    return user.providerData.any(
      (info) =>
          info.providerId == 'google.com' || info.providerId == 'apple.com',
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(
    String uid, {
    String? email,
    bool isGuest = false,
  }) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);

      // Check if profile already exists
      final docSnapshot = await userDoc.get();
      if (docSnapshot.exists) {
        return;
      }

      // Create new profile
      await userDoc.set({
        'uid': uid,
        'email': email,
        'isGuest': isGuest,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'preferences': {
          'currency': 'USD',
          'language': 'en',
          'theme': 'system',
          'karat': '24K',
          'unit': 'gram',
          'notifications': true,
        },
        'subscription': {
          'type': 'free',
          'expiresAt': null,
        },
        'limits': {
          'dailyAIQueries': 100,
          'lastResetDate': DateTime.now().toIso8601String().split('T')[0],
        },
      });
    } catch (e) {
      debugPrint('Failed to create user profile: $e');
      rethrow;
    }
  }

  // Update guest profile to registered user
  Future<void> _updateUserProfileToRegistered(String uid, String email) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'email': email,
        'isGuest': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      rethrow;
    }
  }

  // Handle authentication errors
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'credential-already-in-use':
          return 'This email is already linked to another account. Try signing in instead.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using a different sign-in method.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return 'Authentication failed. Please try again.';
      }
    }
    return 'An unexpected error occurred.';
  }
}
