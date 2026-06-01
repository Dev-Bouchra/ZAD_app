// ============================================================
// 📄 lib/chat_service.dart
// ملف مشترك للـ 3 أدوار
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser!.uid;

  // ─── ID المحادثة: مرتب أبجدياً باش يكون دايماً نفس الـ ID ───
  String conversationId(String otherUid) {
    final ids = [currentUserId, otherUid]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // ─── جلب role المستخدم الحالي ───
  Future<String> getCurrentUserRole() async {
    try {
      final doc = await _firestore.collection('users').doc(currentUserId).get();
      return (doc.data()?['role'] as String? ?? '').toLowerCase();
    } catch (_) {
      return '';
    }
  }

  // ─── جلب المستخدمين اللي يقدر يهدر معهم حسب الدور ───
  Stream<List<Map<String, dynamic>>> getUsersToChat() async* {
    final role = await getCurrentUserRole();

    List<String> allowedRoles;
    if (role == 'association') {
      allowedRoles = ['benevole', 'donateur'];
    } else if (role == 'benevole') {
      allowedRoles = ['association', 'donateur'];
    } else {
      allowedRoles = ['association', 'benevole'];
    }

    yield* _firestore
        .collection('users')
        .where('role', whereIn: allowedRoles)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.id != currentUserId)
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList());
  }

  // ─── فتح أو إنشاء محادثة ───
  Future<void> openConversation({
    required String otherUid,
    required String myName,
    required String myInitials,
    required String otherName,
    required String otherInitials,
  }) async {
    final convId = conversationId(otherUid);
    await _firestore.collection('conversations').doc(convId).set({
      'participants': [currentUserId, otherUid],
      'contactName_$currentUserId': otherName,
      'contactInitials_$currentUserId': otherInitials,
      'contactName_$otherUid': myName,
      'contactInitials_$otherUid': myInitials,
      'unreadCount_$currentUserId': 0,
    }, SetOptions(merge: true));
  }

  // ─── إرسال رسالة ───
  Future<void> sendMessage({
    required String otherUid,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final convId = conversationId(otherUid);
    final now = FieldValue.serverTimestamp();

    final senderInfo = await getUserInfo(currentUserId);
    final senderName = senderInfo['name']!;

    await _firestore
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .add({
      'text': text.trim(),
      'senderId': currentUserId,
      'timestamp': now,
      'read': false,
    });

    await _firestore.collection('conversations').doc(convId).set({
      'lastMessage': text.trim(),
      'lastMessageAt': now,
      'participants': [currentUserId, otherUid],
      'unreadCount_$otherUid': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // 🔔 إشعار للمستقبل
    await NotificationService.sendNotificationToUser(
      userId: otherUid,
      title: '📩 Nouveau message',
      body: '$senderName: ${text.trim()}',
      type: 'message',
      extraData: {'conversationId': convId},
    );
  }

  // ─── حذف رسالة للطرفين ───
  Future<void> deleteMessage({
    required String otherUid,
    required String messageId,
  }) async {
    final convId = conversationId(otherUid);
    await _firestore
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  // ─── Stream الرسائل ───
  Stream<QuerySnapshot> messagesStream(String otherUid) {
    return _firestore
        .collection('conversations')
        .doc(conversationId(otherUid))
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ─── Stream قائمة المحادثات ───
  Stream<QuerySnapshot> conversationsStream() {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots();
  }

  // ─── تعليم المحادثة كـ مقروءة ───
  Future<void> markAsRead(String otherUid) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId(otherUid))
          .update({'unreadCount_$currentUserId': 0});
    } catch (_) {}
  }

  // ─── جلب معلومات مستخدم ───
  Future<Map<String, String>> getUserInfo(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return {'name': 'Utilisateur', 'initials': '??'};
      final data = doc.data()!;
      final name = (data['name'] ?? data['nom'] ?? data['displayName'] ??
          'Utilisateur') as String;
      return {'name': name, 'initials': _getInitials(name)};
    } catch (_) {
      return {'name': 'Utilisateur', 'initials': '??'};
    }
  }

  // public باش تقدر تستعملها من messages_list_screen
  String getInitials(String name) => _getInitials(name);

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '??';
  }

  String formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String formatConversationTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y  a ${diff.inDays}j';
    return '${dt.day}/${dt.month}';
  }
}