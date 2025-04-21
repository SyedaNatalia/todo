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

  UserModel? get currentUser => _currentUser;
  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get profileImagePath => _profileImagePath;

  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Initialize user data
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await fetchCurrentUser();
      await loadProfileImage();
      await fetchUsers();
    } catch (e) {
      print('Error initializing user provider: $e');
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
      print('Error fetching current user: $e');
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
      print('Error fetching users: $e');
    }
  }

  // Load profile image from SharedPreferences
  Future<void> loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _profileImagePath = prefs.getString('profile_image_path');
      notifyListeners();
    } catch (e) {
      print('Error loading profile image: $e');
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
      print('Error saving profile image: $e');
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}