// lib/auth/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential?> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String phone,
    String transport = '',
    String quartier = '',
    String genre = '',
    String donorType = '',
    DateTime? birthDate,
    String associationName = '',
    String registrationNumber = '',
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      Map<String, dynamic> userData = {
        'uid': cred.user!.uid,
        'name': name,
        'nom': name,                           // ← إضافة
        'email': email,
        'phone': _normalizePhone(phone),
        'role': role,
        'statut': 'En attente',                // ← إضافة
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
        'points': 0,
        'missionsCompleted': 0,
        'kgSaved': 0,
        'rating': 0.0,
        'ratingCount': 0,
      };

      if (role == 'benevole') {
        userData['transport'] = transport;
        userData['quartier'] = quartier;
        userData['genre'] = genre;
        userData['birthDate'] = birthDate?.toIso8601String() ?? '';
        userData['bio'] = 'Bénévole chez ZAD';
      } else if (role == 'donateur') {
        userData['donorType'] = donorType;
        userData['quartier'] = quartier;
        userData['genre'] = genre;
        userData['birthDate'] = birthDate?.toIso8601String() ?? '';
        userData['transport'] = transport;
      } else if (role == 'association') {
        userData['associationName'] = associationName;
        userData['registrationNumber'] = registrationNumber;
        userData['quartier'] = quartier;

        if (quartier.isNotEmpty) {
          try {
            List<Location> locations = await locationFromAddress(
              '$quartier, Tlemcen, Algeria',
            );
            if (locations.isNotEmpty) {
              userData['latitude'] = locations.first.latitude;
              userData['longitude'] = locations.first.longitude;
              userData['associationLat'] = locations.first.latitude;
              userData['associationLng'] = locations.first.longitude;
            }
          } catch (e) {
            debugPrint('❌ Geocoding association: $e');
          }
        }
      }

      await _db.collection('users').doc(cred.user!.uid).set(userData);
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  static Future<UserCredential?> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static String _normalizePhone(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[Oo]'), '0');
    normalized = normalized.replaceAll(RegExp(r'[\s\-]'), '');
    if (normalized.startsWith('+213')) {
      normalized = '0${normalized.substring(4)}';
    } else if (normalized.startsWith('213')) {
      normalized = '0${normalized.substring(3)}';
    }
    return normalized;
  }

  static Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      final normalizedInput = _normalizePhone(phone);

      var querySnapshot = await _db
          .collection('users')
          .where('phone', isEqualTo: normalizedInput)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _db
            .collection('users')
            .where('phone', isEqualTo: phone.trim())
            .limit(1)
            .get();
      }

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getUserByPhone: $e');
      return null;
    }
  }

  static Future<String?> createResetCode(String phone) async {
    try {
      final userData = await getUserByPhone(phone);
      if (userData == null) return null;
      final code = _generateRandomCode();
      final email = userData['email'];
      await _db.collection('password_resets').doc(email).set({
        'phone': phone,
        'email': email,
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 10)),
        'used': false,
      });
      debugPrint("📱 Code: $code pour $phone");
      return code;
    } catch (e) {
      debugPrint("❌ Erreur: $e");
      return null;
    }
  }

  static Future<bool> verifyResetCode(String phone, String code) async {
    try {
      final userData = await getUserByPhone(phone);
      if (userData == null) return false;
      final email = userData['email'];
      final doc = await _db.collection('password_resets').doc(email).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final storedCode = data['code'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final used = data['used'] ?? false;
      if (used) return false;
      if (expiresAt.isBefore(DateTime.now())) return false;
      if (storedCode != code) return false;
      return true;
    } catch (e) {
      debugPrint("❌ Erreur: $e");
      return false;
    }
  }

  static Future<void> markResetCodeAsUsed(String phone) async {
    try {
      final userData = await getUserByPhone(phone);
      if (userData != null) {
        final email = userData['email'];
        await _db
            .collection('password_resets')
            .doc(email)
            .update({'used': true});
      }
    } catch (e) {
      debugPrint("❌ Erreur: $e");
    }
  }

  static String _generateRandomCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return random.toString().padLeft(4, '0');
  }

  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (e) {
      debugPrint("❌ Erreur getUserData: $e");
      return null;
    }
  }

  static Future<bool> updateProfile({
    required String uid,
    String? name,
    String? phone,
    String? transport,
    String? quartier,
    String? bio,
    String? associationName,
    String? registrationNumber,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = _normalizePhone(phone);
      if (transport != null) updates['transport'] = transport;
      if (quartier != null) updates['quartier'] = quartier;
      if (bio != null) updates['bio'] = bio;
      if (associationName != null) updates['associationName'] = associationName;
      if (registrationNumber != null)
        updates['registrationNumber'] = registrationNumber;

      if (quartier != null) {
        try {
          List<Location> locations = await locationFromAddress(
            '$quartier, Tlemcen, Algeria',
          );
          if (locations.isNotEmpty) {
            updates['latitude'] = locations.first.latitude;
            updates['longitude'] = locations.first.longitude;
            updates['associationLat'] = locations.first.latitude;
            updates['associationLng'] = locations.first.longitude;
          }
        } catch (e) {
          debugPrint('❌ Geocoding update: $e');
        }
      }

      await _db.collection('users').doc(uid).update(updates);
      debugPrint("✅ Profil mis à jour: $updates");
      return true;
    } catch (e) {
      debugPrint("❌ Erreur updateProfile: $e");
      return false;
    }
  }

  // ==================== إدارة التبرعات ====================

  static Future<bool> addDon({
    required String donorId,
    required String donorName,
    required String title,
    required String description,
    required String quantity,
    required String imageUrl,
    required String address,
    required String quartier,
    required DateTime expiryDate,
    required bool isUrgent,
    double? donorLat,
    double? donorLng,
    String associationId = '',    // ✅ مُضاف
    String associationName = '',  // ✅ مُضاف
  }) async {
    try {
      double? lat = donorLat;
      double? lng = donorLng;

      if ((lat == null || lng == null) && address.isNotEmpty) {
        try {
          List<Location> locations = await locationFromAddress(
            '$address, Tlemcen, Algeria',
          );
          if (locations.isNotEmpty) {
            lat = locations.first.latitude;
            lng = locations.first.longitude;
          }
        } catch (e) {
          debugPrint('❌ Geocoding don: $e');
          lat = 34.8828;
          lng = -1.3167;
        }
      }

      final docRef = _db.collection('dons').doc();
      await docRef.set({
        'donId': docRef.id,
        'donorId': donorId,
        'donorName': donorName,
        'title': title,
        'description': description,
        'quantity': quantity,
        'imageUrl': imageUrl,
        'address': address,
        'quartier': quartier,
        'latitude': lat,
        'longitude': lng,
        'donorLat': lat,
        'donorLng': lng,
        'expiryDate': expiryDate.toIso8601String(),
        'isUrgent': isUrgent,
        'status': 'disponible',
        'volunteerId': '',
        'volunteerName': '',
        'volunteerLat': null,
        'volunteerLng': null,
        'associationId': associationId,    // ✅ يُحفظ من المعامل
        'associationName': associationName, // ✅ يُحفظ من المعامل
        'associationLat': null,
        'associationLng': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Don ajouté: ${docRef.id}");
      return true;
    } catch (e) {
      debugPrint("❌ Erreur addDon: $e");
      return false;
    }
  }

  static Future<void> _notifyAllBenevoles({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'benevole')
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        final notifRef = _db
            .collection('users')
            .doc(doc.id)
            .collection('notifications')
            .doc();
        batch.set(notifRef, {
          'title': title,
          'body': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': extraData ?? {},
        });
      }
      await batch.commit();
      debugPrint("✅ Notifications envoyées à ${snap.docs.length} bénévoles");
    } catch (e) {
      debugPrint("❌ Erreur notifyAllBenevoles: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getMyDons(String donorId) async {
    try {
      final querySnapshot = await _db
          .collection('dons')
          .where('donorId', isEqualTo: donorId)
          .orderBy('createdAt', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("❌ Erreur getMyDons: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableDons() async {
    try {
      final querySnapshot = await _db
          .collection('dons')
          .where('status', isEqualTo: 'disponible')
          .orderBy('isUrgent', descending: true)
          .orderBy('createdAt', descending: true)
          .get();
      debugPrint("📦 Dons disponibles: ${querySnapshot.docs.length}");
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("❌ Erreur getAvailableDons: $e");
      return [];
    }
  }

  static Future<bool> associationAcceptDon({
    required String donId,
    required String associationId,
    required String associationName,
  }) async {
    try {
      double? assocLat, assocLng;

      final assocDoc = await _db.collection('users').doc(associationId).get();
      if (assocDoc.exists) {
        final data = assocDoc.data()!;
        assocLat = (data['associationLat'] as num?)?.toDouble() ??
            (data['latitude'] as num?)?.toDouble();
        assocLng = (data['associationLng'] as num?)?.toDouble() ??
            (data['longitude'] as num?)?.toDouble();

        if ((assocLat == null || assocLng == null)) {
          final quartier = data['quartier'] as String? ?? '';
          if (quartier.isNotEmpty) {
            try {
              List<Location> locations = await locationFromAddress(
                '$quartier, Tlemcen, Algeria',
              );
              if (locations.isNotEmpty) {
                assocLat = locations.first.latitude;
                assocLng = locations.first.longitude;
                await _db.collection('users').doc(associationId).update({
                  'latitude': assocLat,
                  'longitude': assocLng,
                  'associationLat': assocLat,
                  'associationLng': assocLng,
                });
              }
            } catch (e) {
              debugPrint('❌ Geocoding association fallback: $e');
            }
          }
        }
      }

      final donDoc = await _db.collection('dons').doc(donId).get();
      final donData = donDoc.data() ?? {};
      final donTitle = donData['title'] as String? ?? 'Don';
      final donorName = donData['donorName'] as String? ?? '';
      final isUrgent = donData['isUrgent'] as bool? ?? false;
      final quartier = donData['quartier'] as String? ?? '';

      await _db.collection('dons').doc(donId).update({
        'status': 'accepte_par_association',
        'associationId': associationId,
        'associationName': associationName,
        'associationLat': assocLat,
        'associationLng': assocLng,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _notifyAllBenevoles(
        title: isUrgent
            ? '⚡ Don urgent disponible !'
            : '🍽️ Nouveau don disponible !',
        body:
            '$associationName a accepté "$donTitle"${quartier.isNotEmpty ? ' à $quartier' : ''}. Venez livrer !',
        type: 'new_don',
        extraData: {
          'donId': donId,
          'donTitle': donTitle,
          'donorName': donorName,
          'associationName': associationName,
          'isUrgent': isUrgent,
        },
      );

      debugPrint("✅ Don accepté + bénévoles notifiés: $donId");
      return true;
    } catch (e) {
      debugPrint("❌ Erreur associationAcceptDon: $e");
      return false;
    }
  }

  static Future<bool> associationRefuseDon({required String donId}) async {
    try {
      await _db.collection('dons').doc(donId).update({
        'status': 'refuse_par_association',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("❌ Erreur associationRefuseDon: $e");
      return false;
    }
  }

  static Future<bool> acceptMission({
    required String donId,
    required String volunteerId,
    required String volunteerName,
    double? volunteerLat,
    double? volunteerLng,
  }) async {
    try {
      await _db.collection('dons').doc(donId).update({
        'status': 'en_route',
        'volunteerId': volunteerId,
        'volunteerName': volunteerName,
        'volunteerLat': volunteerLat,
        'volunteerLng': volunteerLng,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("❌ Erreur acceptMission: $e");
      return false;
    }
  }

  static Future<bool> updateVolunteerLocation({
    required String donId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _db.collection('dons').doc(donId).update({
        'volunteerLat': lat,
        'volunteerLng': lng,
        'volunteerUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("❌ Erreur updateVolunteerLocation: $e");
      return false;
    }
  }

  static Future<bool> updateDonStatus({
    required String donId,
    required String status,
    String? volunteerId,
    String? volunteerName,
    String? associationId,
    String? associationName,
  }) async {
    try {
      Map<String, dynamic> updates = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (volunteerId != null) updates['volunteerId'] = volunteerId;
      if (volunteerName != null) updates['volunteerName'] = volunteerName;
      if (associationId != null) updates['associationId'] = associationId;
      if (associationName != null) updates['associationName'] = associationName;
      await _db.collection('dons').doc(donId).update(updates);
      return true;
    } catch (e) {
      debugPrint("❌ Erreur updateDonStatus: $e");
      return false;
    }
  }

  // ==================== ✅ نظام النقاط والمكافآت ====================

  static Future<void> completeMission({
    required String volunteerId,
    required String donId,
    required int kgSaved,
    int pointsEarned = 10,
  }) async {
    try {
      await _db.collection('users').doc(volunteerId).update({
        'missionsCompleted': FieldValue.increment(1),
        'kgSaved': FieldValue.increment(kgSaved),
        'points': FieldValue.increment(pointsEarned),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('dons').doc(donId).update({
        'status': 'livré',
        'deliveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotificationToUser(
        userId: volunteerId,
        title: '🎉 Mission accomplie !',
        body: '+$pointsEarned pts · $kgSaved kg sauvés. Continuez comme ça !',
        type: 'mission_completed',
        extraData: {
          'donId': donId,
          'pointsEarned': pointsEarned,
          'kgSaved': kgSaved,
        },
      );

      await _checkAndNotifyNewRecompenses(volunteerId);
      debugPrint("✅ Mission complétée: +$pointsEarned pts pour $volunteerId");
    } catch (e) {
      debugPrint("❌ Erreur completeMission: $e");
    }
  }

  static Future<void> addRating({
    required String volunteerId,
    required String raterName,
    required double rating,
    String donId = '',
  }) async {
    try {
      final doc = await _db.collection('users').doc(volunteerId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final currentRating = (data['rating'] ?? 0.0).toDouble();
      final currentCount = (data['ratingCount'] ?? 0).toInt();

      final newCount = currentCount + 1;
      final newRating = ((currentRating * currentCount) + rating) / newCount;

      final int ratingPoints = rating >= 5 ? 5 : rating >= 4 ? 3 : 1;

      await _db.collection('users').doc(volunteerId).update({
        'rating': newRating,
        'ratingCount': newCount,
        'points': FieldValue.increment(ratingPoints),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _sendNotificationToUser(
        userId: volunteerId,
        title: '⭐ Nouvelle évaluation !',
        body:
            '$raterName vous a évalué avec ${rating.toStringAsFixed(1)}/5 étoiles (+$ratingPoints pts)',
        type: 'new_rating',
        extraData: {
          'raterName': raterName,
          'rating': rating,
          'pointsEarned': ratingPoints,
          'donId': donId,
        },
      );

      await _checkAndNotifyNewRecompenses(volunteerId);
      debugPrint(
          "✅ Évaluation ajoutée: $rating/5 → $newRating (moy) +$ratingPoints pts");
    } catch (e) {
      debugPrint("❌ Erreur addRating: $e");
    }
  }

  static Future<bool> addRecompense({
    required String title,
    required String partner,
    required String partnerCity,
    required String type,
    required String icon,
    required String code,
    required String expiry,
    required int requiredPoints,
    String discount = '',
    String createdByName = '',
  }) async {
    try {
      final docRef = _db.collection('recompenses').doc();
      await docRef.set({
        'id': docRef.id,
        'title': title,
        'partner': partner,
        'partnerCity': partnerCity,
        'type': type,
        'icon': icon,
        'code': code,
        'expiry': expiry,
        'requiredPoints': requiredPoints,
        'discount': discount,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByName': createdByName,
      });

      debugPrint("✅ Récompense ajoutée: ${docRef.id}");

      await _notifyEligibleBenevoles(
        recompenseId: docRef.id,
        title: title,
        partner: partner,
        requiredPoints: requiredPoints,
        type: type,
      );

      return true;
    } catch (e) {
      debugPrint("❌ Erreur addRecompense: $e");
      return false;
    }
  }

  static Future<void> _notifyEligibleBenevoles({
    required String recompenseId,
    required String title,
    required String partner,
    required int requiredPoints,
    required String type,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'benevole')
          .where('points', isGreaterThanOrEqualTo: requiredPoints)
          .get();

      if (snap.docs.isEmpty) {
        debugPrint("ℹ️ Aucun bénévole éligible pour cette récompense");
        return;
      }

      final batch = _db.batch();
      final emoji = type == 'meal' ? '🍽️' : '🏷️';

      for (final doc in snap.docs) {
        final notifRef = _db
            .collection('users')
            .doc(doc.id)
            .collection('notifications')
            .doc();
        batch.set(notifRef, {
          'title': '$emoji Nouvelle récompense débloquée !',
          'body':
              '"$title" chez $partner est maintenant disponible pour vous !',
          'type': 'new_recompense',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'recompenseId': recompenseId,
            'recompenseTitle': title,
            'partner': partner,
            'requiredPoints': requiredPoints,
          },
        });
      }
      await batch.commit();
      debugPrint(
          "✅ ${snap.docs.length} bénévoles notifiés pour la nouvelle récompense");
    } catch (e) {
      debugPrint("❌ Erreur notifyEligibleBenevoles: $e");
    }
  }

  static Future<void> _checkAndNotifyNewRecompenses(
      String volunteerId) async {
    try {
      final userDoc = await _db.collection('users').doc(volunteerId).get();
      if (!userDoc.exists) return;

      final currentPoints = (userDoc.data()!['points'] ?? 0).toInt();

      final recompensesSnap = await _db
          .collection('recompenses')
          .where('isActive', isEqualTo: true)
          .get();

      final notifiedSnap = await _db
          .collection('users')
          .doc(volunteerId)
          .collection('notifiedRecompenses')
          .get();
      final notifiedIds = notifiedSnap.docs.map((d) => d.id).toSet();

      final batch = _db.batch();
      bool hasNewUnlocked = false;

      for (final doc in recompensesSnap.docs) {
        final data = doc.data();
        final required = (data['requiredPoints'] ?? 0).toInt();
        final recompenseId = doc.id;

        if (currentPoints >= required &&
            !notifiedIds.contains(recompenseId)) {
          hasNewUnlocked = true;

          final notifRef = _db
              .collection('users')
              .doc(volunteerId)
              .collection('notifications')
              .doc();
          batch.set(notifRef, {
            'title':
                '${data['type'] == 'meal' ? '🍽️' : '🏷️'} Récompense débloquée !',
            'body':
                '"${data['title']}" chez ${data['partner']} est maintenant disponible !',
            'type': 'new_recompense',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'data': {
              'recompenseId': recompenseId,
              'recompenseTitle': data['title'],
              'partner': data['partner'],
            },
          });

          final notifiedRef = _db
              .collection('users')
              .doc(volunteerId)
              .collection('notifiedRecompenses')
              .doc(recompenseId);
          batch.set(notifiedRef, {
            'unlockedAt': FieldValue.serverTimestamp(),
            'pointsAtUnlock': currentPoints,
          });
        }
      }

      if (hasNewUnlocked) {
        await batch.commit();
        debugPrint(
            "✅ Nouvelles récompenses débloquées notifiées pour $volunteerId");
      }
    } catch (e) {
      debugPrint("❌ Erreur checkAndNotifyNewRecompenses: $e");
    }
  }

  static Future<void> _sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc()
          .set({
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': extraData ?? {},
      });
    } catch (e) {
      debugPrint("❌ Erreur _sendNotificationToUser: $e");
    }
  }
}
