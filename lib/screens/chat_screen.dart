import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';


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

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  List<Map<String, dynamic>> _localVoiceNotes = [];
  Set<String> _firestoreMessageIds = {};

  @override
  void initState() {
    super.initState();
    _loadLocalVoiceNotes();
  }

  Future<void> _sendImageMessage(String imageUrl) async {
    String userId = _auth.currentUser?.uid ?? '';
    String userEmail = _auth.currentUser?.email ?? 'Unknown';

    await _firestore.collection('chats').add({
      'text': '',
      'senderId': userId,
      'receiverId': widget.todoData['assignedBy'],
      'senderEmail': userEmail,
      'receiverEmail': widget.todoData['assignedBy'],
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': 'image',
      'imageUrl': imageUrl,
      if (widget.taskId != null) 'taskId': widget.taskId,
      if (widget.taskTitle != null) 'taskTitle': widget.taskTitle,
    });

    _scrollToBottom();
  }

  Future<void> _loadLocalVoiceNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String chatId = _getChatId();
    final String? voiceNotesJson = prefs.getString('voice_notes_$chatId');

    if (voiceNotesJson != null) {
      setState(() {
        _localVoiceNotes = List<Map<String, dynamic>>.from(
            json.decode(voiceNotesJson).map((item) => Map<String, dynamic>.from(item))
        );
      });
    }
  }

  Future<void> _saveLocalVoiceNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String chatId = _getChatId();
    await prefs.setString('voice_notes_$chatId', json.encode(_localVoiceNotes));
  }

  String _getChatId() {
    String userId = _auth.currentUser?.uid ?? '';
    List<String> ids = [userId, widget.todoData['assignedBy']];
    ids.sort();
    return ids.join('_');
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> convertVoiceNoteToBase64(String filePath) async {
    try {
      File audioFile = File(filePath);
      if (await audioFile.exists()) {
        List<int> audioBytes = await audioFile.readAsBytes();
        return base64Encode(audioBytes);
      } else {
        print('Audio file does not exist at path: $filePath');
        return null;
      }
    } catch (e) {
      print('Error converting voice note to base64: $e');
      return null;
    }
  }

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
        'messageType': 'text',
        if (widget.taskId != null) 'taskId': widget.taskId,
        if (widget.taskTitle != null) 'taskTitle': widget.taskTitle,
      });

      _messageController.clear();
      _scrollToBottom();
    }
  }

  Future<void> _sendVoiceNote(String filePath, String base64Audio, int duration, {bool saveLocally = false}) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      String userEmail = _auth.currentUser?.email ?? 'Unknown';

      String messageId = 'voice_${DateTime.now().millisecondsSinceEpoch}';

      DocumentReference docRef = await _firestore.collection('chats').add({
        'id': messageId,
        'senderId': userId,
        'receiverId': widget.todoData['assignedBy'],
        'senderEmail': userEmail,
        'receiverEmail': widget.todoData['assignedBy'],
        'timestamp': FieldValue.serverTimestamp(),
        'messageType': 'voice',
        'base64Audio': base64Audio,
        'duration': duration,
        if (widget.taskId != null) 'taskId': widget.taskId,
        if (widget.taskTitle != null) 'taskTitle': widget.taskTitle,
      });

      setState(() {
        _firestoreMessageIds.add(docRef.id);
      });

      if (saveLocally) {
        await _saveVoiceNoteLocally(filePath, base64Audio, duration, messageId);
      }

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note sent successfully')),
      );
    } catch (e) {
      print('Error sending voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send voice note: ${e.toString()}')),
      );
    }
  }

  void _scrollToBottom() {
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

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        _recordingPath = '${appDocDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

        print('Starting recording to path: $_recordingPath');

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
        });
      } else {
        print('No recording permission granted');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission to record audio was denied')),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: ${e.toString()}')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      print('Stopping recording');
      String? path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null && path.isNotEmpty) {
        print('Recording stopped. File path: $path');
        File audioFile = File(path);
        if (await audioFile.exists()) {
          print('Audio file exists with size: ${await audioFile.length()} bytes');
          await _processVoiceNote(path);
        } else {
          print('Audio file does not exist at path: $path');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed: File not found')),
          );
        }
      } else {
        print('No recording path returned');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording failed: No file created')),
        );
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process recording: ${e.toString()}')),
      );
    }
  }

  Future<void> _processVoiceNote(String filePath) async {
    try {
      String? base64Audio = await convertVoiceNoteToBase64(filePath);
      if (base64Audio == null) {
        throw Exception('Failed to convert audio to base64');
      }

      int duration = _calculateDuration();

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Voice Note Options'),
            content: const Text('What would you like to do with this voice note?'),
            actions: [
              TextButton(
                child: const Text('Save Locally'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _saveVoiceNoteLocally(filePath, base64Audio, duration);
                },
              ),
              TextButton(
                child: const Text('Send Now'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _sendVoiceNote(filePath, base64Audio, duration);
                },
              ),
              TextButton(
                child: const Text('Save and Send'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _sendVoiceNote(filePath, base64Audio, duration, saveLocally: true);
                },
              ),
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error processing voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process voice note: ${e.toString()}')),
      );
    }
  }

  Future<void> _saveVoiceNoteLocally(String filePath, String base64Audio, int duration, [String? customMessageId]) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      String userEmail = _auth.currentUser?.email ?? 'Unknown';
      String messageId = customMessageId ?? 'voice_${DateTime.now().millisecondsSinceEpoch}';

      Map<String, dynamic> voiceNote = {
        'id': messageId,
        'senderId': userId,
        'senderEmail': userEmail,
        'receiverId': widget.todoData['assignedBy'],
        'receiverEmail': widget.todoData['assignedBy'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messageType': 'voice',
        'filePath': filePath,
        'base64Audio': base64Audio,
        'duration': duration,
        if (widget.taskId != null) 'taskId': widget.taskId,
        if (widget.taskTitle != null) 'taskTitle': widget.taskTitle,
      };

      setState(() {
        _localVoiceNotes.add(voiceNote);
      });

      await _saveLocalVoiceNotes();

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note saved locally')),
      );

    } catch (e) {
      print('Error saving voice note locally: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save voice note: ${e.toString()}')),
      );
    }
  }

  int _calculateDuration() {
    if (_recordingStartTime == null) {
      return 0;
    }

    return DateTime.now().difference(_recordingStartTime!).inMilliseconds;
  }

  Future<void> _playVoiceMessage(String messageId, {String? filePath, String? base64Audio}) async {
    if (_currentlyPlayingId == messageId) {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingId = null;
      });
      return;
    }

    if (_currentlyPlayingId != null) {
      await _audioPlayer.stop();
    }

    setState(() {
      _currentlyPlayingId = messageId;
    });

    try {
      if (filePath != null && File(filePath).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(filePath));
      } else if (base64Audio != null) {
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = '${tempDir.path}/temp_audio_$messageId.m4a';

        File tempFile = File(tempPath);
        await tempFile.writeAsBytes(base64Decode(base64Audio));

        await _audioPlayer.play(DeviceFileSource(tempPath));
      } else {
        throw Exception('No valid audio source provided');
      }

      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _currentlyPlayingId = null;
        });
      });
    } catch (e) {
      print('Error playing audio: $e');
      setState(() {
        _currentlyPlayingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play voice note: ${e.toString()}')),
      );
    }
  }

  String _formatDuration(int milliseconds) {
    int seconds = (milliseconds / 1000).floor();
    int minutes = (seconds / 60).floor();
    seconds = seconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      processSelectedImage(image);
    }
  }

  Future<void> pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      processSelectedImage(photo);
    }
  }

  Future<void> processSelectedImage(XFile imageFile) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String imagePath = '${appDocDir.path}/image_${DateTime.now().millisecondsSinceEpoch}.png';
      final File image = File(imagePath);
      await image.writeAsBytes(await imageFile.readAsBytes());

      await _sendImageMessage(imagePath);

      setState(() {});
    } catch (e) {
      print('Error processing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String userId = _auth.currentUser?.uid ?? '';

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

                List<Map<String, dynamic>> combinedMessages = [];
                _firestoreMessageIds.clear();

                for (var message in messages) {
                  var data = message.data() as Map<String, dynamic>;
                  _firestoreMessageIds.add(message.id);

                  String? customId = data['id'] as String?;

                  combinedMessages.add({
                    ...data,
                    'id': message.id,
                    'customId': customId,
                    'source': 'firestore',
                    'timestamp': data['timestamp'] ?? Timestamp.now(),
                  });
                }

                for (var voiceNote in _localVoiceNotes) {
                  String voiceNoteId = voiceNote['id'] as String;
                  bool alreadyInFirestore = false;

                  for (var firestoreMsg in combinedMessages) {
                    if (firestoreMsg['customId'] == voiceNoteId) {
                      alreadyInFirestore = true;
                      break;
                    }
                  }

                  if (!alreadyInFirestore) {
                    combinedMessages.add({
                      ...voiceNote,
                      'source': 'local',
                      'timestamp': Timestamp.fromMillisecondsSinceEpoch(voiceNote['timestamp']),
                    });
                  }
                }

                combinedMessages.sort((a, b) {
                  Timestamp timestampA = a['timestamp'] as Timestamp;
                  Timestamp timestampB = b['timestamp'] as Timestamp;
                  return timestampA.compareTo(timestampB);
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: combinedMessages.length,
                  itemBuilder: (context, index) {
                    var messageData = combinedMessages[index];
                    var messageId = messageData['id'] as String;
                    var senderId = messageData['senderId'] as String;
                    var senderEmail = messageData['senderEmail'] as String? ?? 'Unknown';
                    var timestamp = messageData['timestamp'] as Timestamp;
                    var messageType = messageData['messageType'] as String? ?? 'text';
                    var messageSource = messageData['source'] as String;

                    bool isMe = senderId == userId;
                    String timeString = DateFormat('h:mm a').format(timestamp.toDate());

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                          left: isMe ? 80 : 10,
                          right: isMe ? 10 : 80,
                        ),
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
                            if (messageType == 'text')
                              Text(
                                messageData['text'] as String,
                                style: TextStyle(fontSize: 16, color: isMe ? Colors.white : Colors.black),
                              )
                            else if (messageType == 'voice')
                              _buildVoiceMessageWidget(messageData, messageId, isMe)
                            else if (messageType == 'image')
                                _buildImageMessageWidget(messageData, isMe),
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
                Tooltip(
                  message: 'Press and hold to record voice message',
                  child: GestureDetector(
                    onLongPress: _isRecording ? null : _startRecording,
                    onLongPressEnd: (_) => _isRecording ? _stopRecording() : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.all(_isRecording ? 12 : 8),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: _isRecording ? Colors.white : Colors.blueAccent,
                            size: _isRecording ? 24 : 20,
                          ),
                          if (_isRecording) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    "Recording",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  _buildPulsingDot(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                  tooltip: 'Take photo or choose from gallery',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Choose an option'),
                          content: SingleChildScrollView(
                            child: ListBody(
                              children: [
                                GestureDetector(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.photo_library, color: Colors.blueAccent),
                                        SizedBox(width: 10),
                                        Text('Gallery'),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    pickImageFromGallery();
                                    Navigator.of(context).pop();
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                                  child: Divider(height: 1),
                                ),
                                GestureDetector(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.camera_alt, color: Colors.blueAccent),
                                        SizedBox(width: 10),
                                        Text('Camera'),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    pickImageFromCamera();
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Enter message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),

                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value as double) < 0.5 ? value * 2 : (1.0 - value) * 2,
          child: Container(
            height: 6,
            width: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoiceMessageWidget(Map<String, dynamic> messageData, String messageId, bool isMe) {
    final String? filePath = messageData['filePath'] as String?;
    final String? base64Audio = messageData['base64Audio'] as String?;
    final int duration = messageData['duration'] as int? ?? 0;
    final bool isPlaying = _currentlyPlayingId == messageId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _playVoiceMessage(messageId, filePath: filePath, base64Audio: base64Audio),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue.shade400 : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 30,
          decoration: BoxDecoration(
            color: isMe ? Colors.blue.shade400 : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(15),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: LinearProgressIndicator(
              value: isPlaying ? null : 0,
              backgroundColor: isMe ? Colors.blue.shade400 : Colors.grey.shade400,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(duration),
          style: TextStyle(
            fontSize: 12,
            color: isMe ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
  Widget _buildImageMessageWidget(Map<String, dynamic> messageData, bool isMe) {
    final String imageUrl = messageData['imageUrl'] as String;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Image'),
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              backgroundColor: Colors.black,
              body: Center(
                child: PhotoView(
                  imageProvider: FileImage(File(imageUrl)),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                ),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(imageUrl),
          width: 300,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}