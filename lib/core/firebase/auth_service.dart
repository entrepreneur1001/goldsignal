import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../analytics/analytics_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Whether the signed-in user has verified their email address.
  /// Anonymous (guest) users are treated as not requiring verification.
  bool get isEmailVerified {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.emailVerified;
  }

  /// Send (or resend) the email-verification link to the current user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.emailVerified) return;
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
    return _auth.currentUser?.emailVerified ?? false;
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
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
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
        final UserCredential userCredential = await user.linkWithCredential(credential);

        // Update user profile in Firestore
        await _updateUserProfileToRegistered(user.uid, email);

        // Send the verification link now that the guest has a real email.
        if (userCredential.user != null) {
          await _trySendEmailVerification(userCredential.user!);
        }

        return userCredential.user;
      }

      return null;
    } catch (e) {
      debugPrint('Account conversion failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
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
    if (user.isAnonymous || user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } catch (e) {
      debugPrint('Auto send email verification failed: $e');
    }
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