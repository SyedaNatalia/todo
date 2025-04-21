class ChattigModel {
  ChattigModel({
    required this.id,
    required this.duration,
    required this.fileUrl,
    this.audioId,
    required this.messageType,
    required this.receiverEmail,
    required this.receiverId,
    required this.senderEmail,
    required this.senderId,
    required this.taskId,
    required this.taskTitle,
    required this.text,
    required this.timestamp,
  });

  factory ChattigModel.fromJson(Map<String, dynamic> json) {
    return ChattigModel(
      id: json['id'],
      duration: json['duration'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      audioId: json['audio_id'],
      messageType: json['messageType'] ?? '',
      receiverEmail: json['receiverEmail'] ?? '',
      receiverId: json['receiverId'] ?? '',
      senderEmail: json['senderEmail'] ?? '',
      senderId: json['senderId'] ?? '',
      taskId: json['taskId'] ?? '',
      taskTitle: json['taskTitle'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  final num id;
  final String duration;
  final String fileUrl;
  final dynamic audioId;
  final String messageType;
  final String receiverEmail;
  final String receiverId;
  final String senderEmail;
  final String senderId;
  final String taskId;
  final String taskTitle;
  final String text;
  final String timestamp;

  ChattigModel copyWith({
    num? id,
    String? duration,
    String? fileUrl,
    dynamic audioId,
    String? messageType,
    String? receiverEmail,
    String? receiverId,
    String? senderEmail,
    String? senderId,
    String? taskId,
    String? taskTitle,
    String? text,
    String? timestamp,
  }) {
    return ChattigModel(
      id: id ?? this.id,
      duration: duration ?? this.duration,
      fileUrl: fileUrl ?? this.fileUrl,
      audioId: audioId ?? this.audioId,
      messageType: messageType ?? this.messageType,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      receiverId: receiverId ?? this.receiverId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderId: senderId ?? this.senderId,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'duration': duration,
      'fileUrl': fileUrl,
      'audio_id': audioId,
      'messageType': messageType,
      'receiverEmail': receiverEmail,
      'receiverId': receiverId,
      'senderEmail': senderEmail,
      'senderId': senderId,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'text': text,
      'timestamp': timestamp,
    };
  }
}