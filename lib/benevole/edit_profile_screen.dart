// lib/screens/benevole/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../auth/auth_service.dart';
import 'profile_screen.dart';
import 'package:a/cloudinary_service.dart';

class BenevoleEditProfileScreen extends StatefulWidget {
  const BenevoleEditProfileScreen({super.key});

  @override
  State<BenevoleEditProfileScreen> createState() =>
      _BenevoleEditProfileScreenState();
}

class _BenevoleEditProfileScreenState
    extends State<BenevoleEditProfileScreen> {
  static const _green     = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenBg   = Color(0xFFF1F8E9);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _divider   = Color(0xFFEEEEEE);
  static const _subText   = Color(0xFF757575);
  static const _textDark  = Color(0xFF1B1B1B);

  final _nomController   = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController   = TextEditingController();

  File?  _profileImage;
  String _selectedTransport = 'Voiture';
  String _selectedQuartier  = 'Centre-ville';
  bool   _isSaving          = false;
  bool   _isLoading         = true;
  String _userId            = '';
  String _userInitials      = '';
  String _existingPhotoUrl  = '';

  final _picker = ImagePicker();

  final List<String> _quartiers = [
    'Centre-ville', 'Boudghène', 'Imama', 'Kiffan El Ouad',
    'Hay Salam', 'Plateau', 'Mansourah', 'Chetouane', 'Autre',
  ];

  final List<String> _transports = ['Voiture', 'Moto', 'Vélo', 'À pied'];

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
        _bioController.text = data['bio'] ?? 'Bénévole chez ZAD';
        _existingPhotoUrl = data['photoUrl'] ?? '';

        final savedTransport = data['transport'] ?? '';
        _selectedTransport = _transports.contains(savedTransport)
            ? savedTransport
            : 'Voiture';

        final savedQuartier = data['quartier'] ?? '';
        _selectedQuartier = _quartiers.contains(savedQuartier)
            ? savedQuartier
            : 'Centre-ville';

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
    return 'B';
  }

  String _getTransportIcon(String transport) {
    switch (transport) {
      case 'Voiture': return '🚗';
      case 'Moto': return '🏍️';
      case 'Vélo': return '🚲';
      case 'À pied': return '🚶';
      default: return '🚗';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Changer la photo',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 16,
                  fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _greenPale,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt, color: _green),
              ),
              title: const Text('Caméra',
                  style: TextStyle(fontFamily: 'Poppins')),
              onTap: () async {
                Navigator.pop(ctx);
                final p = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 85);
                if (p != null) setState(() => _profileImage = File(p.path));
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _greenPale,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library, color: _green),
              ),
              title: const Text('Galerie',
                  style: TextStyle(fontFamily: 'Poppins')),
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

  // ✅ دالة رفع الصورة إلى Cloudinary
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
      // رفع الصورة إذا تم اختيار صورة جديدة
      String? photoUrl = _existingPhotoUrl;
      if (_profileImage != null) {
        photoUrl = await _uploadImage();
      }
      
      final updateData = {
        'name': _nomController.text.trim(),
        'phone': _phoneController.text.trim(),
        'transport': _selectedTransport,
        'quartier': _selectedQuartier,
        'bio': _bioController.text.trim(),
      };
      
      if (photoUrl != null && photoUrl.isNotEmpty) {
        updateData['photoUrl'] = photoUrl;
      }
      
      final success = await AuthService.updateProfile(
        uid: _userId,
        name: _nomController.text.trim(),
        phone: _phoneController.text.trim(),
        transport: _selectedTransport,
        quartier: _selectedQuartier,
        bio: _bioController.text.trim(),
      );
      
      // تحديث photoUrl بشكل منفصل إذا لزم الأمر
      if (photoUrl != null && photoUrl != _existingPhotoUrl) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .update({'photoUrl': photoUrl});
      }
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Profil mis à jour avec succès!'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BenevoleProfileScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Erreur lors de la mise à jour'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFFF9FBF9),
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
                        _buildTransportSection(),
                        const SizedBox(height: 12),
                        _buildQuartierSection(),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x554CAF50), blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 18, left: 18, right: 18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Modifier le profil',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 18,
                  fontWeight: FontWeight.w700, color: Colors.white,
                )),
          ),
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
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _green, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _green.withOpacity(0.2),
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
                              color: _greenPale,
                              child: Center(
                                child: Text(
                                  _userInitials.isEmpty ? "B" : _userInitials,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: _green,
                                  ),
                                ),
                              ),
                            )),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit,
                      color: Colors.white, size: 14),
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
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations personnelles',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13,
                fontWeight: FontWeight.w700, color: _textDark,
              )),
          const SizedBox(height: 14),
          _buildEditField(Icons.person_outline, 'Nom complet', _nomController),
          const SizedBox(height: 10),
          _buildEditField(Icons.email_outlined, 'Email', _emailController,
              keyboardType: TextInputType.emailAddress, enabled: false),
          const SizedBox(height: 10),
          _buildEditField(Icons.phone_outlined, 'Téléphone', _phoneController,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          _buildEditField(Icons.info_outline, 'Bio', _bioController,
              maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildTransportSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Moyen de transport',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13,
                fontWeight: FontWeight.w700, color: _textDark,
              )),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _transports.map((transport) {
              final sel = _selectedTransport == transport;
              return GestureDetector(
                onTap: () => setState(() => _selectedTransport = transport),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _green : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? _green : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getTransportIcon(transport),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        transport,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: sel ? Colors.white : _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
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
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quartier',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13,
                fontWeight: FontWeight.w700, color: _textDark,
              )),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedQuartier,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
            items: _quartiers.map((q) => DropdownMenuItem(
              value: q,
              child: Text(q,
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedQuartier = v!),
          ),
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
          backgroundColor: _green,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 6,
          shadowColor: _green.withOpacity(0.4),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('💾 Sauvegarder',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.white,
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
        color: enabled ? _greenBg : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider, width: 1.5),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, color: _green, size: 18),
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD), fontSize: 12),
              ),
              style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: _textDark),
            ),
          ),
        ],
      ),
    );
  }
}