import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return userCredential.user;
    } catch (e) {
      print('Error signing in: $e');
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
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Check authentication state
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}