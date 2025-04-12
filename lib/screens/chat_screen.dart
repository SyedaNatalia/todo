import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverEmail;
  final String? taskId;
  final String? taskTitle;
  final Map<String, dynamic> todoData;

  const ChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverEmail,
    this.taskId,
    this.taskTitle,
    required this.todoData,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  final String apiBaseUrl = 'https://kirayanama.devsflutter.com/chat.php';

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  // Fetch messages from API
  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String userId = _auth.currentUser?.uid ?? '';

      final response = await http.get(
        Uri.parse(apiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print(response.body);
        _scrollToBottom();
      } else {
        print('Failed to load messages: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching messages: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: ${e.toString()}')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userId = _auth.currentUser?.uid ?? '';
    final userEmail = _auth.currentUser?.email ?? 'Unknown';

    final String messageText = _messageController.text.trim();
    DateTime now = DateTime.now();
    String formattedTimestamp = now.toIso8601String();

    final messageData = {
      'text': messageText,
      'senderId': userId,
      'receiverId': widget.todoData['assignedTo'],
      'senderEmail': userEmail,
      'receiverEmail': widget.todoData['assignedToEmail'] ?? widget.todoData['assignedTo'],
      'timestampString': formattedTimestamp,
      'messageType': 'text',
      'taskId': widget.taskId,
      'taskTitle': widget.taskTitle,
      'fileUrl': '',
      'duration': '',
      'id':'',
    };

    setState(() {
      _messages.add({
        ...messageData,
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'isPending': true,
      });
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(apiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': '',
          'senderId': userId,
          'senderEmail': userEmail,
          'receiverId':userId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestampString': formattedTimestamp,
          'messageType': 'text',
          'fileUrl': '',
          'duration': '',
          'taskId': widget.taskId,
          'taskTitle': widget.taskTitle,
          'text':messageText,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            final index = _messages.indexWhere((msg) =>
            msg['isPending'] == true &&
                msg['text'] == messageData['text']);
            if (index != -1) {
              _messages[index] = {
                ..._messages[index],
                ...responseData['message'],
                'isPending': false,
              };
            }
          });
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        final index = _messages.indexWhere((msg) =>
        msg['isPending'] == true &&
            msg['text'] == messageData['text']);
        if (index != -1) {
          _messages[index]['isFailed'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  Future<void> _sendImageMessage(String imagePath) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      final userEmail = _auth.currentUser?.email ?? 'Unknown';
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final DateTime now = DateTime.now();
      final String formattedTimestamp = now.toIso8601String();

      final messageData = {
        'senderId': userId,
        'receiverId': userId,
        'senderEmail': userEmail,
        'receiverEmail': widget.todoData['assignedTo'],
        'timestampString': formattedTimestamp,
        'messageType': 'image',
        'taskId': '',
        'taskTitle': '',
        'fileUrl': base64Image,
        'duration': '',
        'id':'',
        'text': '',
      };

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _messages.add({
          ...messageData,
          'id': tempId,
          'localFilePath': imagePath,
          'isPending': true,
        });
      });

      _scrollToBottom();

      final response = await http.post(
        Uri.parse(apiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': '',
          'senderId': userId,
          'senderEmail': userEmail,
          'receiverId': userId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestampString': formattedTimestamp,
          'messageType': 'image',
          'fileUrl': base64Image,
          'duration': '',
          'taskId': '',
          'taskTitle': '',
          'text':'',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            final index = _messages.indexWhere((msg) => msg['id'] == tempId);
            if (index != -1) {
              _messages[index] = {
                ..._messages[index],
                ...responseData['message'],
                'isPending': false,
                'localFilePath': imagePath,
              };
            }
          });
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to send image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending image: $e');
      setState(() {
        final index = _messages.indexWhere((msg) =>
        msg['localFilePath'] == imagePath &&
            msg['isPending'] == true);
        if (index != -1) {
          _messages[index]['isFailed'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: ${e.toString()}')),
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

  Future<void> _sendVoiceNote(String filePath) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      String userEmail = _auth.currentUser?.email ?? 'Unknown';
      int duration = _calculateDuration();
      String messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

      File audioFile = File(filePath);
      List<int> audioBytes = await audioFile.readAsBytes();
      String base64Audio = base64Encode(audioBytes);

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final DateTime now = DateTime.now();
      final String formattedTimestamp = now.toIso8601String();
      setState(() {
        _messages.add({
          'id': messageId,
          'senderId': userId,
          'senderEmail': userEmail,
          'receiverId': userId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestampString': formattedTimestamp,
          'messageType': base64Audio,
          'taskId': '',
          'taskTitle': '',
          'fileUrl': '',
          'duration': duration,
          'text':'',
        });
      });

      _scrollToBottom();

      final response = await http.post(
        Uri.parse(apiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': messageId,
          'senderId': userId,
          'senderEmail': userEmail,
          'receiverId': userId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestampString': formattedTimestamp,
          'messageType': base64Audio,
          'fileUrl': '',
          'duration': duration,
          'taskId': '',
          'taskTitle': '',
          'text':'',
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          int index = _messages.indexWhere((msg) => msg['id'] == tempId);
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              'id': messageId,
              'isPending': false,
            };
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice note sent successfully')),
        );
      } else {
        print('Failed to send voice note: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send voice note. Please try again.')),
        );

        setState(() {
          _messages.removeWhere((msg) => msg['id'] == tempId && msg['isPending'] == true);
        });
      }
    } catch (e) {
      print('Error sending voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending voice note: ${e.toString()}')),
      );

      setState(() {
        _messages.removeWhere((msg) => msg['isPending'] == true && msg['localFilePath'] == filePath);
      });
    }
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
          await _sendVoiceNote(path);
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

  int _calculateDuration() {
    if (_recordingStartTime == null) {
      return 0;
    }
    return DateTime.now().difference(_recordingStartTime!).inMilliseconds;
  }

  Future<void> _playVoiceMessage(String messageId, {String? localFilePath, String? base64Audio}) async {
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
      if (localFilePath != null && File(localFilePath).existsSync()) {
        print('Playing voice note from local file: $localFilePath');
        await _audioPlayer.play(DeviceFileSource(localFilePath));
      } else if (base64Audio != null) {
        print('Playing voice note from base64 data');
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
        backgroundColor: Color(0xFF9DCEFF),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.todoData['assignedTo'],
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                var messageData = _messages[index];
                var messageId = messageData['id'] as String;
                var senderId = messageData['senderId'] as String;
                var senderEmail = messageData['senderEmail'] as String? ?? 'Unknown';
                var messageType = messageData['messageType'] as String? ?? 'text';
                var isPending = messageData['isPending'] as bool? ?? false;

                // Convert timestamp to DateTime
                DateTime timestamp;
                if (messageData['timestamp'] is int) {
                  timestamp = DateTime.fromMillisecondsSinceEpoch(messageData['timestamp']);
                } else {
                  // Fallback in case the API returns a different format
                  timestamp = DateTime.now();
                }

                String timeString = DateFormat('h:mm a').format(timestamp);
                bool isMe = senderId == userId;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Stack(
                    children: [
                      Container(
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
                                messageData['text'] as String? ?? '',
                                style: TextStyle(fontSize: 16, color: isMe ? Colors.white : Colors.black),
                              )
                            else if (messageType == 'voice')
                              _buildVoiceMessageWidget(messageData, messageId, isMe)
                            else if (messageType == 'image')
                                _buildImageMessageWidget(messageData, isMe),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isMe ? Colors.white70 : Colors.black54
                                    ),
                                  ),
                                  if (isPending)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(Icons.access_time, size: 10, color: isMe ? Colors.white70 : Colors.black54),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final String? localFilePath = messageData['localFilePath'] as String?;
    final String? fileData = messageData['fileData'] as String?;
    final int duration = messageData['duration'] as int? ?? 0;
    final bool isPlaying = _currentlyPlayingId == messageId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _playVoiceMessage(messageId, localFilePath: localFilePath, base64Audio: fileData),
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
    final String? localFilePath = messageData['localFilePath'] as String?;
    final String? fileData = messageData['fileData'] as String?;

    Widget imageWidget;

    if (localFilePath != null && File(localFilePath).existsSync()) {
      imageWidget = Image.file(
        File(localFilePath),
        width: 300,
        height: 200,
        fit: BoxFit.cover,
      );
    } else if (fileData != null) {
      imageWidget = Image.memory(
        base64Decode(fileData),
        width: 300,
        height: 200,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = Container(
        width: 300,
        height: 200,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      );
    }

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
                  imageProvider: localFilePath != null && File(localFilePath).existsSync()
                      ? FileImage(File(localFilePath))
                      : fileData != null
                      ? MemoryImage(base64Decode(fileData))
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
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
        child: imageWidget,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

