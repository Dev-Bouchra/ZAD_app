import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';

class EvaluationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<bool> submitEvaluation({
    required String toUserId,
    required String toUserRole,
    required String toUserName,
    required String donationId,
    required String missionTitle,
    required int notePonctualite,
    required int noteSoin,
    required int noteComportement,
    required String commentaire,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await _db.collection('users').doc(user.uid).get();
      final fromUserName = userDoc.data()?['name'] ?? 
                           userDoc.data()?['associationName'] ?? 
                           'Utilisateur';
      
      String fromUserRole = 'user';
      if (userDoc.data()?['role'] != null) {
        fromUserRole = userDoc.data()!['role'];
      }

      final moyenne = (notePonctualite + noteSoin + noteComportement) / 3;

      await _db.collection('ratings').doc().set({
        'fromUserId': user.uid,
        'fromUserRole': fromUserRole,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserRole': toUserRole,
        'toUserName': toUserName,
        'donationId': donationId,
        'missionTitle': missionTitle,
        'notePonctualite': notePonctualite,
        'noteSoin': noteSoin,
        'noteComportement': noteComportement,
        'moyenne': moyenne,
        'commentaire': commentaire,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await NotificationService.sendNotificationToUser(
        userId: toUserId,
        title: '⭐ Nouvelle évaluation !',
        body: '$fromUserName vous a évalué avec ${moyenne.toStringAsFixed(1)}/5 étoiles',
        type: 'evaluation',
        extraData: {
          'moyenne': moyenne.toStringAsFixed(1),
          'donationId': donationId,
        },
      );

      return true;
    } catch (e) {
      print('❌ Erreur evaluation: $e');
      return false;
    }
  }

  static Future<double> getUserAverageRating(String userId) async {
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double sum = 0;
      for (var doc in snapshot.docs) {
        sum += (doc.data()['moyenne'] ?? 0).toDouble();
      }
      return sum / snapshot.docs.length;
    } catch (e) {
      return 0.0;
    }
  }

  static Future<int> getUserRatingsCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}