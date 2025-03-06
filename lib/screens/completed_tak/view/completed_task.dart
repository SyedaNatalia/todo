import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_project/screens/chat_screen.dart';

class CompletedTaskScreen extends StatefulWidget {
  const CompletedTaskScreen({Key? key}) : super(key: key);
  @override
  State<CompletedTaskScreen> createState() => _CompletedTaskScreenState();
}
class _CompletedTaskScreenState extends State<CompletedTaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color peachColor = const Color(0xFFFFB5A7);
  final Color lightPeachColor = const Color(0xFFFFE5E0);
  final Color darkPeachColor = const Color(0xFFFF8576);

  String? get _currentUserId => _auth.currentUser?.uid;  //CurrentLogged-inUserInfo
  String? get _currentUserEmail => _auth.currentUser?.email;


  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final date = "${dateTime.month}/${dateTime.day}/${dateTime.year}";
    final time = "${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour < 12 ? 'AM' : 'PM'}";
    return 'Date: $date\nTime: $time';
  }
  String _formatDueDate(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    return DateFormat('MMMM d, yyyy').format(dateTime);
  }
  void _showTaskDetailsBottomSheet(Map<String, dynamic> taskData) {
    final createdAt = taskData['createdAt'] as Timestamp?;
    final updatedAt = taskData['updatedAt'] as Timestamp?;
    final dueDate = taskData['dueDate'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      backgroundColor: lightPeachColor,
      builder: (context) {
        return Container(
          width: MediaQuery.of(context).size.width * 0.95,
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightPeachColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Task Details',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Task Name: ',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: '${taskData['task']}',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Assigned To: ',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: '${taskData['assignedTo'] ?? 'Not assigned'}',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (dueDate != null) ...[
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Due Date: ',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: _formatDueDate(dueDate),
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Status: ',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: 'Completed',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (createdAt != null)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Created At: ',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: _formatTimestamp(createdAt),
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (updatedAt != null)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Completed At: ',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: _formatTimestamp(updatedAt),
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: peachColor,
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.poppins(color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(
          "Completed Tasks",
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _currentUserId == null || _currentUserEmail == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Please login to view your tasks',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Go to Login',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('todos')
            .where('isDone', isEqualTo: true)
            .where('assignedTo', isEqualTo: _currentUserEmail)
            .snapshots(),
        builder: (context, snapshot) {
          return snapshot.connectionState == ConnectionState.waiting
              ? const Center(
            child: CircularProgressIndicator(
              color: Colors.green,
            ),
          )
              : snapshot.hasError
              ? Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: GoogleFonts.poppins(),
            ),
          )
              : (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed tasks found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          )
              : _buildTasksList(snapshot.data!.docs, context);
        },
      ),
    );
  }
  Widget _buildTasksList(List<QueryDocumentSnapshot> tasks, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Your Completed Tasks (${tasks.length})',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(child: CircularProgressIndicator());
                }
                String userRole = snapshot.data!.get('role') ?? 'User';
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final taskId = task.id;
                    final taskData = task.data() as Map<String, dynamic>;
                    final taskTitle = taskData['task'];
                    final assignedTo = taskData['assignedTo'];
                    final completedAt = taskData['updatedAt'] as Timestamp?;
                    return Dismissible(
                      key: Key(taskId),
                      direction: userRole == "Manager"
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      background: Container(
                        color: Colors.red[400],
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: userRole == "Manager"
                          ? (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text(
                                'Delete Task',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                'Are you sure you want to delete this task?',
                                style: GoogleFonts.nunito(),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.poppins(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }
                          : null,
                      onDismissed: (direction) async {
                        await FirebaseFirestore.instance.collection('todos').doc(taskId).delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Task deleted'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        color: const Color(0xFFE8F5E9),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                          title: Text(
                            taskTitle,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned to: $assignedTo',
                                style: GoogleFonts.nunito(fontSize: 14, color: Colors.black54),
                              ),
                              if (completedAt != null)
                                Text(
                                  'Completed: ${DateFormat('MMM d, yyyy').format(completedAt.toDate())}',
                                  style: GoogleFonts.nunito(fontSize: 14, color: Colors.green[700]),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.message, color: Colors.black),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        // receiverId: userRole,
                                        receiverId: taskTitle,
                                        // receiverEmail: assignedTo,
                                        receiverEmail: taskId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: Colors.black54),
                                onPressed: () => _showTaskDetailsBottomSheet(taskData),
                              ),
                            ],
                          ),
                          onTap: () => _showTaskDetailsBottomSheet(taskData),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}