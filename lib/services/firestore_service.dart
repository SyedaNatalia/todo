import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTask(String task, bool isDone) async {
    await _firestore.collection('todos').add({
      'task': task,
      'isDone': isDone,
    });
  }

  Future<void> updateTaskCompletion(String taskId, bool isDone) async {
    await _firestore.collection('todos').doc(taskId).update({
      'isDone': isDone,
    });
  }

  Stream<QuerySnapshot> getTasksStream() {
    return _firestore.collection('todos').snapshots();
  }
}