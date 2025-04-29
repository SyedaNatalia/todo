import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:new_project/screens/chat_home.dart';
import 'package:new_project/screens/completed_task.dart';
import 'package:new_project/screens/login_screen.dart';
import 'package:new_project/screens/overdue_task.dart';
import 'package:new_project/screens/pending_task.dart';
import 'package:new_project/screens/profile_screen.dart';
import 'package:new_project/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _taskController = TextEditingController();
  final String _staticAvatarAsset = 'assets/images/avatar_image.webp';
  final Color IndigoBlueColor = const Color(0xFF79B2EC);


  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingContent = true;

  String? _profileImagePath;
  String? selectedUser;
  DateTime? _selectedDueDate;

  // User current email
  String get currentUserEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadRemainingContent();
  }

  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _profileImagePath = prefs.getString('profile_image_path');
      });
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> _loadRemainingContent() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isLoadingContent = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading content',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              primary: IndigoBlueColor,
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
      String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (!userSnapshot.exists) {
        throw Exception("User not found");
      }

      String userRole = userSnapshot.get('role') ?? 'User';

      // Allow both Manager and Team Lead to delete tasks
      if (userRole == "Manager" || userRole == "Team Lead") {
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
        throw Exception("Only Managers and Team Leads can delete tasks.");
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
    Map<String, String> userRoles = {};
    bool isLoadingUsers = true;

    String currentUserRole = 'User';

    Future<void> fetchUsers() async {
      try {
        final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final DocumentSnapshot currentUserSnapshot = await _firestore
            .collection('users')
            .doc(currentUserId)
            .get();

        if (currentUserSnapshot.exists) {
          currentUserRole = currentUserSnapshot.get('role') ?? 'User';
        }

        final QuerySnapshot userSnapshot = await _firestore.collection('users').get();

        for (var doc in userSnapshot.docs) {
          String email = doc['email'] as String;
          String role = doc['role'] as String;

          userRoles[email] = role;

          if (currentUserRole == 'Manager') {
            if (email != currentUserEmail) {
              userEmails.add(email);
            }
          } else if (currentUserRole == 'Team Lead') {
            // Team Leads can assign to Employees and Interns
            if ((role == 'Employee' || role == 'Intern') && email != currentUserEmail) {
              userEmails.add(email);
            }
          } else if (currentUserRole == 'Employee') {
            // Employees can only assign to Interns
            if (role == 'Intern' && email != currentUserEmail) {
              userEmails.add(email);
            }
          }
        }

        if (currentAssignee == null && userEmails.isNotEmpty) {
          selectedAssignee = userEmails.first;
        } else if (userEmails.isEmpty) {
          selectedAssignee = null;
        }

        isLoadingUsers = false;
      } catch (e) {
        print('Error fetching users: $e');
        isLoadingUsers = false;
      }
    }

    await fetchUsers();
    if (currentUserRole == 'Intern') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Interns are not allowed to assign tasks',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userEmails.isEmpty && currentUserRole != 'Intern') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No users available to assign tasks to',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoadingUsers) {
              return AlertDialog(
                backgroundColor: IndigoBlueColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                content: Container(
                  width: double.maxFinite,
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: IndigoBlueColor,
                    ),
                  ),
                ),
              );
            }
            return AlertDialog(
              backgroundColor: IndigoBlueColor,
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
                          borderSide: BorderSide(color: IndigoBlueColor),
                        ),
                      ),
                      autofocus: true,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedAssignee,
                      decoration: InputDecoration(
                        labelText: 'Assigned to',
                        labelStyle: GoogleFonts.nunito(),
                        border: UnderlineInputBorder(),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: IndigoBlueColor),
                        ),
                      ),
                      hint: Text('Select user', style: GoogleFonts.nunito()),
                      style: GoogleFonts.nunito(),
                      dropdownColor: IndigoBlueColor,
                      items: userEmails.map((String email) {
                        String roleText = userRoles[email] != null ? ' (${userRoles[email]})' : '';
                        return DropdownMenuItem<String>(
                          value: email,
                          child: Text(
                            email + roleText,
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
                            borderSide: BorderSide(color: IndigoBlueColor),
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
                          taskData['dueDate'] = Timestamp.fromDate(_selectedDueDate!);
                        }
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
        drawer: Drawer(
          child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: IndigoBlueColor),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      'HRM',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 5,
                    left: 5,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: AssetImage(_staticAvatarAsset),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 50,
                    left: 120,
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'User',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              Text(
                                'No role assigned',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          );
                        }
                        var userData = snapshot.data!;
                        String userFirstName = userData['firstName'] ?? 'User';
                        String userRole = userData['role'] ?? 'No role assigned';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              userFirstName,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              userRole,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_outlined),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('Completed Tasks'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CompletedTaskScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.pending_actions_outlined),
              title: Text('Pending Tasks'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PendingTaskScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Overdue Tasks'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OverdueTaskScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.chat_outlined),
              title: Text('Chat'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatHomeScreen()),
                );                   },
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded),
              title: Text('Logout'),
              onTap: () async {
                await AuthService().signOut();
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );                   },
            ),
          ],
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight((_isLoading || _isRefreshing) ? 150 : 200),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {

              return AppBar(
                backgroundColor: IndigoBlueColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
                ),
                title: Text(
                  "HRM",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                centerTitle: true,
              );
            }

            var userData = snapshot.data!;
            String userFirstName = userData['firstName'] ?? 'User';
            String userRole = userData['role'] ?? 'No role assigned';

            return AppBar(
              backgroundColor: IndigoBlueColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "HRM",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              flexibleSpace: Stack(
                children: [

                  Positioned(
                    bottom: 15,
                    left: 18,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileScreen()),
                        );
                      },
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: AssetImage(_staticAvatarAsset),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 50,
                    left: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          userFirstName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          userRole,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChatHomeScreen()),
                    );
                  },
                  icon: const Icon(Icons.chat_outlined, color: Colors.black),
                ),
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
            );
          },
        ),
      ),
      body: _isLoadingContent
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: IndigoBlueColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading content...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: IndigoBlueColor,
              ),
            ),
          ],
        ),
      )
          : Padding(
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
                    gradientColors: [Colors.blue.withOpacity(0.7), Colors.green],
                    taskScreen: CompletedTaskScreen(),
                    query: FirebaseFirestore.instance
                        .collection('todos')
                        .where('assignedTo', isEqualTo: userEmail)
                        .where('isDone', isEqualTo: true),
                  ),
                  _buildTaskCard(
                    context,
                    title: "Pending Tasks",
                    icon: Icons.pending_actions,
                    gradientColors: [Colors.blue.withOpacity(0.7), Colors.orange],
                    taskScreen: PendingTaskScreen(),
                    query: FirebaseFirestore.instance
                        .collection('todos')
                        .where('assignedTo', isEqualTo: userEmail)
                        .where('isDone', isEqualTo: false)
                        .where('status', isEqualTo: 'pending'),
                  ),
                  _buildTaskCard(
                    context,
                    title: "Overdue Tasks",
                    icon: Icons.warning,
                    gradientColors: [Colors.blue.withOpacity(0.7), Colors.red],
                    taskScreen: OverdueTaskScreen(),
                    query: FirebaseFirestore.instance
                        .collection('todos')
                        .where('assignedTo', isEqualTo: userEmail)
                        .where('isDone', isEqualTo: false)
                        .where('dueDate', isLessThan: Timestamp.now()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(

        stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return FloatingActionButton(
              onPressed: null,
              backgroundColor: Colors.grey,
              child: const CircularProgressIndicator(color: Colors.white),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          String userRole = snapshot.data!.get('role') ?? 'User';

          if (userRole == 'Manager' || userRole == 'Team Lead' || userRole == 'Employee') {
            String tooltipText = '';
            if (userRole == 'Manager') {
              tooltipText = 'Assign task to anyone';
            } else if (userRole == 'Team Lead') {
              tooltipText = 'Assign task to Employees and Interns';
            } else {
              tooltipText = 'Assign task to Interns';
            }

            return FloatingActionButton(
              onPressed: () => showTaskDialog(),
              backgroundColor: IndigoBlueColor,
              tooltip: tooltipText,
              child: Icon(Icons.add, color: Colors.black),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

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
