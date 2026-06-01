import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../main.dart';
import '../notification_service.dart';
import '../auth/auth_service.dart';
import '../shared/location_picker_screen.dart';
import 'home_screen.dart';
import 'my_dons_screen.dart';
import 'package:a/cloudinary_service.dart';
import '../shared/zad_colors.dart';

class BesoinPrefill {
  final String besoinId;
  final String typeBesoin;
  final String associationId;
  final String associationNom;
  final String quantiteEstimee;
  final String notes;
  final Timestamp? dateLimite;
  final String niveauUrgence;

  const BesoinPrefill({
    required this.besoinId,
    required this.typeBesoin,
    required this.associationId,
    required this.associationNom,
    required this.quantiteEstimee,
    required this.notes,
    required this.dateLimite,
    required this.niveauUrgence,
  });
}

class PublishDonScreen extends StatefulWidget {
  final BesoinPrefill? prefillFromBesoin;
  const PublishDonScreen({super.key, this.prefillFromBesoin});

  @override
  State<PublishDonScreen> createState() => _PublishDonScreenState();
}

class _PublishDonScreenState extends State<PublishDonScreen> {
  final _descriptionController = TextEditingController();
  final _quantityController    = TextEditingController();
  final _autreController       = TextEditingController();

  File?     _photoFile;
  String?   _uploadedImageUrl;
  DateTime? _expiryDate;
  bool      _isUrgent       = false;
  bool      _isSaving       = false;
  bool      _isUploadingImg = false;
  String    _foodType       = 'Plat cuisiné';
  bool      _showAutreField = false;

  String _donorId   = '';
  String _donorName = '';
  String _donorType = '';

  // ✅ إحداثيات الموقع (من الخريطة فقط)
  double? _donorLat;
  double? _donorLng;
  String? _donorPlaceName; // اسم المكان المختار من Search

  final _picker = ImagePicker();

  BesoinPrefill? get _prefill    => widget.prefillFromBesoin;
  bool           get _hasPrefill => _prefill != null;

  List<String> get _availableFoodTypes {
    switch (_donorType) {
      case 'Restaurant':
        return ['Plat cuisiné', 'Fast-food', 'Boissons'];
      case 'Boulangerie':
        return ['Pain'];
      case 'Commerce de produits alimentaires':
        return ['Pain', 'Fruits & Légumes', 'Produits laitiers', 'Conserves', 'Autre'];
      default:
        return ['Plat cuisiné', 'Pain', 'Fruits & Légumes', 'Produits laitiers', 'Conserves', 'Autre'];
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    if (_hasPrefill) {
      final p = _prefill!;
      _foodType = _mapTypeBesoin(p.typeBesoin);
      _quantityController.text = p.quantiteEstimee;
      _descriptionController.text = p.notes.isNotEmpty
          ? p.notes
          : 'Don en réponse au besoin "${p.typeBesoin}" de ${p.associationNom}';
      _isUrgent = p.niveauUrgence == 'Haute';
      if (p.dateLimite != null) _expiryDate = p.dateLimite!.toDate();
    }
  }

  String _mapTypeBesoin(String t) {
    const mapping = {
      'Repas chaud': 'Plat cuisiné',
      'Plat cuisiné': 'Plat cuisiné',
      'Fast-food': 'Fast-food',
      'Boissons': 'Boissons',
      'Pain': 'Pain',
      'Fruits & Légumes': 'Fruits & Légumes',
      'Produits laitiers': 'Produits laitiers',
      'Épicerie sèche': 'Conserves',
      'Conserves': 'Conserves',
      'Autre': 'Autre',
    };
    return mapping[t] ?? 'Autre';
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _donorId = user.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _donorName = data['name'] ?? 'Donateur';
          _donorType = data['donorType'] ?? '';
          if (!_availableFoodTypes.contains(_foodType) &&
              _availableFoodTypes.isNotEmpty) {
            _foodType = _availableFoodTypes.first;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ $e");
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _photoFile      = File(picked.path);
        _isUploadingImg = true;
      });
      final imageUrl = await CloudinaryService.uploadAuto(_photoFile!);
      if (imageUrl != null) {
        setState(() {
          _uploadedImageUrl = imageUrl;
          _isUploadingImg   = false;
        });
      } else {
        setState(() {
          _photoFile        = null;
          _uploadedImageUrl = null;
          _isUploadingImg   = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Échec du téléchargement de la photo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) setState(() => _expiryDate = date);
  }

  // ✅ فتح شاشة الخريطة مع Search
  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: 'Position du don',
          initialLocation: _donorLat != null
              ? LatLng(_donorLat!, _donorLng!)
              : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _donorLat       = result['lat'] as double;
        _donorLng       = result['lng'] as double;
        _donorPlaceName = result['name'] as String?;
      });
    }
  }

  Future<void> _notifyAssociations(String donId, String donTitle) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'association')
          .get();
      for (final doc in snapshot.docs) {
        await NotificationService.sendNotificationToUser(
          userId: doc.id,
          title: _isUrgent
              ? '⚡ Don urgent disponible !'
              : '🍽️ Nouveau don disponible !',
          body: '$_donorName · $donTitle · ${_quantityController.text.trim()}',
          type: _isUrgent ? 'urgent' : 'don',
          extraData: {'donId': donId},
        );
      }
    } catch (e) {
      debugPrint('❌ $e');
    }
  }

  Future<void> _saveDon() async {
    if (_descriptionController.text.isEmpty) {
      _showError("Entrez la description du don"); return;
    }
    if (_quantityController.text.isEmpty) {
      _showError("Entrez la quantité"); return;
    }
    if (_expiryDate == null) {
      _showError("Choisissez la date d'expiration"); return;
    }
    if (_donorLat == null || _donorLng == null) {
      _showError("Veuillez marquer la position sur la carte"); return;
    }

    setState(() => _isSaving = true);

    final String imageUrl = _uploadedImageUrl ?? '';
    String finalFoodType  = _foodType;
    if (_foodType == 'Autre' && _autreController.text.isNotEmpty) {
      finalFoodType = _autreController.text.trim();
    }

    // ✅ نستعمل اسم المكان من Nominatim كـ address، أو إحداثيات كـ fallback
    final String addressToSave = _donorPlaceName?.isNotEmpty == true
        ? _donorPlaceName!
        : '${_donorLat!.toStringAsFixed(5)}, ${_donorLng!.toStringAsFixed(5)}';

    final success = await AuthService.addDon(
      donorId:     _donorId,
      donorName:   _donorName,
      title:       finalFoodType,
      description: _descriptionController.text.trim(),
      quantity:    _quantityController.text.trim(),
      imageUrl:    imageUrl,
      address:     addressToSave,
      quartier:    '',
      expiryDate:  _expiryDate!,
      isUrgent:    _isUrgent,
      donorLat:    _donorLat,
      donorLng:    _donorLng,
      // ✅ إصلاح: إرسال بيانات الجمعية عند وجود prefill
      associationId:   _hasPrefill ? _prefill!.associationId : '',
      associationName: _hasPrefill ? _prefill!.associationNom : '',
    );

    if (success && mounted) {
      try {
        final lastDon = await FirebaseFirestore.instance
            .collection('dons')
            .where('donorId', isEqualTo: _donorId)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (lastDon.docs.isNotEmpty) {
          final donId    = lastDon.docs.first.id;
          final donTitle = lastDon.docs.first.data()['title'] ?? _foodType;
          await _notifyAssociations(donId, donTitle);

          if (_hasPrefill) {
            final batch = FirebaseFirestore.instance.batch();
            batch.update(
              FirebaseFirestore.instance
                  .collection('besoins')
                  .doc(_prefill!.besoinId),
              {
                'statut':    'accepte',
                'donId':     donId,
                'accepteAt': FieldValue.serverTimestamp(),
              },
            );
            batch.update(
              FirebaseFirestore.instance.collection('dons').doc(donId),
              {
                'besoinId':        _prefill!.besoinId,
                'associationId':   _prefill!.associationId,
                // ✅ إصلاح: استخدام 'associationName' بدل 'associationNom'
                'associationName': _prefill!.associationNom,
              },
            );
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint("❌ $e");
      }

      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Don publié avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyDonsScreen()),
      );
    } else if (mounted) {
      setState(() => _isSaving = false);
      _showError("Erreur lors de la publication");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _autreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────
          Container(
            color: ZADColors.headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Publier un don',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          if (_hasPrefill)
                            Text(
                              'En réponse à : ${_prefill!.associationNom}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Prefill Banner ───────────────────────────────
          if (_hasPrefill)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ZADColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: ZADColors.primary.withOpacity(0.3), width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism,
                      color: ZADColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Besoin lié : "${_prefill!.typeBesoin}" — ${_prefill!.associationNom}',
                      style: const TextStyle(
                          color: ZADColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Type d'aliment ───────────────────────
                  _SectionTitle(
                      icon: Icons.fastfood_outlined,
                      label: "Type d'aliment"),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableFoodTypes.map((type) {
                      final sel = _foodType == type;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _foodType       = type;
                          _showAutreField = (type == 'Autre');
                          if (type != 'Autre') _autreController.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? ZADColors.primary
                                : ZADColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel
                                    ? ZADColors.primary
                                    : ZADColors.primaryLight),
                          ),
                          child: Text(type,
                              style: TextStyle(
                                  color: sel ? Colors.white : ZADColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_showAutreField) ...[
                    const SizedBox(height: 12),
                    _InputBox(
                      child: TextField(
                        controller: _autreController,
                        decoration: const InputDecoration(
                          hintText: 'Précisez le type...',
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Description ──────────────────────────
                  _SectionTitle(
                      icon: Icons.description_outlined,
                      label: 'Description'),
                  const SizedBox(height: 10),
                  _InputBox(
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez votre don...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Quantité ─────────────────────────────
                  _SectionTitle(
                      icon: Icons.production_quantity_limits,
                      label: 'Quantité'),
                  const SizedBox(height: 10),
                  _InputBox(
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 10 kg, 20 portions...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Date d'expiration ────────────────────
                  _SectionTitle(
                      icon: Icons.calendar_today_outlined,
                      label: "Date d'expiration"),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickExpiryDate,
                    child: _InputBox(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month,
                              color: ZADColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            _expiryDate == null
                                ? 'Choisir une date'
                                : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                            style: TextStyle(
                              color: _expiryDate == null
                                  ? ZADColors.textLight
                                  : ZADColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Urgence ──────────────────────────────
                  _SectionTitle(
                      icon: Icons.priority_high, label: 'Urgence'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _UrgencyChip(
                          label: 'Normal',
                          color: ZADColors.primary,
                          selected: !_isUrgent,
                          onTap: () => setState(() => _isUrgent = false)),
                      const SizedBox(width: 10),
                      _UrgencyChip(
                          label: 'Urgent',
                          color: ZADColors.danger,
                          selected: _isUrgent,
                          onTap: () => setState(() => _isUrgent = true)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Position (خريطة فقط) ─────────────────
                  _SectionTitle(
                      icon: Icons.location_on, label: 'Position du don'),
                  const SizedBox(height: 10),

                  // ✅ زر فتح الخريطة مع Search
                  GestureDetector(
                    onTap: _pickLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _donorLat != null
                            ? const Color(0xFFE8F5E9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _donorLat != null
                              ? ZADColors.primary
                              : ZADColors.divider,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _donorLat != null
                                ? Icons.check_circle
                                : Icons.map_outlined,
                            color: ZADColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _donorLat != null
                                      ? '✅ Position marquée sur la carte'
                                      : '📍 Marquer la position sur la carte',
                                  style: TextStyle(
                                    color: _donorLat != null
                                        ? ZADColors.primary
                                        : ZADColors.textMedium,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                // ✅ يعرض اسم المكان من Nominatim
                                if (_donorPlaceName != null &&
                                    _donorPlaceName!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      _donorPlaceName!,
                                      style: const TextStyle(
                                          color: ZADColors.primary,
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Photo ────────────────────────────────
                  _SectionTitle(
                      icon: Icons.photo_camera_outlined,
                      label: 'Photo (optionnel)'),
                  const SizedBox(height: 10),

                  if (_isUploadingImg)
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: ZADColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: ZADColors.primary),
                            SizedBox(height: 10),
                            Text('Téléchargement en cours...',
                                style: TextStyle(
                                    color: ZADColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  else if (_photoFile != null && _uploadedImageUrl != null)
                    ImagePreviewBox(
                      imageFile: _photoFile!,
                      onRemove: () => setState(() {
                        _photoFile        = null;
                        _uploadedImageUrl = null;
                      }),
                      onReplace: _pickPhoto,
                    )
                  else
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: _InputBox(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: ZADColors.primarySoft),
                              ),
                              child: const Icon(Icons.camera_alt_outlined,
                                  color: ZADColors.primary, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Photo de confirmation',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: ZADColors.textDark,
                                          fontSize: 14)),
                                  Text('Caméra ou galerie · optionnel',
                                      style: TextStyle(
                                          color: ZADColors.textLight,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: ZADColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Ajouter',
                                  style: TextStyle(
                                      color: ZADColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),
                  ZADButton(
                    label: _isSaving ? 'Publication...' : 'Publier le don',
                    icon: Icons.upload_rounded,
                    onTap: () {
                      if (!_isSaving && !_isUploadingImg) _saveDon();
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 2),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────

class _InputBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _InputBox({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: ZADColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ZADColors.textDark)),
        ],
      );
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _UrgencyChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? color : ZADColors.divider,
                  width: selected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: selected ? color : ZADColors.textMedium,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      );
}

class ImagePreviewBox extends StatelessWidget {
  final File imageFile;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  const ImagePreviewBox({
    super.key,
    required this.imageFile,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.file(
              imageFile,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.close,
                  label: 'Supprimer',
                  color: ZADColors.danger,
                  onTap: onRemove,
                ),
                _ActionButton(
                  icon: Icons.refresh,
                  label: 'Changer',
                  color: ZADColors.primary,
                  onTap: onReplace,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}