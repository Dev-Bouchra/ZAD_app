// lib/screens/association/confirmer_reception_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:a/cloudinary_service.dart';
import 'report_problem_screen.dart';
import 'home_screen.dart';
import '../../notification_service.dart'; // ✅ إضافة import

class ZadColors {
  static const Color darkNavy   = Color(0xFF1A2B4A);
  static const Color teal       = Color(0xFF2E7D7D);
  static const Color leafGreen  = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFCCD6E0);
  static const Color labelGrey  = Color(0xFF6B7A8D);
  static const Color cardBg     = Color(0xFFF5F7FA);
  static const Color textDark   = Color(0xFF1A2B4A);
}

class ConfirmerReceptionScreen extends StatefulWidget {
  final String donId;

  const ConfirmerReceptionScreen({super.key, required this.donId});

  @override
  State<ConfirmerReceptionScreen> createState() =>
      _ConfirmerReceptionScreenState();
}

class _ConfirmerReceptionScreenState
    extends State<ConfirmerReceptionScreen> {
  File? _image;
  final ImagePicker _picker = ImagePicker();

  bool   _isLoading       = true;
  bool   _isConfirming    = false;
  String _volunteerName   = '';
  String _volunteerInitials = 'BN';
  double _volunteerRating = 0.0;
  int    _volunteerMissions = 0;
  String _donTitle        = '';
  String _donSource       = '';
  String _donQuantity     = '';
  String _deliveredAt     = '';
  int    _durationMinutes = 0;
  String _volunteerId     = '';
  String _donorId         = '';
  String _associationId   = '';
  String _donStatus       = '';

  @override
  void initState() {
    super.initState();
    _loadDonData();
  }

  Future<void> _loadDonData() async {
    try {
      final donDoc = await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .get();

      if (!donDoc.exists || !mounted) return;
      final d = donDoc.data()!;

      final String volunteerId  = d['volunteerId'] ?? '';
      String volunteerName      = d['volunteerName'] ?? '';
      double rating             = 0.0;
      int    missions           = 0;

      if (volunteerId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(volunteerId)
              .get();
          if (userDoc.exists) {
            final ud  = userDoc.data()!;
            volunteerName = ud['name'] ?? volunteerName;
            rating        = (ud['rating'] as num?)?.toDouble() ?? 0.0;
            missions      = (ud['completedMissions'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}
      }

      String deliveredAt = '';
      int    durationMin  = 0;
      try {
        final now  = DateTime.now();
        final hour = now.hour.toString().padLeft(2, '0');
        final min  = now.minute.toString().padLeft(2, '0');
        deliveredAt = 'Livré à ${hour}h$min';

        final reservedAt =
            (d['reservedAt'] as dynamic?)?.toDate() as DateTime?;
        if (reservedAt != null) {
          durationMin = now.difference(reservedAt).inMinutes.clamp(1, 999);
        }
      } catch (_) {}

      String initials = 'BN';
      if (volunteerName.isNotEmpty) {
        final parts = volunteerName.trim().split(' ');
        initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : volunteerName
                .substring(0, volunteerName.length.clamp(0, 2))
                .toUpperCase();
      }

      final donStatus = d['status'] as String? ?? '';

      if (!mounted) return;
      setState(() {
        _volunteerId      = volunteerId;
        _donorId          = d['donorId'] ?? '';
        _associationId    = d['associationId'] ?? '';
        _donStatus        = donStatus;
        _volunteerName    = volunteerName.isEmpty ? 'Bénévole' : volunteerName;
        _volunteerInitials = initials;
        _volunteerRating  = rating;
        _volunteerMissions = missions;
        _donTitle         = d['title'] ?? 'Don';
        _donSource        = d['donorName'] ?? '';
        _donQuantity      = d['quantity']?.toString() ?? '';
        _deliveredAt      = deliveredAt;
        _durationMinutes  = durationMin;
        _isLoading        = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur loadDonData: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: ZadColors.leafGreen),
              title: const Text('Galerie'),
              onTap: () async {
                final XFile? selected = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (selected != null)
                  setState(() => _image = File(selected.path));
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt,
                  color: ZadColors.leafGreen),
              title: const Text('Appareil photo'),
              onTap: () async {
                final XFile? selected = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (selected != null)
                  setState(() => _image = File(selected.path));
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmerReception() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    try {
      String? photoUrl;

      // رفع الصورة إلى Cloudinary
      if (_image != null) {
        photoUrl = await CloudinaryService.uploadFile(
          _image!,
          resourceType: 'image',
        );
      }

      // ✅ تحديث status الدون
      await FirebaseFirestore.instance
          .collection('dons')
          .doc(widget.donId)
          .update({
        'status':               'livre',
        'confirmedAt':          FieldValue.serverTimestamp(),
        'confirmationPhotoUrl': photoUrl,
        'updatedAt':            FieldValue.serverTimestamp(),
      });

      // ✅ تحديث نقاط ومهام البينيفول
      if (_volunteerId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_volunteerId)
            .update({
          'completedMissions': FieldValue.increment(1),
          'points':            FieldValue.increment(10),
        });
      }

      // ✅ إشعار للبينيفول
      if (_volunteerId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: _volunteerId,
          title: '✅ Livraison confirmée !',
          body: 'L\'association a confirmé la réception de "$_donTitle". Vous avez gagné 10 points 🎉',
          type: 'mission_completed',
        );
      }

      // ✅ إشعار للدوناتور
      if (_donorId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: _donorId,
          title: '🎉 Votre don a été livré !',
          body: '"$_donTitle" a bien été reçu par l\'association. Merci pour votre générosité !',
          type: 'livraison',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Réception confirmée avec succès !'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint("❌ Erreur confirmation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la confirmation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZadColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Confirmer la réception',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32),
                  child: Text(
                    'Vérifiez le don avant de confirmer',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('BÉNÉVOLE ASSIGNÉ'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildAvatar(_volunteerInitials),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _volunteerName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: ZadColors.darkNavy,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star,
                                                color: Color(0xFFFFB800),
                                                size: 14),
                                            Text(
                                              _volunteerRating > 0
                                                  ? ' ${_volunteerRating.toStringAsFixed(1)} · $_volunteerMissions missions réalisées'
                                                  : ' $_volunteerMissions missions réalisées',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: ZadColors.labelGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('DÉTAIL DU DON'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildIconContainer(
                                      _getDonIcon(_donTitle)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _donTitle,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: ZadColors.darkNavy,
                                          ),
                                        ),
                                        Text(
                                          _donSource.isNotEmpty
                                              ? '$_donSource · $_donQuantity'
                                              : _donQuantity,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ZadColors.labelGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (_deliveredAt.isNotEmpty)
                                    _buildBadge(
                                      _deliveredAt,
                                      const Color(0xFFE8F5E9),
                                      ZadColors.leafGreen,
                                    ),
                                  if (_durationMinutes > 0) ...[
                                    const SizedBox(width: 8),
                                    _buildBadge(
                                      'Durée : $_durationMinutes min',
                                      const Color(0xFFE3F2FD),
                                      const Color(0xFF1565C0),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _image == null ? _pickImage : null,
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: ZadColors.cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _image == null
                                        ? ZadColors.inputBorder
                                        : ZadColors.leafGreen,
                                    width: 1.5,
                                  ),
                                  image: _image != null
                                      ? DecorationImage(
                                          image: FileImage(_image!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _image == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.camera_alt_outlined,
                                            color: ZadColors.labelGrey,
                                            size: 32,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Photo de confirmation',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: ZadColors.darkNavy,
                                            ),
                                          ),
                                          Text(
                                            'Optionnel · Prenez une photo du don reçu',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: ZadColors.labelGrey,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                              if (_image != null)
                                Positioned(
                                  top: 10, right: 10,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _image = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFFFCDD2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_outlined,
                                color: Color(0xFFE53935),
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Un problème avec le don ?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFE53935),
                                      ),
                                    ),
                                    Text(
                                      'Signalez-le avant de confirmer la réception',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFB71C1C),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isConfirming || _donStatus != 'recu_par_benevole')
                        ? null
                        : _confirmerReception,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _donStatus == 'recu_par_benevole'
                          ? ZadColors.leafGreen
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isConfirming
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _donStatus == 'recu_par_benevole'
                                ? 'Confirmer la réception'
                                : '⏳ En attente du bénévole...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ReportProblemScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFE53935)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      'Signaler un problème',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDonIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('pain') || t.contains('boulangerie'))
      return Icons.bakery_dining;
    if (t.contains('repas') || t.contains('plat')) return Icons.restaurant;
    if (t.contains('fruit') || t.contains('légume')) return Icons.eco;
    if (t.contains('conserve')) return Icons.kitchen;
    return Icons.volunteer_activism;
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZadColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ZadColors.labelGrey,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildAvatar(String initials) {
    return Container(
      width: 46, height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFF1B5E20),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: ZadColors.leafGreen, size: 22),
    );
  }

  Widget _buildBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textCol,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}