import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<User?> signIn(String email, String password) async {
      try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error signing in: $e");
      return null;
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print("Error signing up: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    try {
      HttpsCallable callable = _functions.httpsCallable('getAllUsers');
      final response = await callable();
      return List<Map<String, dynamic>>.from(response.data['users']);
    } catch (e) {
      print("Error fetching users: $e");
      return [];
    }
  }
}