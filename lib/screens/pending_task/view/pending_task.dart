import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class PendingTaskScreen extends StatefulWidget {
  const PendingTaskScreen({Key? key}) : super(key: key);

  @override
  State<PendingTaskScreen> createState() => _PendingTaskScreenState();
}

class _PendingTaskScreenState extends State<PendingTaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color peachColor = const Color(0xFFFFB5A7);
  final Color lightPeachColor = const Color(0xFFFFE5E0);
  final Color darkPeachColor = const Color(0xFFFF8576);

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final date = "${dateTime.month}/${dateTime.day}/${dateTime.year}";
    final time = "${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour < 12 ? 'AM' : 'PM'}";
    return 'Date: $date\nTime: $time';
  }

  // Format due date
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
                      text: 'Pending',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.orange,
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
                        text: 'Last Updated: ',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _firestore.collection('todos').doc(taskData['id']).update({
                          'isDone': true,
                          'status': 'completed',
                          'updatedAt': Timestamp.now(),
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Task marked as completed!',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to update task. Please try again.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                    ),
                    child: Text(
                      'Mark Complete',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
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
        backgroundColor: Colors.orange,
        title: Text(
          "Pending Tasks",
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('todos')
            .where('isDone', isEqualTo: false)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.orange,
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
                'No pending tasks found.',
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
                final assignedTo = taskData['assignedTo'];
                final dueDate = taskData['dueDate'] as Timestamp?;

                final taskDataWithId = {...taskData, 'id': taskId};

                return Dismissible(
                  key: Key(taskId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.yellowAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (direction) {
                    _firestore.collection('todos').doc(taskId).delete();
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    color: const Color(0xFFFFF3E0), // Light orange background
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 30,
                      ),
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
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          if (dueDate != null)
                            Text(
                              'Due: ${DateFormat('MMM d, yyyy').format(dueDate.toDate())}',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: dueDate.toDate().isBefore(DateTime.now())
                                    ? Colors.red[700]  // Past due
                                    : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              try {
                                await _firestore.collection('todos').doc(taskId).update({
                                  'isDone': true,
                                  'status': 'completed',
                                  'updatedAt': Timestamp.now(),
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Task marked as completed!',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update task. Please try again.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline, color: Colors.black54),
                            onPressed: () => _showTaskDetailsBottomSheet(taskDataWithId),
                          ),
                        ],
                      ),
                      onTap: () => _showTaskDetailsBottomSheet(taskDataWithId),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}