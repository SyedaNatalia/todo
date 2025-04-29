import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Auth state
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Error handling
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Constructor to listen for auth state changes
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      print('Error signing in: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Sign up with email and password
  Future<User?> signUp(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      print('Error signing up: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _auth.signOut();
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      print('Error signing out: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      _errorMessage = _handleAuthError(e);
      print('Error resetting password: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Check authentication state
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Handle auth errors
  String _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Email address is not valid';
        case 'user-disabled':
          return 'User has been disabled';
        case 'user-not-found':
          return 'User not found';
        case 'wrong-password':
          return 'Password is incorrect';
        case 'email-already-in-use':
          return 'The email address is already in use';
        case 'operation-not-allowed':
          return 'Operation not allowed';
        case 'weak-password':
          return 'Password is too weak';
        default:
          return 'Authentication failed: ${error.message}';
      }
    }
    return 'Authentication failed: $error';
  }

  // Clear errors
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
