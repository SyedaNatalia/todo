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

  List<Task> get completedTasks => _completedTasks;
  List<Task> get pendingTasks => _pendingTasks;
  List<Task> get overdueTasks => _overdueTasks;
  bool get isLoading => _isLoading;

  String get currentUserEmail => _auth.currentUser?.email ?? '';
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Fetch tasks for the current user
  Future<void> fetchTasks() async {
    _setLoading(true);
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
      print('Error fetching tasks: $e');
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
      print('Error adding task: $e');
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
      print('Error updating task: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    _setLoading(true);
    try {
      await _firestore.collection('todos').doc(taskId).delete();
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      print('Error deleting task: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Mark task as done
  Future<void> markTaskAsDone(String taskId) async {
    _setLoading(true);
    try {
      await _firestore.collection('todos').doc(taskId).update({
        'isDone': true,
        'status': 'completed',
        'updatedAt': Timestamp.now(),
      });
      await fetchTasks(); // Refresh tasks
    } catch (e) {
      print('Error marking task as done: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}