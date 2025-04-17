/// id : 78
/// duration : ""
/// fileUrl : ""
/// audio_id : null
/// messageType : "text"
/// receiverEmail : "aqsa@gmail.com"
/// receiverId : "8RpSw5AzECP20jTEIVYBew8rCp02"
/// senderEmail : "abbas@gmail.com"
/// senderId : "1UWM7vqPVXaSBBH1ZcMEhv9HALm1"
/// taskId : ""
/// taskTitle : ""
/// text : "??"
/// timestamp : "2025-04-15 14:02:35"

class ChattigModel {
  ChattigModel({
      num id, 
      String duration, 
      String fileUrl, 
      dynamic audioId, 
      String messageType, 
      String receiverEmail, 
      String receiverId, 
      String senderEmail, 
      String senderId, 
      String taskId, 
      String taskTitle, 
      String text, 
      String timestamp,}){
    _id = id;
    _duration = duration;
    _fileUrl = fileUrl;
    _audioId = audioId;
    _messageType = messageType;
    _receiverEmail = receiverEmail;
    _receiverId = receiverId;
    _senderEmail = senderEmail;
    _senderId = senderId;
    _taskId = taskId;
    _taskTitle = taskTitle;
    _text = text;
    _timestamp = timestamp;
}

  ChattigModel.fromJson(dynamic json) {
    _id = json['id'];
    _duration = json['duration'];
    _fileUrl = json['fileUrl'];
    _audioId = json['audio_id'];
    _messageType = json['messageType'];
    _receiverEmail = json['receiverEmail'];
    _receiverId = json['receiverId'];
    _senderEmail = json['senderEmail'];
    _senderId = json['senderId'];
    _taskId = json['taskId'];
    _taskTitle = json['taskTitle'];
    _text = json['text'];
    _timestamp = json['timestamp'];
  }
  num _id;
  String _duration;
  String _fileUrl;
  dynamic _audioId;
  String _messageType;
  String _receiverEmail;
  String _receiverId;
  String _senderEmail;
  String _senderId;
  String _taskId;
  String _taskTitle;
  String _text;
  String _timestamp;
ChattigModel copyWith({  num id,
  String duration,
  String fileUrl,
  dynamic audioId,
  String messageType,
  String receiverEmail,
  String receiverId,
  String senderEmail,
  String senderId,
  String taskId,
  String taskTitle,
  String text,
  String timestamp,
}) => ChattigModel(  id: id ?? _id,
  duration: duration ?? _duration,
  fileUrl: fileUrl ?? _fileUrl,
  audioId: audioId ?? _audioId,
  messageType: messageType ?? _messageType,
  receiverEmail: receiverEmail ?? _receiverEmail,
  receiverId: receiverId ?? _receiverId,
  senderEmail: senderEmail ?? _senderEmail,
  senderId: senderId ?? _senderId,
  taskId: taskId ?? _taskId,
  taskTitle: taskTitle ?? _taskTitle,
  text: text ?? _text,
  timestamp: timestamp ?? _timestamp,
);
  num get id => _id;
  String get duration => _duration;
  String get fileUrl => _fileUrl;
  dynamic get audioId => _audioId;
  String get messageType => _messageType;
  String get receiverEmail => _receiverEmail;
  String get receiverId => _receiverId;
  String get senderEmail => _senderEmail;
  String get senderId => _senderId;
  String get taskId => _taskId;
  String get taskTitle => _taskTitle;
  String get text => _text;
  String get timestamp => _timestamp;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['duration'] = _duration;
    map['fileUrl'] = _fileUrl;
    map['audio_id'] = _audioId;
    map['messageType'] = _messageType;
    map['receiverEmail'] = _receiverEmail;
    map['receiverId'] = _receiverId;
    map['senderEmail'] = _senderEmail;
    map['senderId'] = _senderId;
    map['taskId'] = _taskId;
    map['taskTitle'] = _taskTitle;
    map['text'] = _text;
    map['timestamp'] = _timestamp;
    return map;
  }

}