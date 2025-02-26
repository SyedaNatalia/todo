import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_project/screens/profile_screen.dart';
import 'package:new_project/screens/widgets/custom_textfield.dart';
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

  bool _isLoading = false;
  bool _isRefreshing = false;

  String? _selectedUser;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> showTaskDialog({
    String? taskId,
    String? currentTask,
    String? currentAssignee,
    String? currentAssignedBy,
  }) async {
    _taskController.text = currentTask ?? '';
    String? selectedAssignee = currentAssignee;
    String? selectedAssignedBy = currentAssignedBy ?? FirebaseAuth.instance.currentUser?.email;
    List<String> userEmails = [];
    bool isLoadingUsers = true;

    Future<void> fetchUsers() async {
      try {
        final QuerySnapshot userSnapshot = await _firestore.collection('users').get();
        userEmails = userSnapshot.docs
            .map((doc) => doc['email'] as String)
            .toList();

        if (selectedAssignee == null && userEmails.isNotEmpty) {
          selectedAssignee = userEmails[0];
        }
        if (selectedAssignedBy == null && userEmails.isNotEmpty) {
          selectedAssignedBy = userEmails[0];
        }

        isLoadingUsers = false;
      } catch (e) {
        print('Error fetching users: $e');
        isLoadingUsers = false;
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {

            if (isLoadingUsers) {
              fetchUsers().then((_) {
                setState(() {});
              });
            }

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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
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
                  SizedBox(height: 16),
                  isLoadingUsers
                      ? CircularProgressIndicator(color: peachColor)
                      : DropdownButtonFormField<String>(
                    value: selectedAssignee,
                    decoration: InputDecoration(
                      labelText: 'Assigned to',
                      labelStyle: GoogleFonts.nunito(),
                      border: UnderlineInputBorder(),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: peachColor),
                      ),
                    ),
                    hint: Text('Select user', style: GoogleFonts.nunito()),
                    style: GoogleFonts.nunito(),
                    dropdownColor: peachColor,
                    items: userEmails.map((String email) {
                      return DropdownMenuItem<String>(
                        value: email,
                        child: Text(
                          email,
                          style: GoogleFonts.nunito(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedAssignee = newValue;
                      });
                    },
                    isExpanded: true,
                  ),
                  SizedBox(height: 16),
                  isLoadingUsers
                      ? CircularProgressIndicator(color: peachColor)
                      : DropdownButtonFormField<String>(
                    value: selectedAssignedBy,
                    decoration: InputDecoration(
                      labelText: 'Assigned by',
                      labelStyle: GoogleFonts.nunito(),
                      border: UnderlineInputBorder(),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: peachColor),
                      ),
                    ),
                    hint: Text('Select user', style: GoogleFonts.nunito()),
                    style: GoogleFonts.nunito(),
                    dropdownColor: peachColor,
                    items: userEmails.map((String email) {
                      return DropdownMenuItem<String>(
                        value: email,
                        child: Text(
                          email,
                          style: GoogleFonts.nunito(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedAssignedBy = newValue;
                      });
                    },
                    isExpanded: true,
                  ),
                ],
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
                    if (_taskController.text.isNotEmpty &&
                        selectedAssignee != null &&
                        selectedAssignedBy != null) {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        final pairString = '$selectedAssignee' '+' '$selectedAssignedBy';
                        if (taskId != null) {
                          await _firestore.collection('todos').doc(taskId).update({
                            'task': _taskController.text.trim(),
                            'assignedTo': selectedAssignee,
                            'assignedBy': selectedAssignedBy,
                            'pair': pairString,
                            'updatedAt': Timestamp.now(),
                          });
                        } else {
                          await _firestore.collection('todos').add({
                            'task': _taskController.text.trim(),
                            'assignedTo': selectedAssignee,
                            'assignedBy': selectedAssignedBy,
                            'pair': pairString,
                            'isDone': false,
                            'createdAt': Timestamp.now(),
                            'updatedAt': Timestamp.now(),
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
                          _isLoading = false;
                        });
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please fill all required fields',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
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

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final date = "${dateTime.month}/${dateTime.day}/${dateTime.year}";
    final time = "${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour < 12 ? 'AM' : 'PM'}";
    return 'Date: $date\nTime: $time';
  }

  void _showTaskDetailsBottomSheet(Map<String, dynamic> taskData) {
    final createdAt = taskData['createdAt'] as Timestamp?;
    final updatedAt = taskData['updatedAt'] as Timestamp?;

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
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Assigned By: ',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: '${taskData['assignedBy'] ?? 'Not assigned'}',
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
                      text: 'Status: ',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: '${taskData['isDone'] ? 'Done' : 'Not Done'}',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: Colors.black,
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
                        text: 'Updated At: ',
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

  //@override
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
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
              icon: const Icon(Icons.person, color: Colors.black),
            ),
            // Logout Icon
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
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
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
                        final assignedTo = taskData['assignedTo'];

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
                              subtitle: Text(
                                'Assigned to: $assignedTo',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.black54),
                                    onPressed: () => showTaskDialog(
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
                              onTap: () {
                                _showTaskDetailsBottomSheet(taskData);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          // Add a button at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomTextFieldScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: peachColor,
                minimumSize: const Size(50, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(
                Icons.list,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTaskDialog(),
        backgroundColor: peachColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}