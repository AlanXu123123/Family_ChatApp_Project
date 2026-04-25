import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // ── Room ID helpers ──

  String _getChatRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatRoomId) =>
      _firestore.collection('chatRooms').doc(chatRoomId).collection('messages');

  // ── Private (1-on-1) chat rooms ──

  Future<void> ensureChatRoom(String uid1, String uid2) async {
    final roomId = _getChatRoomId(uid1, uid2);
    final doc = _firestore.collection('chatRooms').doc(roomId);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'type': 'private',
        'participants': [uid1, uid2],
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {uid1: 0, uid2: 0},
      });
    }
  }

  Stream<List<Message>> getMessages(String myUid, String otherUid, {int limit = 100}) {
    final roomId = _getChatRoomId(myUid, otherUid);
    return getMessagesByRoom(roomId, limit: limit);
  }

  Future<void> markAsRead(String myUid, String otherUid) async {
    final roomId = _getChatRoomId(myUid, otherUid);
    await markRoomAsRead(roomId, myUid);
  }

  Stream<int> getUnreadCount(String myUid, String otherUid) {
    final roomId = _getChatRoomId(myUid, otherUid);
    return getRoomUnreadCount(roomId, myUid);
  }

  Future<void> sendTextMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String text,
  }) async {
    final roomId = _getChatRoomId(senderId, receiverId);
    final msgId = _uuid.v4();
    final message = Message(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.text,
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    await _messagesRef(roomId).doc(msgId).set(message.toMap());
    await _updateLastMessagePrivate(roomId, text.trim(), senderId, receiverId);
  }

  Future<void> sendImageMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String imageUrl,
  }) async {
    final roomId = _getChatRoomId(senderId, receiverId);
    final msgId = _uuid.v4();
    final message = Message(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.image,
      content: imageUrl,
      timestamp: DateTime.now(),
    );
    await _messagesRef(roomId).doc(msgId).set(message.toMap());
    await _updateLastMessagePrivate(roomId, '[图片]', senderId, receiverId);
  }

  Future<void> sendVoiceMessage({
    required String senderId,
    required String senderName,
    required String receiverId,
    required String voiceUrl,
    required int durationSeconds,
  }) async {
    final roomId = _getChatRoomId(senderId, receiverId);
    final msgId = _uuid.v4();
    final message = Message(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.voice,
      content: voiceUrl,
      voiceDurationSeconds: durationSeconds,
      timestamp: DateTime.now(),
    );
    await _messagesRef(roomId).doc(msgId).set(message.toMap());
    await _updateLastMessagePrivate(roomId, '[语音]', senderId, receiverId);
  }

  Future<void> _updateLastMessagePrivate(
      String roomId, String preview, String senderId, String receiverId) async {
    await _firestore.collection('chatRooms').doc(roomId).update({
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'unreadCount.$receiverId': FieldValue.increment(1),
    });
  }

  // ── Generic room-based methods (shared by private & group) ──

  Stream<List<Message>> getMessagesByRoom(String roomId, {int limit = 100}) {
    return _messagesRef(roomId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Message.fromMap(d.data(), d.id)).toList());
  }

  Future<void> markRoomAsRead(String roomId, String myUid) async {
    final doc = _firestore.collection('chatRooms').doc(roomId);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.update({'unreadCount.$myUid': 0});
    }
  }

  Stream<int> getRoomUnreadCount(String roomId, String myUid) {
    return _firestore.collection('chatRooms').doc(roomId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return 0;
      final unread = data['unreadCount'] as Map<String, dynamic>?;
      return (unread?[myUid] as int?) ?? 0;
    });
  }

  Stream<int> getTotalUnreadCount(String myUid) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final unread = data['unreadCount'] as Map<String, dynamic>?;
        total += (unread?[myUid] as int?) ?? 0;
      }
      return total;
    });
  }

  Future<List<Map<String, String>>> getGroupMemberProfiles(String roomId) async {
    final doc = await _firestore.collection('chatRooms').doc(roomId).get();
    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    final profiles = <Map<String, String>>[];
    for (final uid in participants) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        profiles.add({
          'uid': uid,
          'displayName': userDoc.data()?['displayName'] ?? '',
          'email': userDoc.data()?['email'] ?? '',
        });
      }
    }
    return profiles;
  }

  // ── Group chat rooms ──

  static const familyGroupId = 'family_group';

  Future<void> ensureFamilyGroup(String uid) async {
    final doc = _firestore.collection('chatRooms').doc(familyGroupId);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'type': 'group',
        'name': '聊天室',
        'participants': [uid],
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCount': {uid: 0},
      });
    } else {
      final updates = <String, dynamic>{};
      final data = snap.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      if (!participants.contains(uid)) {
        updates['participants'] = FieldValue.arrayUnion([uid]);
        updates['unreadCount.$uid'] = 0;
      }
      if (data['name'] != '聊天室') {
        updates['name'] = '聊天室';
      }
      if (updates.isNotEmpty) {
        await doc.update(updates);
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getGroupChats(String myUid) {
    return _firestore
        .collection('chatRooms')
        .where('type', isEqualTo: 'group')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> sendTextToRoom({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final msgId = _uuid.v4();
    final message = Message(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.text,
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    await _messagesRef(roomId).doc(msgId).set(message.toMap());
    await _updateLastMessageGroup(roomId, text.trim(), senderId);
  }

  Future<void> sendImageToRoom({
    required String roomId,
    required String senderId,
    required String senderName,
    required String imageUrl,
  }) async {
    final msgId = _uuid.v4();
    final message = Message(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.image,
      content: imageUrl,
      timestamp: DateTime.now(),
    );
    await _messagesRef(roomId).doc(msgId).set(message.toMap());
    await _updateLastMessageGroup(roomId, '[图片]', senderId);
  }

  Future<void> sendVoiceToRoom({
    required String roomId,
    required String senderId,
    required String senderName,
    required String voiceUrl,
    required int durationSeconds,
  }) async {
    final msgId = _uuid.v4();
    final message = Message(
      id: msgId,
      senderId: senderId,
      senderName: senderName,
      type: MessageType.voice,
      content: voiceUrl,
      voiceDurationSeconds: durationSeconds,
      timestamp: DateTime.now(),
    );
    await _messagesRef(roomId).doc(msgId).set(message.toMap());
    await _updateLastMessageGroup(roomId, '[语音]', senderId);
  }

  Future<void> _updateLastMessageGroup(
      String roomId, String preview, String senderId) async {
    final doc = await _firestore.collection('chatRooms').doc(roomId).get();
    final participants = List<String>.from(doc.data()?['participants'] ?? []);
    final updates = <String, dynamic>{
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    };
    for (final uid in participants) {
      if (uid != senderId) {
        updates['unreadCount.$uid'] = FieldValue.increment(1);
      }
    }
    await _firestore.collection('chatRooms').doc(roomId).update(updates);
  }
}
