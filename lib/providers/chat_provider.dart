import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../models/chat_msg_model.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<Conversation> _conversations = [];
  List<ChatMessage> _messages = [];
  List<UserModel> _chatUsers = [];
  UserModel? _selectedUser;
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  List<Conversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  List<UserModel> get chatUsers => _chatUsers;
  UserModel? get selectedUser => _selectedUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserEmail => _auth.currentUser?.email ?? '';

  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;

  // Constructor
  ChatProvider() {
    // Initialize when provider is created
    if (_auth.currentUser != null) {
      initialize();
    }

    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        initialize();
      } else {
        _cleanupResources();
      }
    });
  }

  // Set selected user for chat
  void setSelectedUser(UserModel user) {
    _selectedUser = user;
    notifyListeners();

    // Get conversation with this user
    Conversation? conversation = getConversationWithUser(user.email);
    if (conversation != null) {
      listenToMessages(conversation.id);
    }
  }

  // Initialize chat data
  Future<void> initialize() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await fetchChatUsers();
      _listenToConversations();
    } catch (e) {
      _errorMessage = 'Error initializing chat provider: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Fetch all users except current user
  Future<void> fetchChatUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isNotEqualTo: currentUserEmail)
          .get();

      _chatUsers = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching chat users: $e';
      print(_errorMessage);
    }
  }

  // Listen to user's conversations
  void _listenToConversations() {
    if (_conversationsSubscription != null) {
      _conversationsSubscription!.cancel();
    }

    _conversationsSubscription = _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserEmail)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .listen((snapshot) {
      _conversations = snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc.data(), doc.id))
          .toList();

      notifyListeners();
    }, onError: (e) {
      _errorMessage = 'Error listening to conversations: $e';
      print(_errorMessage);
    });
  }

  // Listen to messages in a specific conversation
  void listenToMessages(String conversationId) {
    if (_messagesSubscription != null) {
      _messagesSubscription!.cancel();
    }

    _messagesSubscription = _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
          .toList();

      notifyListeners();

      // Mark messages as read if they were sent to current user
      _markMessagesAsRead(conversationId);
    }, onError: (e) {
      _errorMessage = 'Error listening to messages: $e';
      print(_errorMessage);
    });
  }

  // Get or create conversation between two users
  Future<String> getOrCreateConversation(String otherUserEmail) async {
    try {
      // Check if conversation already exists
      final querySnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserEmail)
          .get();

      for (var doc in querySnapshot.docs) {
        List<String> participants = List<String>.from(doc['participants']);
        if (participants.contains(otherUserEmail)) {
          return doc.id;
        }
      }

      // Create new conversation if none exists
      final convoRef = await _firestore.collection('conversations').add({
        'participants': [currentUserEmail, otherUserEmail],
        'lastMessage': '',
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': '',
        'unreadMessages': false,
      });

      return convoRef.id;
    } catch (e) {
      _errorMessage = 'Error getting or creating conversation: $e';
      print(_errorMessage);
      throw e;
    }
  }

  // Send a text message
  Future<void> sendMessage({
    required String receiverEmail,
    required String receiverId,
    required String message,
  }) async {
    if (message.trim().isEmpty) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      // Get or create conversation
      final conversationId = await getOrCreateConversation(receiverEmail);

      // Create message
      final newMessage = {
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'receiverEmail': receiverEmail,
        'message': message,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'conversationId': conversationId,
        'type': 'text',
      };

      // Add message to Firestore
      await _firestore.collection('messages').add(newMessage);

      // Update conversation with last message info
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': message,
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': currentUserId,
        'unreadMessages': true,
      });

    } catch (e) {
      _errorMessage = 'Error sending message: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Send an image message
  Future<void> sendImageMessage({
    required String receiverEmail,
    required String receiverId,
    required File imageFile,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Get or create conversation
      final conversationId = await getOrCreateConversation(receiverEmail);

      // Upload image to Firebase Storage
      final storageRef = _storage.ref().child('chat_images')
          .child('${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}');

      final uploadTask = storageRef.putFile(imageFile);
      final taskSnapshot = await uploadTask;
      final imageUrl = await taskSnapshot.ref.getDownloadURL();

      // Create message with image URL
      final newMessage = {
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'receiverEmail': receiverEmail,
        'message': 'Sent an image',
        'imageUrl': imageUrl,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'conversationId': conversationId,
        'type': 'image',
      };

      // Add message to Firestore
      await _firestore.collection('messages').add(newMessage);

      // Update conversation with last message info
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': 'Sent an image',
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': currentUserId,
        'unreadMessages': true,
      });

    } catch (e) {
      _errorMessage = 'Error sending image: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Send a voice message
  Future<void> sendVoiceMessage({
    required String receiverEmail,
    required String receiverId,
    required File audioFile,
    required Duration duration,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Get or create conversation
      final conversationId = await getOrCreateConversation(receiverEmail);

      // Upload voice note to Firebase Storage
      final storageRef = _storage.ref().child('voice_messages')
          .child('${DateTime.now().millisecondsSinceEpoch}_${audioFile.path.split('/').last}');

      final uploadTask = storageRef.putFile(audioFile);
      final taskSnapshot = await uploadTask;
      final audioUrl = await taskSnapshot.ref.getDownloadURL();

      // Create message with audio URL
      final newMessage = {
        'senderId': currentUserId,
        'senderEmail': currentUserEmail,
        'receiverId': receiverId,
        'receiverEmail': receiverEmail,
        'message': 'Sent a voice message',
        'audioUrl': audioUrl,
        'audioDuration': duration.inSeconds,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'conversationId': conversationId,
        'type': 'voice',
      };

      // Add message to Firestore
      await _firestore.collection('messages').add(newMessage);

      // Update conversation with last message info
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': 'Sent a voice message',
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': currentUserId,
        'unreadMessages': true,
      });

    } catch (e) {
      _errorMessage = 'Error sending voice message: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Mark messages as read
  Future<void> _markMessagesAsRead(String conversationId) async {
    try {
      // Get all unread messages sent to current user
      final unreadMessages = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      // Mark each message as read
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // If there are unread messages, update the conversation
      if (unreadMessages.docs.isNotEmpty) {
        batch.update(
            _firestore.collection('conversations').doc(conversationId),
            {'unreadMessages': false}
        );
      }

      await batch.commit();
    } catch (e) {
      _errorMessage = 'Error marking messages as read: $e';
      print(_errorMessage);
    }
  }

  // Get conversation with specific user
  Conversation? getConversationWithUser(String userEmail) {
    for (var conversation in _conversations) {
      if (conversation.participants.contains(userEmail)) {
        return conversation;
      }
    }
    return null;
  }

  // Get unread messages count for all conversations
  int getTotalUnreadCount() {
    int count = 0;
    for (var conversation in _conversations) {
      if (conversation.unreadMessages && conversation.lastMessageSenderId != currentUserId) {
        count++;
      }
    }
    return count;
  }

  // Delete a message (if allowed)
  Future<void> deleteMessage(String messageId) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      // Get the message to check if current user is the sender
      final messageDoc = await _firestore.collection('messages').doc(messageId).get();

      if (!messageDoc.exists) {
        _errorMessage = 'Message not found';
        return;
      }

      final messageData = messageDoc.data() as Map<String, dynamic>;

      // Only allow deleting if current user is the sender
      if (messageData['senderId'] != currentUserId) {
        _errorMessage = 'You can only delete your own messages';
        return;
      }

      // Delete the message
      await _firestore.collection('messages').doc(messageId).delete();

      // Find if it was the last message in the conversation
      final conversationId = messageData['conversationId'];
      final conversation = await _firestore.collection('conversations').doc(conversationId).get();

      if (conversation.exists) {
        final conversationData = conversation.data() as Map<String, dynamic>;

        // If this was the last message, update the conversation with the previous message
        if (conversationData['lastMessageSenderId'] == currentUserId) {
          // Get the new last message
          final lastMessages = await _firestore
              .collection('messages')
              .where('conversationId', isEqualTo: conversationId)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (lastMessages.docs.isNotEmpty) {
            final newLastMessage = lastMessages.docs.first.data();
            await _firestore.collection('conversations').doc(conversationId).update({
              'lastMessage': newLastMessage['message'],
              'lastMessageTime': newLastMessage['timestamp'],
              'lastMessageSenderId': newLastMessage['senderId'],
            });
          } else {
            // If no messages left, reset conversation
            await _firestore.collection('conversations').doc(conversationId).update({
              'lastMessage': '',
              'lastMessageTime': Timestamp.now(),
              'lastMessageSenderId': '',
              'unreadMessages': false,
            });
          }
        }
      }

    } catch (e) {
      _errorMessage = 'Error deleting message: $e';
      print(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Clean up resources when user logs out
  void _cleanupResources() {
    _messages = [];
    _conversations = [];
    _chatUsers = [];
    _selectedUser = null;

    // Cancel all stream subscriptions
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();

    notifyListeners();
  }

  // Override dispose method
  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Clear error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
