// lib/donateur/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../main.dart';
import 'profile_screen.dart';
import 'package:a/cloudinary_service.dart';
import '../shared/zad_colors.dart';

class DonateurEditProfileScreen extends StatefulWidget {
  const DonateurEditProfileScreen({super.key});

  @override
  State<DonateurEditProfileScreen> createState() =>
      _DonateurEditProfileScreenState();
}

class _DonateurEditProfileScreenState
    extends State<DonateurEditProfileScreen> {
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  File? _profileImage;
  String _existingPhotoUrl = '';
  String _selectedQuartier = '';
  bool _isSaving = false;
  bool _isLoading = true;
  String _userId = '';
  String _userInitials = '';

  final _picker = ImagePicker();

  final List<String> _quartiers = [
    'Centre-ville',
    'Boudghène',
    'Imama',
    'Kiffan El Ouad',
    'Hay Salam',
    'Plateau',
    'Mansourah',
    'Chetouane',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _userId = user.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _nomController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _existingPhotoUrl = data['photoUrl'] ?? '';

        final savedQuartier = data['quartier'] ?? '';
        if (savedQuartier.isNotEmpty && _quartiers.contains(savedQuartier)) {
          _selectedQuartier = savedQuartier;
        } else {
          _selectedQuartier = '';
        }

        _userInitials = _getInitials(_nomController.text);

        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ Erreur chargement: $e");
      setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
    return 'D';
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: ZADColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Changer la photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: ZADColors.primarySoft,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    const Icon(Icons.camera_alt, color: ZADColors.primary),
              ),
              title: const Text('Caméra'),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 85);
                if (p != null) setState(() => _profileImage = File(p.path));
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: ZADColors.primarySoft,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    const Icon(Icons.photo_library, color: ZADColors.primary),
              ),
              title: const Text('Galerie'),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 85);
                if (p != null) setState(() => _profileImage = File(p.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دالة رفع الصورة المعدلة
  Future<String?> _uploadImage() async {
    if (_profileImage == null) return _existingPhotoUrl.isNotEmpty ? _existingPhotoUrl : null;
    
    try {
      final photoUrl = await CloudinaryService.uploadAuto(_profileImage!);
      
      if (photoUrl == null) {
        throw Exception('Échec du téléchargement de l\'image');
      }
      
      print("✅ Image uploaded to Cloudinary: $photoUrl");
      return photoUrl;
    } catch (e) {
      print("❌ Erreur upload image: $e");
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (_selectedQuartier.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Veuillez sélectionner votre quartier'),
            backgroundColor: ZADColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      String? photoUrl = _existingPhotoUrl;
      if (_profileImage != null) {
        photoUrl = await _uploadImage();
      }

      final updateData = {
        'name': _nomController.text.trim(),
        'phone': _phoneController.text.trim(),
        'quartier': _selectedQuartier,
        'address': _addressController.text.trim(),
      };
      
      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Profil mis à jour avec succès!'),
          backgroundColor: ZADColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: ZADColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      children: [
                        _buildAvatarSection(),
                        const SizedBox(height: 16),
                        _buildInfoSection(),
                        const SizedBox(height: 12),
                        _buildQuartierSection(),
                        const SizedBox(height: 12),
                        _buildAddressSection(),
                        const SizedBox(height: 24),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ZADColors.headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: ZADColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 18,
        left: 18,
        right: 18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Modifier mon profil',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: Center(
        child: GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ZADColors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: ZADColors.primary.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _profileImage != null
                      ? Image.file(_profileImage!, fit: BoxFit.cover)
                      : (_existingPhotoUrl.isNotEmpty
                          ? Image.network(_existingPhotoUrl, fit: BoxFit.cover)
                          : Container(
                              color: ZADColors.primarySoft,
                              child: Center(
                                child: Text(
                                  _userInitials.isEmpty ? "D" : _userInitials,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: ZADColors.primary,
                                  ),
                                ),
                              ),
                            )),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ZADColors.accentYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child:
                      const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const Text('Informations personnelles',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ZADColors.textDark,
              )),
          const SizedBox(height: 14),
          _buildEditField(Icons.person_outline, 'Nom complet', _nomController),
          const SizedBox(height: 10),
          _buildEditField(Icons.email_outlined, 'Email', _emailController,
              keyboardType: TextInputType.emailAddress, enabled: false),
          const SizedBox(height: 10),
          _buildEditField(Icons.phone_outlined, 'Téléphone', _phoneController,
              keyboardType: TextInputType.phone),
        ],
      ),
    );
  }

  Widget _buildQuartierSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const Text('Quartier',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ZADColors.textDark,
              )),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedQuartier.isEmpty ? null : _selectedQuartier,
            hint: const Text('Sélectionnez votre quartier',
                style: TextStyle(color: ZADColors.textLight)),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ZADColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ZADColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: ZADColors.primary, width: 1.5),
              ),
            ),
            items: _quartiers.map((q) {
              return DropdownMenuItem(
                value: q,
                child: Text(q, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedQuartier = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const Text('Adresse complète',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ZADColors.textDark,
              )),
          const SizedBox(height: 12),
          _buildEditField(
              Icons.location_on_outlined, 'Adresse', _addressController),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: ZADColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 6,
          shadowColor: ZADColors.primary.withOpacity(0.4),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('💾 Sauvegarder',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                )),
      ),
    );
  }

  Widget _buildEditField(
    IconData icon,
    String hint,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? ZADColors.primarySoft : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZADColors.divider, width: 1.5),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, color: ZADColors.primary, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintStyle:
                    const TextStyle(color: ZADColors.textLight, fontSize: 12),
              ),
              style: const TextStyle(fontSize: 13, color: ZADColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}