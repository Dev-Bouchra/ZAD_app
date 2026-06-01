// 📄 lib/donateur/offre_manager.dart
// مدير العروض مع Firebase Firestore - نسخة مصلحة مع requiredPoints

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OffreManager {
  // Singleton
  OffreManager._();
  static final OffreManager instance = OffreManager._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ الحصول على تيار العروض للمستخدم الحالي
  Stream<List<Map<String, dynamic>>> getOffresStream() {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('offres')
        .where('donorId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {
              'id': doc.id,
              ...doc.data(),
            };
          }).toList();
        });
  }

  // ✅ الحصول على قائمة العروض (Future)
  Future<List<Map<String, dynamic>>> getOffresFuture() async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return [];
    }

    final querySnapshot = await _firestore
        .collection('offres')
        .where('donorId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  // ✅ إضافة عرض جديد (مع requiredPoints)
  Future<void> ajouterOffre(Map<String, dynamic> offre) async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      throw Exception('Vous devez être connecté');
    }

    // ✅ التحقق من صحة البيانات قبل الإرسال
    final Map<String, dynamic> offreData = {
      'title': offre['title']?.toString() ?? '',
      'description': offre['description']?.toString() ?? '',
      'type': offre['type']?.toString() ?? 'reduction',
      'valeur': offre['valeur']?.toString() ?? '',
      'expiry': offre['expiry']?.toString() ?? 'Indéfiniment',
      'restants': offre['restants'] is int ? offre['restants'] : (offre['restants'] == -1 ? -1 : 50),
      'icon': offre['icon']?.toString() ?? '🎁',
      'partenaire': offre['partenaire']?.toString() ?? 'Notre partenaire',
      'code': offre['code']?.toString() ?? 'ZAD-${DateTime.now().millisecondsSinceEpoch}',
      'donorId': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // ✅ النقاط المطلوبة لفتح العرض
      'requiredPoints': offre['requiredPoints'] ?? 10,
    };

    try {
      await _firestore.collection('offres').add(offreData);
      debugPrint('✅ Offre ajoutée avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'ajout: $e');
      throw Exception('Erreur lors de la création de l\'offre: $e');
    }
  }

  // ✅ حذف عرض
  Future<void> supprimerOffre(String offreId) async {
    if (offreId.isEmpty) {
      throw Exception('ID d\'offre invalide');
    }

    try {
      await _firestore.collection('offres').doc(offreId).delete();
      debugPrint('✅ Offre supprimée avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression: $e');
      throw Exception('Erreur lors de la suppression: $e');
    }
  }

  // ✅ تحديث عرض
  Future<void> mettreAJourOffre(String offreId, Map<String, dynamic> data) async {
    if (offreId.isEmpty) {
      throw Exception('ID d\'offre invalide');
    }

    try {
      await _firestore.collection('offres').doc(offreId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  // ✅ إنقاص عدد الاستخدامات المتبقية
  Future<void> decrementerRestants(String offreId, int restantsActuels) async {
    if (offreId.isEmpty) {
      throw Exception('ID d\'offre invalide');
    }

    final nouveauxRestants = restantsActuels - 1;

    if (nouveauxRestants < -1) {
      throw Exception('Plus d\'utilisations disponibles');
    }

    try {
      await _firestore.collection('offres').doc(offreId).update({
        'restants': nouveauxRestants,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  // ✅ الحصول على عرض بواسطة ID
  Future<Map<String, dynamic>?> getOffreById(String offreId) async {
    if (offreId.isEmpty) {
      return null;
    }

    final doc = await _firestore.collection('offres').doc(offreId).get();

    if (doc.exists) {
      return {
        'id': doc.id,
        ...doc.data()!,
      };
    }

    return null;
  }

  // ✅ الحصول على عدد العروض النشطة
  Future<int> getNombreOffresActives() async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return 0;
    }

    final querySnapshot = await _firestore
        .collection('offres')
        .where('donorId', isEqualTo: currentUserId)
        .where('restants', isNotEqualTo: 0)
        .get();

    return querySnapshot.size;
  }

  // ✅ الحصول على عدد العروض المنتهية
  Future<int> getNombreOffresExpirees() async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return 0;
    }

    final querySnapshot = await _firestore
        .collection('offres')
        .where('donorId', isEqualTo: currentUserId)
        .where('restants', isEqualTo: 0)
        .get();

    return querySnapshot.size;
  }

  // ✅ حذف جميع العروض
  Future<void> supprimerToutesOffres() async {
    final String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null) {
      return;
    }

    final querySnapshot = await _firestore
        .collection('offres')
        .where('donorId', isEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();

    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ✅ التحقق من صحة العرض
  Future<bool> isOffreValide(String offreId) async {
    final offre = await getOffreById(offreId);

    if (offre == null) return false;

    final restants = offre['restants'] as int? ?? 0;

    if (restants == 0) return false;

    final expiryStr = offre['expiry'] as String?;
    if (expiryStr != null && expiryStr != 'Indéfiniment') {
      try {
        final parts = expiryStr.split('/');
        if (parts.length == 3) {
          final expiryDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
          if (expiryDate.isBefore(DateTime.now())) {
            return false;
          }
        }
      } catch (e) {
        // تجاهل خطأ التحليل
      }
    }

    return true;
  }
}