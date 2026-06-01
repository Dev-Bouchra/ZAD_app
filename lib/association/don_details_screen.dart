// lib/association/don_details_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_service.dart';

class DonDetailsScreen extends StatefulWidget {
  final String donId;
  final Map<String, dynamic> donData;

  const DonDetailsScreen({
    super.key,
    required this.donId,
    required this.donData,
  });

  @override
  State<DonDetailsScreen> createState() => _DonDetailsScreenState();
}

class _DonDetailsScreenState extends State<DonDetailsScreen> {
  bool _isLoading = false;

  Future<void> _acceptDon() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack("Erreur: utilisateur non connecté", Colors.red);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final assocName = userData['associationName'] ?? userData['name'] ?? 'Association';

      final double? assocLat = (userData['associationLat'] as num?)?.toDouble()
          ?? (userData['latitude'] as num?)?.toDouble();
      final double? assocLng = (userData['associationLng'] as num?)?.toDouble()
          ?? (userData['longitude'] as num?)?.toDouble();
      final String assocAddress = userData['quartier'] ?? userData['address'] ?? '';

      final donDoc = await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .get();
      final donDocData = donDoc.data() ?? {};
      final donorId = donDocData['donorId'] ?? '';
      final donTitle = donDocData['title'] ?? 'Don';
      final benevoleId = donDocData['benevoleId'] ?? '';
      final benevoleName = donDocData['benevoleName'] ?? '';

      double? donorLat;
      double? donorLng;
      if (donorId.isNotEmpty) {
        try {
          final donorDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(donorId)
              .get();
          if (donorDoc.exists) {
            final donorData = donorDoc.data()!;
            donorLat = (donorData['latitude'] as num?)?.toDouble()
                ?? (donorData['donorLat'] as num?)?.toDouble();
            donorLng = (donorData['longitude'] as num?)?.toDouble()
                ?? (donorData['donorLng'] as num?)?.toDouble();
          }
        } catch (e) {
          print("⚠️ Impossible de récupérer la position du donateur: $e");
        }
      }

      final updateData = <String, dynamic>{
        'status': 'accepte_par_association',
        'associationId': user.uid,
        'associationName': assocName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (assocLat != null && assocLng != null) {
        updateData['associationLat'] = assocLat;
        updateData['associationLng'] = assocLng;
        updateData['associationAddress'] = assocAddress;
        print('✅ Position association sauvegardée: $assocLat, $assocLng');
      } else {
        print('⚠️ Position de l\'association non définie dans le profil');
      }

      if (donorLat != null && donorLng != null) {
        updateData['donorLat'] = donorLat;
        updateData['donorLng'] = donorLng;
        print('✅ Position donateur sauvegardée: $donorLat, $donorLng');
      } else {
        print('⚠️ Position du donateur non définie');
      }

      await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .update(updateData);

      if (donorId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: donorId,
          title: 'Votre don a été accepté ! ✅',
          body: '$assocName a accepté votre don "$donTitle"',
          type: 'don',
          extraData: {'donId': widget.donId},
        );
      }

      if (benevoleId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: benevoleId,
          title: '📦 Nouveau don disponible !',
          body: 'Un don "$donTitle" est disponible. Veuillez vous rapprocher de l\'association.',
          type: 'don_available',
          extraData: {
            'donId': widget.donId,
            'donTitle': donTitle,
          },
        );
        print('✅ Notification envoyée au bénévole: $benevoleId');
      } else {
        print('⚠️ Pas de benevoleId associé à ce don');
      }

      if (mounted) {
        _showSnack("✅ Don accepté ! Les bénévoles vont le voir.", Colors.green);
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ Erreur acceptDon: $e");
      _showSnack("Erreur lors de l'acceptation", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refuseDon() async {
    setState(() => _isLoading = true);
    try {
      final donDoc = await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .get();
      final donorId = donDoc.data()?['donorId'] ?? '';
      final donTitle = donDoc.data()?['title'] ?? 'Don';

      await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .update({
        'status': 'refuse',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (donorId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: donorId,
          title: 'Don non accepté',
          body: 'Votre don "$donTitle" n\'a pas été retenu cette fois',
          type: 'urgent',
          extraData: {'donId': widget.donId},
        );
      }

      if (mounted) {
        _showSnack("Don refusé.", Colors.redAccent);
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
      }
    } catch (e) {
      print("❌ Erreur refuseDon: $e");
      _showSnack("Erreur lors du refus", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _showConfirmDialog({required bool isAccept}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAccept ? 'Confirmer l\'acceptation' : 'Confirmer le refus',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAccept
              ? 'Voulez-vous accepter ce don ? Il sera visible pour les bénévoles.'
              : 'Voulez-vous refuser ce don ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isAccept) {
                _acceptDon();
              } else {
                _refuseDon();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isAccept ? const Color(0xFF1B5E20) : Colors.redAccent,
            ),
            child: Text(
              isAccept ? 'Accepter' : 'Refuser',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final don = widget.donData;
    final isUrgent = don['isUrgent'] == true || don['statut'] == 'Urgent';

    // ✅ قراءة رابط الصورة من بيانات التبرع
    final String? imageUrl = don['imageUrl'] as String?;
    final bool hasImage = imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.contains('placeholder');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Détails du Don',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ عرض الصورة الحقيقية إذا وجدت
                  if (hasImage)
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: Image.network(
                          imageUrl!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 220,
                              color: const Color(0xFFE8F5E9),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 220,
                              width: double.infinity,
                              color: const Color(0xFFE8F5E9),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 60,
                                    color: Color(0xFF1B5E20),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Image non disponible',
                                    style: TextStyle(
                                      color: Color(0xFF1B5E20),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    // ✅ أيقونة افتراضية إذا لم توجد صورة
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: const Color(0xFFE8F5E9),
                      child: const Icon(
                        Icons.restaurant,
                        size: 100,
                        color: Color(0xFF1B5E20),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                don['source'] ?? don['donorName'] ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A2B4A),
                                ),
                              ),
                            ),
                            if (isUrgent)
                              _buildBadge("Urgent", Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                don['adresse'] ?? don['address'] ?? '',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          "Détails du don",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A2B4A),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildDetailTile(
                          Icons.fastfood_outlined,
                          "Produit",
                          don['titre'] ?? don['title'] ?? '',
                        ),
                        _buildDetailTile(
                          Icons.shopping_bag_outlined,
                          "Quantité",
                          don['quantite'] ?? don['quantity'] ?? '',
                        ),
                        if ((don['description'] ?? '').isNotEmpty)
                          _buildDetailTile(
                            Icons.info_outline,
                            "Description",
                            don['description'],
                          ),
                        _buildDetailTile(
                          Icons.timer_outlined,
                          "Expiration",
                          don['expiration'] ?? don['expiryDate'] ?? '',
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () =>
                                _showConfirmDialog(isAccept: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Accepter ce don",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton(
                            onPressed: () =>
                                _showConfirmDialog(isAccept: false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.redAccent, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              "Refuser",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1B5E20), size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2B4A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}