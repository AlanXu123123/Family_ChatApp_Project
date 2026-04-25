import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, voice }

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final int? voiceDurationSeconds;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.voiceDurationSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'voiceDurationSeconds': voiceDurationSeconds,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String docId) {
    return Message(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      content: map['content'] ?? '',
      voiceDurationSeconds: map['voiceDurationSeconds'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
