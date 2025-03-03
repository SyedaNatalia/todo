import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:new_project/screens/chat_screen.dart';
import 'package:new_project/screens/completed_tak/view/completed_task.dart';
import 'package:new_project/screens/login_screen.dart';
import 'package:new_project/screens/overdue_task.dart';
import 'package:new_project/screens/pending_task/view/pending_task.dart';
import 'package:new_project/screens/profile_screen.dart';
import 'package:new_project/services/auth_service.dart';

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
  DateTime? _selectedDueDate;

  //user current email
  String get currentUserEmail => FirebaseAuth.instance.currentUser?.email ?? '';
  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }
  Future<void> _selectDate(BuildContext context, StateSetter setDialogState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: peachColor,
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDueDate) {
      setDialogState(() {
        _selectedDueDate = picked;
      });
    }
  }
  Future<void> deleteTask(String taskId) async {
    try {
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;//GetCurrentUserID
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance//UserRole
          .collection('users')
          .doc(currentUserId)
          .get();
      if (!userSnapshot.exists) {
        throw Exception("User not found");
      }
      String userRole = userSnapshot.get('role') ?? 'User';
      if (userRole == "Manager") {
        await FirebaseFirestore.instance.collection('todos').doc(taskId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task deleted successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        throw Exception("Only Managers can delete tasks.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> showTaskDialog({
    String? taskId,
    String? currentTask,
    String? currentAssignee,
    DateTime? currentDueDate,
  }) async {
    _taskController.text = currentTask ?? '';
    String? selectedAssignee = currentAssignee ?? currentUserEmail;
    _selectedDueDate = currentDueDate;
    List<String> userEmails = [];
    bool isLoadingUsers = true;
    Future<void> fetchUsers() async {
      try {
        final QuerySnapshot userSnapshot = await _firestore.collection('users').get();
        userEmails = userSnapshot.docs
            .map((doc) => doc['email'] as String)
            .toList();
        if (selectedAssignee == null && userEmails.isNotEmpty) {
          selectedAssignee = currentUserEmail;
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
              content: SingleChildScrollView(
                child: Column(
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
                    InkWell(
                      onTap: () => _selectDate(context, setState),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due Date',
                          labelStyle: GoogleFonts.nunito(),
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: peachColor),
                          ),
                          suffixIcon: Icon(Icons.calendar_today, color: Colors.black54),
                        ),
                        child: Text(
                          _selectedDueDate == null
                              ? 'Select a due date'
                              : DateFormat('MMM d, yyyy').format(_selectedDueDate!),
                          style: GoogleFonts.nunito(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _taskController.clear();
                    _selectedDueDate = null;
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
                        selectedAssignee != null) {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        final pairString = '$selectedAssignee' '+' '$currentUserEmail';
                        final Map<String, dynamic> taskData = {
                          'task': _taskController.text.trim(),
                          'assignedTo': selectedAssignee,
                          'assignedBy': currentUserEmail,
                          'pair': pairString,
                          'updatedAt': Timestamp.now(),
                          'status': 'pending',
                        };
                        if (_selectedDueDate != null) {
                          taskData['dueDate'] = Timestamp.fromDate(_selectedDueDate!);}
                        if (taskId != null) {
                          await _firestore.collection('todos').doc(taskId).update(taskData);
                        } else {
                          taskData['isDone'] = false;
                          taskData['createdAt'] = Timestamp.now();
                          await _firestore.collection('todos').add(taskData);
                        }
                        _taskController.clear();
                        _selectedDueDate = null;
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
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    String userEmail = user?.email ?? '';
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight((_isLoading || _isRefreshing) ? 150 : 70),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return AppBar(
                backgroundColor: peachColor,
                title: Text("Task Categories", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                centerTitle: true,
              );
            }
            var userData = snapshot.data!;
            String userFirstName = userData['firstName'] ?? 'User';
            String userRole = userData['role'] ?? 'No role assigned';

            return AppBar(
              backgroundColor: peachColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome,$userFirstName", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text("$userRole", style: GoogleFonts.poppins(fontSize: 8, color: Colors.black)),
                  Text(userEmail, style: GoogleFonts.poppins(fontSize: 6, color: Colors.black)),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                  },
                  icon: const Icon(Icons.person, color: Colors.black),
                ),
                IconButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.black),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
                  },
                  icon: const Icon(Icons.chat, color: Colors.black),
                ),
              ],
              bottom: (_isLoading || _isRefreshing)
                  ? PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
                  : null,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                children: [
                  _buildTaskCard(
                    context,
                    title: "Completed Tasks",
                    icon: Icons.check_circle,
                    gradientColors: [Colors.green.withOpacity(0.7), Colors.green],
                    taskScreen: CompletedTaskScreen(),
                    query: FirebaseFirestore.instance.collection('todos').where('assignedTo', isEqualTo: userEmail).where('isDone', isEqualTo: true),
                  ),
                  _buildTaskCard(
                    context,
                    title: "Overdue Tasks",
                    icon: Icons.warning,
                    gradientColors: [Colors.red.withOpacity(0.7), Colors.red],
                    taskScreen: OverdueTaskScreen(),
                    query: FirebaseFirestore.instance.collection('todos').where('assignedTo', isEqualTo: userEmail).where('isDone', isEqualTo: false).where('dueDate', isLessThan: Timestamp.now()),
                  ),
                  _buildTaskCard(
                    context,
                    title: "Pending Tasks",
                    icon: Icons.pending_actions,
                    gradientColors: [Colors.orange.withOpacity(0.7), Colors.orange],
                    taskScreen: PendingTaskScreen(),
                    query: FirebaseFirestore.instance.collection('todos').where('assignedTo', isEqualTo: userEmail).where('isDone', isEqualTo: false).where('status', isEqualTo: 'pending'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTaskDialog(),
        backgroundColor: peachColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // Widget build(BuildContext context) {
  //   User? user = FirebaseAuth.instance.currentUser;
  //   String userEmail = user?.email ?? '';
  //   return Scaffold(
  //     appBar: PreferredSize(
  //       preferredSize: Size.fromHeight((_isLoading || _isRefreshing) ? 150 : 50),
  //       child: AppBar(
  //         backgroundColor: peachColor,
  //         shape: const RoundedRectangleBorder(
  //           borderRadius: BorderRadius.vertical(
  //             bottom: Radius.circular(30),
  //           ),
  //         ),
  //         title: Text(
  //           "Task Categories",
  //           style: GoogleFonts.poppins(
  //             fontSize: 15,
  //             fontWeight: FontWeight.bold,
  //             color: Colors.black,
  //           ),
  //         ),
  //         centerTitle: true,
  //         actions: [
  //           IconButton(
  //             onPressed: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(builder: (context) => const ProfileScreen()),
  //               );
  //             },
  //             icon: const Icon(Icons.person, color: Colors.black),
  //           ),
  //           IconButton(
  //             onPressed: () async {
  //               await AuthService().signOut();
  //               Navigator.pushReplacement(
  //                 context,
  //                 MaterialPageRoute(builder: (context) => const LoginScreen()),
  //               );
  //             },
  //             icon: const Icon(Icons.logout_rounded, color: Colors.black),
  //           ),
  //         ],
  //         bottom: (_isLoading || _isRefreshing)
  //             ? PreferredSize(
  //           preferredSize: const Size.fromHeight(100),
  //           child: Padding(
  //             padding: const EdgeInsets.only(bottom: 20.0),
  //             child: CircularProgressIndicator(
  //               color: Colors.white,
  //             ),
  //           ),
  //         )
  //             : null,
  //       ),
  //     ),
  //     body: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           StreamBuilder<DocumentSnapshot>(
  //             stream: FirebaseFirestore.instance
  //                 .collection('users')
  //                 .doc(user?.uid)
  //                 .snapshots(),
  //             builder: (context, snapshot) {
  //               if (snapshot.connectionState == ConnectionState.waiting) {
  //                 return CircularProgressIndicator();
  //               }
  //               if (!snapshot.hasData || !snapshot.data!.exists) {
  //                 return Text("User data not found.");
  //               }
  //               var userData = snapshot.data!;
  //               String userFirstName = userData['firstName'] ?? 'User';
  //               String userRole = userData['role'] ?? 'No role assigned';
  //               return Padding(
  //                 padding: const EdgeInsets.only(bottom: 16.0),
  //                 child: Text(
  //                   "Welcome, $userFirstName ($userRole)\n$userEmail",
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 12,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               );
  //             },
  //           ),
  //           Expanded(
  //             child: GridView.count(
  //               crossAxisCount: 2,
  //               crossAxisSpacing: 16.0,
  //               mainAxisSpacing: 16.0,
  //               children: [
  //                 _buildTaskCard(
  //                   context,
  //                   title: "Completed Tasks",
  //                   icon: Icons.check_circle,
  //                   gradientColors: [Colors.green.withOpacity(0.7), Colors.green],
  //                   taskScreen: CompletedTaskScreen(),
  //                   query: FirebaseFirestore.instance
  //                       .collection('todos')
  //                       .where('assignedTo', isEqualTo: userEmail)
  //                       .where('isDone', isEqualTo: true),
  //                 ),
  //                 _buildTaskCard(
  //                   context,
  //                   title: "Overdue Tasks",
  //                   icon: Icons.warning,
  //                   gradientColors: [Colors.red.withOpacity(0.7), Colors.red],
  //                   taskScreen: OverdueTaskScreen(),
  //                   query: FirebaseFirestore.instance
  //                       .collection('todos')
  //                       .where('assignedTo', isEqualTo: userEmail)
  //                       .where('isDone', isEqualTo: false)
  //                       .where('dueDate', isLessThan: Timestamp.now()),
  //                 ),
  //                 _buildTaskCard(
  //                   context,
  //                   title: "Pending Tasks",
  //                   icon: Icons.pending_actions,
  //                   gradientColors: [Colors.orange.withOpacity(0.7), Colors.orange],
  //                   taskScreen: PendingTaskScreen(),
  //                   query: FirebaseFirestore.instance
  //                       .collection('todos')
  //                       .where('assignedTo', isEqualTo: userEmail)
  //                       .where('isDone', isEqualTo: false)
  //                       .where('status', isEqualTo: 'pending'),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //     floatingActionButton: FloatingActionButton(
  //       onPressed: () => showTaskDialog(),
  //       backgroundColor: peachColor,
  //       child: const Icon(Icons.add, color: Colors.black),
  //     ),
  //   );
  // }
  Widget _buildTaskCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required List<Color> gradientColors,
        required Widget taskScreen,
        required Query query,
      }) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => taskScreen),
            );
          },
          child: Card(
            elevation: 4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 50.0, color: Colors.white),
                  const SizedBox(height: 8.0),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}