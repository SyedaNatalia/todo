import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../screens/home_screen.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form keys
  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> signupFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> forgotPasswordFormKey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();

  // Auth state
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  // Loading state
  bool isLoading = false;

  // Error handling
  String? errorMessage;

  // Constructor to listen for auth state changes
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  // Form validation methods
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter your email";
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Please enter a valid email address";
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter your password";
    }
    if (value.length < 8) {
      return "Password must be at least 8 characters long";
    }
    return null;
  }

  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return "This field is required";
    }
    return null;
  }

  // Login method that handles form validation and navigation
  Future<void> login(BuildContext context) async {
    if (!loginFormKey.currentState!.validate()) return;

    final success = await signIn(
      emailController.text.trim(),
      passwordController.text,
    );

    if (success && context.mounted) {
      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  // Sign up method that handles form validation and navigation
  Future<void> signup(BuildContext context) async {
    if (!signupFormKey.currentState!.validate()) return;

    final userData = {
      'firstName': firstNameController.text.trim(),
      'lastName': lastNameController.text.trim(),
      'role': 'user', // Default role
    };

    final success = await signUp(
      emailController.text.trim(),
      passwordController.text,
      userData,
    );

    if (success && context.mounted) {
      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  // Request password reset
  Future<void> requestPasswordReset(BuildContext context) async {
    if (!forgotPasswordFormKey.currentState!.validate()) return;

    final success = await resetPassword(emailController.text.trim());

    if (success && context.mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to login screen
      Navigator.pop(context);
    }
  }

  // Firebase authentication methods
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    clearError();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user != null;
    } on FirebaseAuthException catch (e) {
      errorMessage = _handleAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp(String email, String password, Map<String, dynamic> userData) async {
    _setLoading(true);
    clearError();

    try {
      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create UserModel with ID from Firebase Auth
        final userModel = UserModel(
          id: userCredential.user!.uid,
          email: email,
          firstName: userData['firstName'],
          lastName: userData['lastName'],
          role: userData['role'],
          profileImagePath: null, // Default to null for new users
        );

        // Save user details to Firestore
        await _saveUserData(userCredential.user!.uid, userModel);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      errorMessage = _handleAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _saveUserData(String uid, UserModel userData) async {
    try {
      await _firestore.collection('users').doc(uid).set(userData.toMap());
    } catch (e) {
      // If saving user data fails, we should delete the auth user
      await _auth.currentUser?.delete();
      throw Exception('Failed to save user data');
    }
  }

  Future<UserModel?> getCurrentUserData() async {
    if (currentUser == null) return null;

    try {
      final docSnapshot = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (docSnapshot.exists) {
        return UserModel.fromFirestore(docSnapshot.data()!, currentUser!.uid);
      }
      return null;
    } catch (e) {
      errorMessage = 'Error retrieving user data';
      notifyListeners();
      return null;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _auth.signOut();
      // Clear controllers
      emailController.clear();
      passwordController.clear();
      firstNameController.clear();
      lastNameController.clear();
    } catch (e) {
      errorMessage = 'Error signing out';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    clearError();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      errorMessage = _handleAuthError(e);
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Utility methods
  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException error) {
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
        return error.message ?? 'Authentication failed';
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Dispose controllers
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  void clearLoginFields() {
    emailController.clear();
    passwordController.clear();
  }

  void clearRegisterFields() {
    firstNameController.clear();
    lastNameController.clear();
    emailController.clear();
    passwordController.clear();
  }
}