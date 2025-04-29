import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? _currentUser;
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _profileImagePath;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get profileImagePath => _profileImagePath;
  String? get errorMessage => _errorMessage;

  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Constructor
  UserProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        initialize();
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  // Initialize user data
  Future<void> initialize() async {
    if (_auth.currentUser == null) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      await fetchCurrentUser();
      await loadProfileImage();
      await fetchUsers();
    } catch (e) {
      _errorMessage = 'Error initializing user provider: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Fetch current user data
  Future<void> fetchCurrentUser() async {
    if (_auth.currentUser == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      if (doc.exists) {
        _currentUser = UserModel.fromFirestore(doc.data()!, doc.id);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error fetching current user: $e';
      print(_errorMessage);
    }
  }

  // Fetch all users
  Future<void> fetchUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .get();

      _users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching users: $e';
      print(_errorMessage);
    }
  }

  // Load profile image from SharedPreferences
  Future<void> loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _profileImagePath = prefs.getString('profile_image_path');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error loading profile image: $e';
      print(_errorMessage);
    }
  }

  // Save profile image path to SharedPreferences
  Future<void> saveProfileImage(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', path);
      _profileImagePath = path;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error saving profile image: $e';
      print(_errorMessage);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? role,
    String? bio,
  }) async {
    if (_currentUser == null) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      final Map<String, dynamic> updateData = {};

      if (name != null && name.isNotEmpty) {
        updateData['name'] = name;
      }

      if (role != null && role.isNotEmpty) {
        updateData['role'] = role;
      }

      if (bio != null && bio.isNotEmpty) {
        updateData['bio'] = bio;
      }

      if (updateData.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentUserId)
            .update(updateData);

        await fetchCurrentUser(); // Refresh user data
      }
    } catch (e) {
      _errorMessage = 'Error updating profile: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Get users based on role hierarchy
  List<UserModel> getUsersBasedOnRole() {
    if (_currentUser == null) return [];

    switch (_currentUser!.role) {
      case 'Manager':
        return _users.where((user) => user.email != currentUserEmail).toList();
      case 'Team Lead':
        return _users.where((user) =>
        (user.role == 'Employee' || user.role == 'Intern') &&
            user.email != currentUserEmail
        ).toList();
      case 'Employee':
        return _users.where((user) =>
        user.role == 'Intern' &&
            user.email != currentUserEmail
        ).toList();
      default:
        return [];
    }
  }

  // Check if user can assign tasks
  bool canAssignTasks() {
    if (_currentUser == null) return false;
    return ['Manager', 'Team Lead', 'Employee'].contains(_currentUser!.role);
  }

  // Check if user can delete tasks
  bool canDeleteTasks() {
    if (_currentUser == null) return false;
    return ['Manager', 'Team Lead'].contains(_currentUser!.role);
  }

  // Create a new user (for admin functionality)
  Future<void> createUser({
    required String email,
    required String name,
    required String role,
  }) async {
    if (_currentUser?.role != 'Manager') {
      _errorMessage = 'Only managers can create new users';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      // Create user document in Firestore
      await _firestore.collection('users').add({
        'email': email,
        'name': name,
        'role': role,
        'createdAt': Timestamp.now(),
      });

      await fetchUsers(); // Refresh user list
    } catch (e) {
      _errorMessage = 'Error creating user: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Get user by email
  UserModel? getUserByEmail(String email) {
    try {
      return _users.firstWhere((user) => user.email == email);
    } catch (e) {
      return null;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
