import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatHomeScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> _getUserFirstName(String userId) async {
    var userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc['firstName'] ?? 'Unknown' : 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('chats').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var chats = snapshot.data!.docs;

          Map<String, DocumentSnapshot> userChats = {};

          for (var chat in chats) {
            var senderId = chat['senderId'];
            if (!userChats.containsKey(senderId)) {
              userChats[senderId] = chat;
            }
          }
          var uniqueChats = userChats.values.toList();

          return ListView.builder(
            itemCount: uniqueChats.length,
            itemBuilder: (context, index) {
              var chat = uniqueChats[index];
              var senderId = chat['senderId'];
              var lastMessage = chat['text'];

              return FutureBuilder<String>(
                future: _getUserFirstName(senderId),
                builder: (context, nameSnapshot) {
                  if (!nameSnapshot.hasData) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        child: Icon(Icons.person),
                      ),
                      title: Text('Loading...'),
                      subtitle: Text(lastMessage),
                      trailing: Text('12:00 PM'),
                    );
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person),
                    ),
                    title: Text(nameSnapshot.data!),
                    subtitle: Text(lastMessage),
                    trailing: Text('12:00 PM'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverId: senderId,
                            receiverEmail: nameSnapshot.data!,
                            taskId: 'assignedById', taskTitle: 'assignedByEmail',
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