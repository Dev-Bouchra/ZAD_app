import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class NotificationService {
  // ✅ المسار الموحّد — نفس ما تقرأه notifications_screen.dart
  static CollectionReference _notifsRef(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('messages'); // ✅ كان 'userNotifications' — هذا سبب المشكلة
  }

  // ✅ init — مطلوب من main.dart
  Future<void> init() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('⚠️ FCM init error: $e');
    }
  }

  // ✅ حفظ FCM token بعد اللوجين
  Future<void> saveTokenAfterLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('⚠️ saveTokenAfterLogin error: $e');
    }
  }

  // ✅ إرسال إشعار لمستخدم معين
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _notifsRef(userId).add({
        'titre': title,
        'title': title,
        'message': body,
        'body': body,
        'type': type,
        'lu': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        ...?extraData,
      });
      debugPrint('✅ Notification envoyée à $userId');
    } catch (e) {
      debugPrint('❌ sendNotificationToUser error: $e');
    }
  }

  // ✅ تعليم إشعار واحد كمقروء
  static Future<void> markAsRead(String notifId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _notifsRef(user.uid).doc(notifId).update({
        'lu': true,
        'isRead': true,
      });
    } catch (e) {
      debugPrint('❌ markAsRead error: $e');
    }
  }

  // ✅ تعليم جميع الإشعارات كمقروءة
  static Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snap = await _notifsRef(user.uid)
          .where('lu', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'lu': true, 'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ markAllAsRead error: $e');
    }
  }

  // ✅ Stream لعدد الإشعارات غير المقروءة (للـ badge في الـ header)
  static Stream<int> unreadCountStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return _notifsRef(user.uid)
        .where('lu', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  }
}