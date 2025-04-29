import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Task> _completedTasks = [];
  List<Task> _pendingTasks = [];
  List<Task> _overdueTasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Task> get completedTasks => _completedTasks;
  List<Task> get pendingTasks => _pendingTasks;
  List<Task> get overdueTasks => _overdueTasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Initialize by fetching tasks
  TaskProvider() {
    fetchTasks();
  }

  // Fetch tasks for the current user
  Future<void> fetchTasks() async {
    if (currentUserEmail.isEmpty) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      // Fetch completed tasks
      final completedSnapshot = await _firestore
          .collection('todos')
          .where('assignedTo', isEqualTo: currentUserEmail)
          .where('isDone', isEqualTo: true)
          .get();

      _completedTasks = completedSnapshot.docs
          .map((doc) => Task.fromFirestore(doc.data(), doc.id))
          .toList();

      // Fetch pending tasks
      final pendingSnapshot = await _firestore
          .collection('todos')
          .where('assignedTo', isEqualTo: currentUserEmail)
          .where('isDone', isEqualTo: false)
          .where('status', isEqualTo: 'pending')
          .get();

      _pendingTasks = pendingSnapshot.docs
          .map((doc) => Task.fromFirestore(doc.data(), doc.id))
          .toList();

      // Fetch overdue tasks
      final overdueSnapshot = await _firestore
          .collection('todos')
          .where('assignedTo', isEqualTo: currentUserEmail)
          .where('isDone', isEqualTo: false)
          .where('dueDate', isLessThan: Timestamp.now())
          .get();

      _overdueTasks = overdueSnapshot.docs
          .map((doc) => Task.fromFirestore(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching tasks: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Fetch tasks for a specific user (for managers/team leads)
  Future<List<Task>> fetchTasksForUser(String userEmail) async {
    _setLoading(true);
    try {
      final tasksSnapshot = await _firestore
          .collection('todos')
          .where('assignedTo', isEqualTo: userEmail)
          .get();

      final tasks = tasksSnapshot.docs
          .map((doc) => Task.fromFirestore(doc.data(), doc.id))
          .toList();

      return tasks;
    } catch (e) {
      _errorMessage = 'Error fetching tasks for user: $e';
      print(_errorMessage);
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Add a new task
  Future<void> addTask({
    required String task,
    required String assignedTo,
    DateTime? dueDate,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final pairString = '$assignedTo+$currentUserEmail';
      final Map<String, dynamic> taskData = {
        'task': task.trim(),
        'assignedTo': assignedTo,
        'assignedBy': currentUserEmail,
        'pair': pairString,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'isDone': false,
        'status': 'pending',
      };

      if (dueDate != null) {
        taskData['dueDate'] = Timestamp.fromDate(dueDate);
      }

      await _firestore.collection('todos').add(taskData);
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      _errorMessage = 'Error adding task: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Update an existing task
  Future<void> updateTask({
    required String taskId,
    required String task,
    required String assignedTo,
    DateTime? dueDate,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final pairString = '$assignedTo+$currentUserEmail';
      final Map<String, dynamic> taskData = {
        'task': task.trim(),
        'assignedTo': assignedTo,
        'assignedBy': currentUserEmail,
        'pair': pairString,
        'updatedAt': Timestamp.now(),
        'status': 'pending',
      };

      if (dueDate != null) {
        taskData['dueDate'] = Timestamp.fromDate(dueDate);
      }

      await _firestore.collection('todos').doc(taskId).update(taskData);
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      _errorMessage = 'Error updating task: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firestore.collection('todos').doc(taskId).delete();
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      _errorMessage = 'Error deleting task: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Mark task as done
  Future<void> markTaskAsDone(String taskId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firestore.collection('todos').doc(taskId).update({
        'isDone': true,
        'status': 'completed',
        'updatedAt': Timestamp.now(),
      });
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      _errorMessage = 'Error marking task as done: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Mark task as pending again
  Future<void> markTaskAsPending(String taskId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firestore.collection('todos').doc(taskId).update({
        'isDone': false,
        'status': 'pending',
        'updatedAt': Timestamp.now(),
      });
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      _errorMessage = 'Error marking task as pending: $e';
      print(_errorMessage);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Stream tasks for real-time updates
  Stream<List<Task>> streamTasks() {
    return _firestore
        .collection('todos')
        .where('assignedTo', isEqualTo: currentUserEmail)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Task.fromFirestore(doc.data(), doc.id))
        .toList());
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
