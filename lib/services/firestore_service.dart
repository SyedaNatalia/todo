import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a task with optional due date and assigned to fields
  Future<void> addTask({
    required String task,
    required bool isDone,
    String? assignedTo,
    DateTime? dueDate,
  }) async {
    await _firestore.collection('todos').add({
      'task': task,
      'isDone': isDone,
      'status': isDone ? 'completed' : 'pending',
      'assignedTo': assignedTo,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  // Update task completion status
  Future<void> updateTaskCompletion(String taskId, bool isDone) async {
    await _firestore.collection('todos').doc(taskId).update({
      'isDone': isDone,
      'status': isDone ? 'completed' : 'pending',
      'updatedAt': Timestamp.now(),
    });
  }

  // Get all tasks
  Stream<QuerySnapshot> getTasksStream() {
    return _firestore.collection('todos').snapshots();
  }

  // Get pending tasks (with due date)
  Stream<QuerySnapshot> getPendingTasksStream() {
    return _firestore
        .collection('todos')
        .where('isDone', isEqualTo: false)
        .where('dueDate', isNull: false)
        .snapshots();
  }

  // Get uncompleted tasks (without due date)
  Stream<QuerySnapshot> getUncompletedTasksStream() {
    return _firestore
        .collection('todos')
        .where('isDone', isEqualTo: false)
        .where('dueDate', isNull: true)
        .snapshots();
  }

  // Get completed tasks
  Stream<QuerySnapshot> getCompletedTasksStream() {
    return _firestore
        .collection('todos')
        .where('isDone', isEqualTo: true)
        .snapshots();
  }
}
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class FirestoreService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   Future<void> addTask(String task, bool isDone) async {
//     await _firestore.collection('todos').add({
//       'task': task,
//       'isDone': isDone,
//     });
//   }
//
//   Future<void> updateTaskCompletion(String taskId, bool isDone) async {
//     await _firestore.collection('todos').doc(taskId).update({
//       'isDone': isDone,
//     });
//   }
//
//   Stream<QuerySnapshot> getTasksStream() {
//     return _firestore.collection('todos').snapshots();
//   }
// }