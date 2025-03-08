import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverEmail;
  final String? taskId;
  final String? taskTitle;
  final Map<String, dynamic> todoData;

  const ChatScreen({Key? key,
    required this.receiverId,
    required this.receiverEmail,
    this.taskId,
    this.taskTitle,
  required this.todoData}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      String userId = _auth.currentUser?.uid ?? '';
      String userEmail = _auth.currentUser?.email ?? 'Unknown';

      await _firestore.collection('chats').add({
        'text': _messageController.text.trim(),
        'senderId': userId,
        'receiverId': widget.todoData['assignedBy'],
        'senderEmail': userEmail,
        'receiverEmail': widget.todoData['assignedBy'],
        'timestamp': FieldValue.serverTimestamp(),

        if (widget.taskId != null) 'taskId': widget.taskId,
        if (widget.taskTitle != null) 'taskTitle': widget.taskTitle,
      });

      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String userId = _auth.currentUser?.uid ?? '';
    print("Todo data ${widget.todoData}");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.todoData['assignedBy'],
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.taskTitle != null)
              Text(
                'Re: ${widget.taskTitle}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
              ),
          ],
        ),
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
      body: Column(
        children: [
          if (widget.taskTitle != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(Icons.task_alt, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discussing task: ${widget.taskTitle}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;

                  bool isPairMatch = (data['senderId'] == userId && data['receiverId'] == widget.todoData['assignedBy']) ||
                      (data['senderId'] == widget.todoData['assignedBy'] && data['receiverId'] == userId);

                  return isPairMatch;
                }).toList();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index].data() as Map<String, dynamic>;
                    var messageText = messageData['text'] as String;
                    var senderId = messageData['senderId'] as String;
                    var senderEmail = messageData['senderEmail'] as String? ?? 'Unknown';
                    var timestamp = messageData['timestamp'] as Timestamp?;

                    bool isMe = senderId == userId;
                    String timeString = timestamp == null
                        ? 'Sending...'
                        : DateFormat('h:mm a').format(timestamp.toDate());
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only
                          (top: 4,
                        bottom: 4,
                        left: isMe ? 80 : 10,
                        right: isMe ? 10 : 80,),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[300] : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : senderEmail.split('@').first,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Colors.white : Colors.black87
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              messageText,
                              style: TextStyle(fontSize: 16, color: isMe ? Colors.white : Colors.black),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Text(
                                timeString,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.black54
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Enter message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
                IconButton( onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}