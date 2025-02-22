import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();

  final Color peachColor = const Color(0xFFFFB5A7);
  final Color lightPeachColor = const Color(0xFFFFE5E0);
  final Color darkPeachColor = const Color(0xFFFF8576);

  bool _isLoading = false; // For task operations
  bool _isRefreshing = false; // For refresh operations

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _showTaskDialog({String? taskId, String? currentTask}) async {
    _taskController.text = currentTask ?? '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: lightPeachColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            taskId == null ? 'Add Task' : 'Update Task',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: _taskController,
            style: GoogleFonts.nunito(),
            decoration: InputDecoration(
              hintText: 'Enter task title',
              hintStyle: GoogleFonts.nunito(color: Colors.black54),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: peachColor),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskController.clear();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () async {
                if (_taskController.text.isNotEmpty) {
                  setState(() {
                    _isLoading = true; // Start loading
                  });

                  try {
                    if (taskId != null) {
                      await _firestore.collection('todos').doc(taskId).update({
                        'task': _taskController.text.trim(),
                      });
                    } else {
                      await _firestore.collection('todos').add({
                        'task': _taskController.text.trim(),
                        'isDone': false,
                      });
                    }
                    _taskController.clear();
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to ${taskId == null ? 'add' : 'update'} task. Please try again.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() {
                      _isLoading = false; // Stop loading
                    });
                  }
                }
              },
              child: Text(
                taskId == null ? 'Add' : 'Update',
                style: GoogleFonts.poppins(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshScreen() async {
    setState(() {
      _isRefreshing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight((_isLoading || _isRefreshing) ? 150 : 50),
        child: AppBar(
          backgroundColor: peachColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          title: Text(
            "Todo List",
            style: GoogleFonts.poppins(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () async {
                await AuthService().signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.black),
            ),
          ],
          bottom: (_isLoading || _isRefreshing)
              ? PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          )
              : null,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshScreen,
        child: _isRefreshing
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('todos').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: peachColor,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: GoogleFonts.poppins(),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  'No tasks found.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              );
            }

            final tasks = snapshot.data!.docs;

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final taskId = task.id;
                  final taskData = task.data() as Map<String, dynamic>;
                  final taskTitle = taskData['task'];
                  final isDone = taskData['isDone'];

                  return Dismissible(
                    key: Key(taskId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: darkPeachColor,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (direction) async {
                      await _firestore.collection('todos').doc(taskId).delete();
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      color: lightPeachColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          taskTitle,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.black54),
                              onPressed: () => _showTaskDialog(
                                taskId: taskId,
                                currentTask: taskTitle,
                              ),
                            ),
                            Checkbox(
                              value: isDone,
                              activeColor: peachColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) async {
                                await _firestore.collection('todos').doc(taskId).update({
                                  'isDone': value ?? false,
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        backgroundColor: peachColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}