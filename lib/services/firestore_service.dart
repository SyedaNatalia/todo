import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> updateTaskCompletion(String taskId, bool isDone) async {
    await _firestore.collection('todos').doc(taskId).update({
      'isDone': isDone,
      'status': isDone ? 'completed' : 'pending',
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> getTasksStream() {
    return _firestore.collection('todos').snapshots();
  }

  Stream<QuerySnapshot> getPendingTasksStream() {
    return _firestore
        .collection('todos')
        .where('isDone', isEqualTo: false)
        .where('dueDate', isNull: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getOverdueTasksStream() {
    return _firestore
        .collection('todos')
        .where('isDone', isEqualTo: false)
        .where('dueDate', isLessThan: Timestamp.now())
        .snapshots();
  }

  Stream<QuerySnapshot> getCompletedTasksStream() {
    return _firestore
        .collection('todos')
        .where('isDone', isEqualTo: true)
        .snapshots();
  }
}