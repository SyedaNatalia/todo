import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OverdueTaskScreen extends StatefulWidget {
  const OverdueTaskScreen({Key? key}) : super(key: key);

  @override
  State<OverdueTaskScreen> createState() => _OverdueTaskScreenState();
}

class _OverdueTaskScreenState extends State<OverdueTaskScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color redColor = const Color(0xFFF94144);
  final Color lightRedColor = const Color(0xFFF8D7DA);
  final Color darkRedColor = const Color(0xFFE63946);

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

  String _getDaysOverdue(Timestamp dueDate) {
    final now = DateTime.now();
    final due = dueDate.toDate();
    final difference = now.difference(due).inDays;

    if (difference == 0) {
      return "Due today";
    } else if (difference == 1) {
      return "1 day overdue";
    } else {
      return "$difference days overdue";
    }
  }

  void _showTaskDetailsBottomSheet(Map<String, dynamic> taskData) {
    final createdAt = taskData['createdAt'] as Timestamp?;
    final updatedAt = taskData['updatedAt'] as Timestamp?;
    final dueDate = taskData['dueDate'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      backgroundColor: lightRedColor,
      builder: (context) {
        return Container(
          width: MediaQuery.of(context).size.width * 0.95,
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightRedColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Overdue Task Details',
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
                          color: redColor,
                          fontWeight: FontWeight.bold,
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
                        text: 'Status: ',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      TextSpan(
                        text: _getDaysOverdue(dueDate),
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          color: redColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                    onPressed: () async {
                      try {
                        final now = DateTime.now();
                        final newDueDate = DateTime(now.year, now.month, now.day + 1);

                        await _firestore.collection('todos').doc(taskData['id']).update({
                          'dueDate': Timestamp.fromDate(newDueDate),
                          'updatedAt': Timestamp.now(),
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Task extended by 1 day!',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to extend task. Please try again.',
                              style: GoogleFonts.poppins(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[400],
                    ),
                    child: Text(
                      'Extend Due Date',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: redColor,
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(color: Colors.white),
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
    if (_currentUserEmail == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: redColor,
          title: Text(
            "Overdue Tasks",
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 60,
                color: redColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Please log in to view your tasks',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: redColor,
        title: Text(
          "Overdue Tasks",
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
            .where('assignedTo', isEqualTo: _currentUserEmail)
            .where('isDone', isEqualTo: false)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: redColor,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No overdue tasks!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re up to date with all your tasks.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }
          final allTasks = snapshot.data!.docs;
          final overdueTasks = allTasks.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dueDate = data['dueDate'] as Timestamp?;
            if (dueDate == null) return false;

            final now = DateTime.now();
            final dueDateTime = dueDate.toDate();
            final nowDate = DateTime(now.year, now.month, now.day);
            final dueDateOnly = DateTime(dueDateTime.year, dueDateTime.month, dueDateTime.day);
            return dueDateOnly.isBefore(nowDate);
          }).toList();
          if (overdueTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No overdue tasks!',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re up to date with all your tasks.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: lightRedColor,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: redColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: redColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'These tasks are past their due date and require immediate attention.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: overdueTasks.length,
                    itemBuilder: (context, index) {
                      final task = overdueTasks[index];
                      final taskId = task.id;
                      final taskData = task.data() as Map<String, dynamic>;
                      final taskTitle = taskData['task'];
                      final assignedTo = taskData['assignedTo'];
                      final dueDate = taskData['dueDate'] as Timestamp;
                      final taskDataWithId = {...taskData, 'id': taskId};
                      return Dismissible(
                        key: Key(taskId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red[300],
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          _firestore.collection('todos').doc(taskId).delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Task deleted',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor: Colors.grey[700],
                              action: SnackBarAction(
                                label: 'UNDO',
                                textColor: Colors.white,
                                onPressed: () {},
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          color: lightRedColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: redColor.withOpacity(0.3), width: 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Badge(
                              backgroundColor: redColor,
                              label: Text(
                                _getDaysOverdue(dueDate).contains("days")
                                    ? dueDate.toDate().difference(DateTime.now()).inDays.abs().toString()
                                    : "!",
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              child: Icon(
                                Icons.event_busy,
                                color: redColor,
                                size: 30,
                              ),
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
                                  'Due: ${DateFormat('MMM d, yyyy').format(dueDate.toDate())} (${_getDaysOverdue(dueDate)})',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    color: redColor,
                                    fontWeight: FontWeight.bold,
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
                                  icon: const Icon(Icons.update, color: Colors.blue),
                                  tooltip: 'Extend by 1 day',
                                  onPressed: () async {
                                    try {
                                      final now = DateTime.now();
                                      final newDueDate = DateTime(now.year, now.month, now.day + 1);
                                      await _firestore.collection('todos').doc(taskId).update({
                                        'dueDate': Timestamp.fromDate(newDueDate),
                                        'updatedAt': Timestamp.now(),
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Task extended by 1 day!',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.blue,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to extend task. Please try again.',
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}