// lib/association/modifier_profil_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import '../shared/location_picker_screen.dart';
import 'package:a/cloudinary_service.dart';
import 'profil_screen.dart';

class ModifierProfilScreen extends StatefulWidget {
  const ModifierProfilScreen({super.key});

  @override
  State<ModifierProfilScreen> createState() => _ModifierProfilScreenState();
}

class _ModifierProfilScreenState extends State<ModifierProfilScreen> {
  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _phoneController   = TextEditingController();
  final _addressController = TextEditingController();

  bool   _isLoading        = true;
  bool   _isSaving         = false;
  bool   _isUploadingPhoto = false;
  String _userId           = '';

  double? _currentLat;
  double? _currentLng;

  File?   _newProfileImage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _isLoading = false); return; }
      _userId = user.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text    = data['associationName'] ?? data['name'] ?? '';
        _emailController.text   = data['email'] ?? '';
        _phoneController.text   = data['phone'] ?? '';
        _addressController.text = data['quartier'] ?? '';

        _currentLat = (data['associationLat'] as num?)?.toDouble()
            ?? (data['latitude'] as num?)?.toDouble();
        _currentLng = (data['associationLng'] as num?)?.toDouble()
            ?? (data['longitude'] as num?)?.toDouble();

        _profileImageUrl = data['profileImageUrl'] as String?;
      }
    } catch (e) {
      debugPrint("❌ $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1B5E20)),
              title: const Text('Prendre une photo'),
              onTap: () async {
                Navigator.pop(ctx);
                await _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1B5E20)),
              title: const Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.pop(ctx);
                await _getImage(ImageSource.gallery);
              },
            ),
            if (_profileImageUrl != null || _newProfileImage != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer la photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _newProfileImage = null;
                    _profileImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (picked != null) {
      setState(() => _newProfileImage = File(picked.path));
    }
  }

  // رفع الصورة إلى Cloudinary بدل Firebase Storage
  Future<String?> _uploadProfileImage() async {
    if (_newProfileImage == null) return _profileImageUrl;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await CloudinaryService.uploadFile(
        _newProfileImage!,
        resourceType: 'image',
      );
      if (url == null) {
        _showSnack('Erreur lors du téléchargement de la photo', Colors.red);
      }
      return url ?? _profileImageUrl;
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _pickLocation() async {
    // ✅ يستقبل Map {lat, lng, name} من LocationPickerScreen المحدَّث
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: "Position de l'association",
          initialLocation: _currentLat != null
              ? LatLng(_currentLat!, _currentLng!)
              : null,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _currentLat = result['lat'] as double;
        _currentLng = result['lng'] as double;
        // اسم المكان يتحفظ في حقل Adresse تلقائياً
        final name = result['name'] as String? ?? '';
        if (name.isNotEmpty) {
          _addressController.text = name;
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack("Entrez le nom de l'association", Colors.orange);
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnack("Entrez l'adresse", Colors.orange);
      return;
    }
    if (_currentLat == null || _currentLng == null) {
      _showSnack("Veuillez marquer la position sur la carte", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final imageUrl = await _uploadProfileImage();

      await user.updateDisplayName(_nameController.text.trim());
      if (imageUrl != null) {
        await user.updatePhotoURL(imageUrl);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update({
        'associationName':  _nameController.text.trim(),
        'name':             _nameController.text.trim(),
        'phone':            _phoneController.text.trim(),
        'quartier':         _addressController.text.trim(),
        'associationLat':   _currentLat!,
        'associationLng':   _currentLng!,
        'latitude':         _currentLat!,
        'longitude':        _currentLng!,
        'profileImageUrl':  imageUrl ?? FieldValue.delete(),
        'updatedAt':        FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnack('✅ Profil mis à jour !', const Color(0xFF1B5E20));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfilScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ $e');
      _showSnack('Erreur lors de la mise à jour', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Modifier le profil',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B5E20),
                      borderRadius: BorderRadius.only(
                        bottomLeft:  Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            backgroundImage: _newProfileImage != null
                                ? FileImage(_newProfileImage!)
                                    as ImageProvider
                                : (_profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!)
                                    : null),
                            child: (_newProfileImage == null &&
                                    _profileImageUrl == null)
                                ? Text(
                                    _getInitials(_nameController.text),
                                    style: const TextStyle(
                                        fontSize: 30,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: GestureDetector(
                              onTap: _pickProfileImage,
                              child: CircleAvatar(
                                backgroundColor: Colors.orange,
                                radius: 18,
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.camera_alt,
                                        size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildTextField("Nom de l'association",
                            _nameController, Icons.business),
                        const SizedBox(height: 15),
                        _buildTextField("Email", _emailController,
                            Icons.email_outlined,
                            enabled: false),
                        const SizedBox(height: 15),
                        _buildTextField("Téléphone", _phoneController,
                            Icons.phone_android),
                        const SizedBox(height: 15),
                        _buildTextField(
                            "Adresse de l'association",
                            _addressController,
                            Icons.location_on_outlined,
                            maxLines: 2),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: _currentLat != null
                                  ? const Color(0xFFE8F5E9)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _currentLat != null
                                    ? const Color(0xFF1B5E20)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _currentLat != null
                                      ? Icons.check_circle
                                      : Icons.map_outlined,
                                  color: const Color(0xFF1B5E20),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _currentLat != null
                                        ? '✅ Position marquée sur la carte'
                                        : '📍 Marquer la position sur la carte',
                                    style: TextStyle(
                                      color: _currentLat != null
                                          ? const Color(0xFF1B5E20)
                                          : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 14, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15)),
                              elevation: 2,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2),
                                  )
                                : const Text(
                                    "Enregistrer les modifications",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF1B5E20)),
        prefixIcon: Icon(icon, color: const Color(0xFF1B5E20)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide:
              const BorderSide(color: Color(0xFF1B5E20), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
      ),
    );
  }
}