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
  int? _currentlyPlayingId;

  final String apiBaseUrl = 'https://kirayanama.devsflutter.com/chat.php';

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String userId = _auth.currentUser?.uid ?? '';
      String receiverId = widget.receiverId;

      final response = await http.get(
        Uri.parse('$apiBaseUrl?senderId=$userId&receiverId=$receiverId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print("messages ${responseData}");
          print("messages $responseData");
          List<dynamic> messages = responseData;
          setState(() {
            _messages = messages.map((msg) {
              return {
                'id': msg['id'],
                'senderId': msg['senderId'],
                'receiverId': msg['receiverId'],
                'senderEmail': msg['senderEmail'],
                'receiverEmail': msg['receiverEmail'],
                'timestamp': msg['timestamp'],
                'messageType': msg['messageType'],
                'text': msg['text'],
                'fileUrl': msg['fileUrl'],
                'duration': msg['duration'],
                'taskId': msg['taskId'],
                'taskTitle': msg['taskTitle'],
              };
            }).toList();
            _isLoading = false;
          });
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

  Future<void> deleteMessage(String messageId) async {

    final userId = _auth.currentUser?.uid ?? '';
    final userEmail = _auth.currentUser?.email ?? 'Unknown';

    final String messageText = _messageController.text.trim();
    DateTime now = DateTime.now();
    String formattedTimestamp = "${now.year}-${now.month.toString().padLeft(
        2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString()
        .padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second
        .toString().padLeft(2, '0')}";
    String receiverId = widget.receiverId;

    final messageData = {
      'text': messageText,
      'senderId': userId,
      'receiverId': receiverId,
      'senderEmail': userEmail,
      'receiverEmail': widget.todoData['assignedToEmail'] ??
          widget.todoData['assignedTo'],
      'timestamp': formattedTimestamp,
      'messageType': 'text',
      'taskId': widget.taskId,
      'taskTitle': widget.taskTitle,
      'fileUrl': '',
      'duration': '',
      'id': messageId,
    };

    setState(() {
      _messages.removeWhere((msg) => msg['id'] == messageId);
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/$messageId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': messageId,}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted')),
          );
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: ${e.toString()}')),
      );
    }
  }
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final userId = _auth.currentUser?.uid ?? '';
    final userEmail = _auth.currentUser?.email ?? 'Unknown';

    final String messageText = _messageController.text.trim();
    DateTime now = DateTime.now();
    String formattedTimestamp = "${now.year}-${now.month.toString().padLeft(
        2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString()
        .padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second
        .toString().padLeft(2, '0')}";
    String receiverId = widget.receiverId;

    final messageData = {
      'text': messageText,
      'senderId': userId,
      'receiverId': receiverId,
      'senderEmail': userEmail,
      'receiverEmail': widget.todoData['assignedToEmail'] ??
          widget.todoData['assignedTo'],
      'timestamp': formattedTimestamp,
      'messageType': 'text',
      'taskId': widget.taskId,
      'taskTitle': widget.taskTitle,
      'fileUrl': '',
      'duration': '',
      'id': '',
    };

    setState(() {
      _messages.add({
        ...messageData,
        'id': 'temp_${DateTime
            .now()
            .millisecondsSinceEpoch}',
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
          'receiverId': receiverId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestamp': formattedTimestamp,
          'messageType': 'text',
          'fileUrl': '',
          'duration': '',
          'taskId': widget.taskId,
          'taskTitle': widget.taskTitle,
          'text': messageText,
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
      String formattedTimestamp = "${now.year}-${now.month.toString().padLeft(
          2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString()
          .padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now
          .second.toString().padLeft(2, '0')}";
      String receiverId = widget.receiverId;

      final messageData = {
        'senderId': userId,
        'receiverId': receiverId,
        'senderEmail': userEmail,
        'receiverEmail': widget.todoData['assignedTo'],
        'timestamp': formattedTimestamp,
        'messageType': 'image',
        'taskId': '',
        'taskTitle': '',
        'fileUrl': base64Image,
        'duration': '',
        'id': '',
        'text': '',
      };

      final tempId = 'temp_${DateTime
          .now()
          .millisecondsSinceEpoch}';
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
          'receiverId': receiverId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestamp': formattedTimestamp,
          'messageType': 'image',
          'fileUrl': base64Image,
          'duration': '',
          'taskId': '',
          'taskTitle': '',
          'text': '',
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
  Future<void> _playVoiceMessage(int messageId, {
    String? localFilePath,
    String? base64Audio,
    String? audioUrl,
  }) async {
    try {
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

      print('Playing voice message #$messageId');

      if (localFilePath != null && await File(localFilePath).exists()) {
        print('Playing from local file: $localFilePath');
        await _audioPlayer.play(DeviceFileSource(localFilePath));
      }
      else if (base64Audio != null && base64Audio.isNotEmpty) {
        try {
          print('Decoding base64 audio data');
          Directory tempDir = await getTemporaryDirectory();
          String tempPath = '${tempDir.path}/temp_audio_$messageId.m4a';
          File tempFile = File(tempPath);

          List<int> audioBytes = base64Decode(base64Audio);
          print('Decoded audio size: ${audioBytes.length} bytes');

          await tempFile.writeAsBytes(audioBytes);
          print('Saved to temp file: $tempPath (${await tempFile.length()} bytes)');

          if (await tempFile.exists()) {
            await _audioPlayer.play(DeviceFileSource(tempPath));
          } else {
            throw Exception('Failed to create temporary audio file');
          }
        } catch (e) {
          print('Error processing base64 audio: $e');
          throw Exception('Invalid audio data');
        }
      }
      else if (audioUrl != null && audioUrl.isNotEmpty) {
        print('Playing from URL: $audioUrl');
        await _audioPlayer.play(UrlSource(audioUrl));
      }
      else {
        throw Exception('No valid audio source available');
      }

      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _currentlyPlayingId = null;
          });
        }
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

  Widget _buildVoiceMessageWidget(Map<String, dynamic> messageData, int messageId, bool isMe) {
    final String? localFilePath = messageData['localFilePath'] as String?;
    final String? fileUrl = messageData['fileUrl'] as String?;

    final dynamic durationValue = messageData['duration'];
    int duration = 0;

    if (durationValue is int) {
      duration = durationValue;
    } else if (durationValue is String && durationValue.isNotEmpty) {
      duration = int.tryParse(durationValue) ?? 0;
    }

    final bool isPlaying = _currentlyPlayingId == messageId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            print('Voice message tapped - ID: $messageId');
            print('Local file path: $localFilePath');
            print('File URL available: ${fileUrl != null && fileUrl.isNotEmpty}');

            _playVoiceMessage(
              messageId,
              localFilePath: localFilePath,
              base64Audio: fileUrl?.startsWith('http') != true ? fileUrl : null,
              audioUrl: fileUrl?.startsWith('http') == true ? fileUrl : null,
            );
          },
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
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.5)),
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

  Future<void> _sendVoiceNote(String filePath) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      String userEmail = _auth.currentUser?.email ?? 'Unknown';
      int duration = _calculateDuration();

      File audioFile = File(filePath);
      List<int> audioBytes = await audioFile.readAsBytes();
      String base64Audio = base64Encode(audioBytes);

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final DateTime now = DateTime.now();
      String formattedTimestamp = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      String receiverId = widget.receiverId;

      setState(() {
        _messages.add({
          'id': tempId,
          'senderId': userId,
          'senderEmail': userEmail,
          'receiverId': receiverId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestamp': formattedTimestamp,
          'messageType': 'voice',  // Changed from base64Audio to 'voice'
          'fileUrl': base64Audio,
          'localFilePath': filePath,
          'duration': duration.toString(),  // Convert to string for consistency
          'taskId': '',
          'taskTitle': '',
          'text': '',
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
          'receiverId': receiverId,
          'receiverEmail': widget.todoData['assignedTo'],
          'timestamp': formattedTimestamp,
          'messageType': 'voice',  // Critical: changed from base64Audio to 'voice'
          'fileUrl': base64Audio,
          'duration': duration.toString(),  // Convert to string for consistency
          'taskId': '',
          'taskTitle': '',
          'text': '',
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
              };
            }
          });
        } else {
          throw Exception(responseData['message']);
        }
      } else {
        throw Exception('Failed to send voice note: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending voice note: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending voice note: ${e.toString()}')),
      );

      setState(() {
        _messages.removeWhere((msg) =>
        msg['isPending'] == true && msg['localFilePath'] == filePath);
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        Directory appDocDir = await getApplicationDocumentsDirectory();
        _recordingPath = '${appDocDir.path}/voice_note_${DateTime
            .now()
            .millisecondsSinceEpoch}.m4a';

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
          const SnackBar(
              content: Text('Permission to record audio was denied')),
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
          print(
              'Audio file exists with size: ${await audioFile.length()} bytes');
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
    return DateTime
        .now()
        .difference(_recordingStartTime!)
        .inMilliseconds;
  }

  Future<void> playVoiceMessage(int messageId, {

    String? localFilePath,
    String? base64Audio,
    String? audioUrl,
  }) async {
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
        await _audioPlayer.play(DeviceFileSource(localFilePath));
      } else if (base64Audio != null) {
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = '${tempDir.path}/temp_audio_$messageId.m4a';
        File tempFile = File(tempPath);
        await tempFile.writeAsBytes(base64Decode(base64Audio));
        await _audioPlayer.play(DeviceFileSource(tempPath));
      } else if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
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
      final String imagePath = '${appDocDir.path}/image_${DateTime
          .now()
          .millisecondsSinceEpoch}.png';
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
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())

            :ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                var messageData = _messages[index];
                var messageId = messageData['id'];
                var senderId = messageData['senderId'] as String;
                var senderEmail = messageData['senderEmail'] as String? ?? 'Unknown';
                var messageType = messageData['messageType'] as String? ?? 'text';

                DateTime timestamp;
                try {
                  timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').parse(messageData['timestamp']);
                } catch (e) {
                  timestamp = DateTime.now();
                }

                String timeString = DateFormat('h:mm a').format(timestamp);
                bool isMe = senderId == userId;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child:
                  GestureDetector(
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Message'),
                            content: const Text('Are you sure you want to delete this message?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  deleteMessage(messageId);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
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
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: isMe ? Colors.white : Colors.black
                                  ),
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                );
              },
            )
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Tooltip(
                  message: 'Press and hold to record voice message',
                  child: GestureDetector(
                    onLongPress: _isRecording ? null : _startRecording,
                    onLongPressEnd: (_) =>
                    _isRecording
                        ? _stopRecording()
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.all(_isRecording ? 12 : 8),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: _isRecording
                            ? [BoxShadow(color: Colors.red.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2)
                        ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            color: _isRecording ? Colors.white : Colors
                                .blueAccent,
                            size: _isRecording ? 24 : 20,
                          ),
                          if (_isRecording) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                                        Icon(Icons.photo_library,
                                            color: Colors.blueAccent),
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
                                  padding: const EdgeInsets.only(
                                      top: 12, bottom: 12),
                                  child: Divider(height: 1),
                                ),
                                GestureDetector(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        Icon(Icons.camera_alt,
                                            color: Colors.blueAccent),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20)),
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

  Widget buildVoiceMessageWidget(Map<String, dynamic> messageData, int messageId, bool isMe) {

    final String? localFilePath = messageData['localFilePath'] as String?;
    final String? fileUrl = messageData['fileUrl'] as String?;
    final dynamic durationValue = messageData['duration'];
    final int duration = durationValue is int ? durationValue :
    durationValue is String && durationValue.isNotEmpty ? int.tryParse(durationValue) ?? 0 : 0;
    final bool isPlaying = _currentlyPlayingId == messageId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _playVoiceMessage(
            messageId,
            localFilePath: localFilePath,
            base64Audio: fileUrl,
            audioUrl: fileUrl?.startsWith('http') == true ? fileUrl : null,
          ),
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
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.5)),
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
    final String? fileUrl = messageData['fileUrl'] as String?;

    Widget imageWidget;

    if (localFilePath != null && File(localFilePath).existsSync()) {
      imageWidget = Image.file(
        File(localFilePath),
        width: 300,
        height: 200,
        fit: BoxFit.cover,
      );
    } else if (fileUrl != null && fileUrl.isNotEmpty) {
      // Check if fileUrl is a base64 string (not starting with http)
      if (!fileUrl.startsWith('http')) {
        try {
          imageWidget = Image.memory(
            base64Decode(fileUrl),
            width: 300,
            height: 200,
            fit: BoxFit.cover,
          );
        } catch (e) {
          print('Error decoding base64 image: $e');
          imageWidget = Container(
            width: 300,
            height: 200,
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
          );
        }
      } else {
        // Handle URL-based images
        imageWidget = Image.network(
          fileUrl,
          width: 300,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 300,
              height: 200,
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $error');
            return Container(
              width: 300,
              height: 200,
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            );
          },
        );
      }
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
                      : fileUrl != null && !fileUrl.startsWith('http')
                      ? MemoryImage(base64Decode(fileUrl))
                      : fileUrl != null
                      ? NetworkImage(fileUrl)
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  loadingBuilder: (context, event) => Center(
                    child: CircularProgressIndicator(
                      value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                    ),
                  ),
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
