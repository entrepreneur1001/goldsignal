import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Sign in as guest (anonymous)
  Future<User?> signInAsGuest() async {
    try {
      final UserCredential credential = await _auth.signInAnonymously();
      final User? user = credential.user;
      
      if (user != null) {
        // Create initial guest profile in Firestore
        await _createUserProfile(user.uid, isGuest: true);
      }
      
      return user;
    } catch (e) {
      print('Guest sign in failed: $e');
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
      return credential.user;
    } catch (e) {
      print('Email sign in failed: $e');
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
      }

      return credential.user;
    } catch (e) {
      print('Email sign up failed: $e');
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

        return userCredential.user;
      }

      return null;
    } catch (e) {
      print('Account conversion failed: $e');
      throw Exception(_handleAuthError(e));
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out failed: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset failed: $e');
      throw Exception(_handleAuthError(e));
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
      print('Failed to create user profile: $e');
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
      print('Failed to update user profile: $e');
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