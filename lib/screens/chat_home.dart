import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

class ChatHomeScreen extends StatelessWidget {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<String> getUserFirstName(String userId) async {
    var userDoc = await firestore.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc['firstName'] ?? 'Unknown' : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    User? currentUser = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF9DCEFF),

        title: Text(
          "Chats",
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
        stream: firestore
            .collection('todos')
            .where('assignedBy', isEqualTo: currentUser?.email)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var tasks = snapshot.data!.docs;
          Set<String> assignedUsers = {};
          List<Map<String,dynamic>> todoData = [];

          for (var task in tasks) {
            final todo = task.data();
            var assignedTo = task['assignedTo'];
            if (assignedTo != null && assignedTo != currentUser?.email) {
              assignedUsers.add(assignedTo);
              todoData.add(todo as Map<String,dynamic>);
            //  print("data $todo");
            }
          }

          if (assignedUsers.isEmpty) {
            return Center(
              child: Text(
                "No Chats Available",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            itemCount: assignedUsers.length,
            itemBuilder: (context, index) {
              String assignedUserEmail = assignedUsers.elementAt(index);

              return FutureBuilder<QuerySnapshot>(
                future: firestore
                    .collection('users')
                    .where('email', isEqualTo: assignedUserEmail)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                    return SizedBox.shrink();
                  }

                  var userDoc = userSnapshot.data!.docs.first;
                  String assignedUserId = userDoc.id;
                  String assignedUserName = userDoc['firstName'] ?? 'Unknown';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person),
                    ),
                    title: Text(assignedUserName),
                    subtitle: Text("Tap to chat"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            todoData: todoData[index],
                            //{
                              // 'assignedBy': tasks['assignedBy'],
                              // 'assignedTo': tasks ['assignedTo'],
                              // // 'taskId': ,
                              // // 'taskTitle': chats['taskTitle']!,
                           // },
                            receiverId: assignedUserId,
                            receiverEmail: assignedUserEmail,
                            taskId: '',
                            taskTitle: '',
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
