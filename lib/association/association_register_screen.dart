// lib/association/association_register_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../auth/onboarding_screen2.dart';
import '../auth/login_screen.dart';
import '../auth/pending_approval_screen.dart';              // ← إضافة
import 'package:a/cloudinary_service.dart';

class AssociationRegisterScreen extends StatefulWidget {
  const AssociationRegisterScreen({super.key});

  @override
  State<AssociationRegisterScreen> createState() =>
      _AssociationRegisterScreenState();
}

class _AssociationRegisterScreenState
    extends State<AssociationRegisterScreen> {
  static const _green     = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _divider   = Color(0xFFEEEEEE);
  static const _subText   = Color(0xFF757575);
  static const _textDark  = Color(0xFF1B1B1B);

  final _nomAssocController   = TextEditingController();
  final _emailAssocController = TextEditingController();
  final _phoneAssocController = TextEditingController();
  final _adresseController    = TextEditingController();
  final _nomRespController    = TextEditingController();
  final _phoneRespController  = TextEditingController();
  final _emailRespController  = TextEditingController();
  final _passwordController   = TextEditingController();
  final _confirmController    = TextEditingController();

  int    _currentStep   = 1;
  bool   _isLoading     = false;
  bool   _showPassword  = false;
  bool   _showConfirm   = false;
  String _selectedRole  = '';

  File? _profileImage;
  File? _docImage;

  final List<Map<String, String>> _roles = [
    {'icon': '👤', 'name': 'Président'},
    {'icon': '🤝', 'name': 'Vice-président'},
    {'icon': '💼', 'name': 'Secrétaire général'},
    {'icon': '💰', 'name': 'Trésorier'},
    {'icon': '📋', 'name': 'Coordinateur'},
  ];

  @override
  void dispose() {
    _nomAssocController.dispose();
    _emailAssocController.dispose();
    _phoneAssocController.dispose();
    _adresseController.dispose();
    _nomRespController.dispose();
    _phoneRespController.dispose();
    _emailRespController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isProfile}) async {
    if (isProfile) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: _green),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _getImage(ImageSource.camera, isProfile: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: _green),
                title: const Text('Choisir depuis la galerie'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _getImage(ImageSource.gallery, isProfile: true);
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _profileImage = null);
                  },
                ),
            ],
          ),
        ),
      );
    } else {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _docImage = File(picked.path));
      }
    }
  }

  Future<void> _getImage(ImageSource source, {required bool isProfile}) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (picked != null) {
      setState(() {
        if (isProfile) {
          _profileImage = File(picked.path);
        } else {
          _docImage = File(picked.path);
        }
      });
    }
  }

  int _passwordStrength() {
    final p = _passwordController.text;
    if (p.length >= 8 &&
        p.contains(RegExp(r'[A-Z]')) &&
        p.contains(RegExp(r'[0-9]'))) return 2;
    if (p.length >= 6) return 1;
    return 0;
  }

  Color  _strengthColor() =>
      [Colors.red, Colors.orange, Colors.green][_passwordStrength()];
  String _strengthLabel() =>
      ['Faible', 'Moyen', 'Fort'][_passwordStrength()];

  String? _validateCurrentStep() {
    if (_currentStep == 1) {
      if (_nomAssocController.text.trim().isEmpty)
        return 'Entrez le nom de l\'association';
      final email = _emailAssocController.text.trim();
      if (email.isEmpty) return 'Entrez l\'email officiel';
      if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(email))
        return 'Email invalide (ex: contact@assoc.dz)';
      final phone = _phoneAssocController.text.trim();
      if (phone.isEmpty) return 'Entrez le téléphone';
      if (!RegExp(r'^(0|\+213)[0-9]{9}$').hasMatch(phone))
        return 'Téléphone invalide (ex: 0550123456)';
      if (_adresseController.text.trim().length < 5)
        return 'Adresse trop courte';
      if (_docImage == null)
        return 'Ajoutez le document officiel (Agrément)';
    }
    if (_currentStep == 2) {
      if (_nomRespController.text.trim().length < 3)
        return 'Nom du responsable trop court';
      final phone = _phoneRespController.text.trim();
      if (phone.isEmpty) return 'Entrez le téléphone du responsable';
      if (!RegExp(r'^(0|\+213)[0-9]{9}$').hasMatch(phone))
        return 'Téléphone invalide (ex: 0550123456)';
      final email = _emailRespController.text.trim();
      if (email.isEmpty) return 'Entrez l\'email du responsable';
      if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(email))
        return 'Email invalide (ex: nom@gmail.com)';
      if (_selectedRole.isEmpty) return 'Choisissez un rôle';
    }
    if (_currentStep == 3) {
      if (_passwordController.text.isEmpty)
        return 'Entrez un mot de passe';
      if (_passwordController.text.length < 6)
        return 'Mot de passe trop court (6 caractères min)';
      if (_confirmController.text != _passwordController.text)
        return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        email:              _emailRespController.text.trim(),
        password:           _passwordController.text.trim(),
        name:               _nomRespController.text.trim(),
        role:               'association',
        phone:              _phoneRespController.text.trim(),
        associationName:    _nomAssocController.text.trim(),
        registrationNumber: 'DEMANDE_EN_COURS',
        quartier:           _adresseController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await CloudinaryService.uploadFile(
          _profileImage!,
          resourceType: 'image',
        );
        if (profileImageUrl != null) {
          await user.updatePhotoURL(profileImageUrl);
        }
      }

      String? agrementUrl;
      if (_docImage != null) {
        agrementUrl = await CloudinaryService.uploadFile(
          _docImage!,
          resourceType: 'image',
        );
      }

      final now     = DateTime.now();
      final dateStr =
          'Ajouté le ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
        'agrementStatus': 'En attente',
        'agrementDate':   dateStr,
        if (agrementUrl != null) 'agrementUrl': agrementUrl,
        'statutsStatus':  'Manquant',
        'statutsDate':    'Non encore ajouté',
        'nifStatus':      'Manquant',
        'nifDate':        'Non encore ajouté',
      });

      if (mounted) {
        // ← التعديل الوحيد: بدل '/assoc/home' → PendingApprovalScreen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Erreur lors de la création du compte';
        if (e.toString().contains('email-already-in-use'))
          msg = 'Cet email est déjà utilisé';
        else if (e.toString().contains('weak-password'))
          msg = 'Mot de passe trop faible';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: Column(
        children: [
          _buildHeader(),
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _currentStep == 1
                  ? _buildStep1()
                  : _currentStep == 2
                      ? _buildStep2()
                      : _buildStep3(),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16, right: 16, bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_currentStep > 1) {
                setState(() => _currentStep--);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OnboardingScreen2()),
                  (route) => false,
                );
              }
            },
            child: Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                  color: _greenPale, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: _green, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer un compte',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textDark)),
                Text('🏢 Association — Étape $_currentStep/3',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: _subText)),
              ],
            ),
          ),
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
                color: _greenPale, shape: BoxShape.circle),
            child: const Center(
                child: Text('🏢', style: TextStyle(fontSize: 18))),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final labels = ['Infos', 'Responsable', 'Sécurité'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < 3; i++) ...[
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _currentStep >= i + 1 ? _green : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentStep >= i + 1 ? _green : _divider,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: _currentStep > i + 1
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 16)
                        : Text('${i + 1}',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _currentStep == i + 1
                                    ? Colors.white
                                    : _subText)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i],
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: _currentStep == i + 1
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _currentStep == i + 1 ? _green : _subText)),
              ],
            ),
            if (i < 2)
              Container(
                width: 60, height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: _currentStep > i + 1 ? _green : _divider,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🖼️ Photo de profil (optionnelle)'),
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(isProfile: true),
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: _greenPale,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _profileImage != null ? _green : _divider,
                  width: 2.5,
                ),
              ),
              child: _profileImage != null
                  ? ClipOval(
                      child: Image.file(_profileImage!, fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_a_photo, color: _green, size: 28),
                        SizedBox(height: 4),
                        Text('Ajouter',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                color: _green,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Photo optionnelle · Modifiable plus tard',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 10, color: _subText),
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('🏢 Informations de l\'association'),
        _buildTextField(
            controller: _nomAssocController,
            hint: 'Nom de l\'association',
            icon: Icons.business_outlined),
        _buildTextField(
            controller: _emailAssocController,
            hint: 'Email officiel',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        _buildTextField(
            controller: _phoneAssocController,
            hint: 'Téléphone (+213...)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        _buildTextField(
            controller: _adresseController,
            hint: 'Adresse complète',
            icon: Icons.home_outlined),
        const SizedBox(height: 8),
        _sectionLabel('📄 Document officiel (Agrément)'),
        _buildImagePicker(
          isProfile: false,
          image: _docImage,
          label: 'Agrément / Récépissé',
          sublabel: 'JPG/PNG · Obligatoire',
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  color: Color(0xFF7B1FA2), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre compte sera examiné par l\'admin avant activation.\nDélai : 24-48h.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Color(0xFF7B1FA2),
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('👤 Informations du responsable'),
        _buildTextField(
            controller: _nomRespController,
            hint: 'Nom complet du responsable',
            icon: Icons.person_outline),
        _buildTextField(
            controller: _phoneRespController,
            hint: 'Téléphone (+213...)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        _buildTextField(
            controller: _emailRespController,
            hint: 'Email personnel',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 8),
        _sectionLabel('💼 Rôle dans l\'association'),
        ...(_roles.map((role) {
          final isSelected = _selectedRole == role['name'];
          return GestureDetector(
            onTap: () => setState(() => _selectedRole = role['name']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? _greenPale : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isSelected ? _green : _divider, width: 2),
              ),
              child: Row(
                children: [
                  Text(role['icon']!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(role['name']!,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected ? _greenDark : _textDark)),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? _green : Colors.transparent,
                      border: Border.all(
                          color: isSelected ? _green : _divider, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          );
        })),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🔒 Sécurité du compte'),
        _buildPasswordField(),
        const SizedBox(height: 10),
        _buildConfirmPasswordField(),
        const SizedBox(height: 20),
        _sectionLabel('📋 Récapitulatif'),
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10)
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _profileImage != null
                      ? CircleAvatar(
                          radius: 22,
                          backgroundImage: FileImage(_profileImage!),
                        )
                      : Container(
                          width: 44, height: 44,
                          decoration: const BoxDecoration(
                              color: _green, shape: BoxShape.circle),
                          child: const Center(
                              child: Text('🏢',
                                  style: TextStyle(fontSize: 22))),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nomAssocController.text.isEmpty
                              ? 'Votre association'
                              : _nomAssocController.text,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textDark),
                        ),
                        if (_emailAssocController.text.isNotEmpty)
                          Text(_emailAssocController.text,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: _subText)),
                      ],
                    ),
                  ),
                ],
              ),
              if (_nomRespController.text.isNotEmpty) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: _subText, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_nomRespController.text}${_selectedRole.isNotEmpty ? ' · $_selectedRole' : ''}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _subText),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _greenPale,
              borderRadius: BorderRadius.circular(10)),
          child: const Text(
            '🌿 En créant ce compte, vous acceptez les conditions d\'utilisation de ZAD.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: _green,
                height: 1.6),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _green)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider, width: 1.5),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(icon, color: _subText, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD), fontSize: 12),
              ),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider, width: 1.5),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.lock_outline, color: _subText, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Mot de passe',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintStyle: TextStyle(
                    color: Color(0xFFBDBDBD), fontSize: 12),
              ),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility : Icons.visibility_off,
              color: _subText, size: 20,
            ),
            onPressed: () =>
                setState(() => _showPassword = !_showPassword),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider, width: 1.5),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14),
            child: Icon(Icons.lock_outline, color: _subText, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _confirmController,
              obscureText: !_showConfirm,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Confirmer le mot de passe',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                hintStyle: TextStyle(
                    color: Color(0xFFBDBDBD), fontSize: 12),
              ),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(
              _showConfirm ? Icons.visibility : Icons.visibility_off,
              color: _subText, size: 20,
            ),
            onPressed: () =>
                setState(() => _showConfirm = !_showConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker({
    required bool isProfile,
    required File? image,
    required String label,
    required String sublabel,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _pickImage(isProfile: isProfile),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textDark)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: _subText)),
                ],
              ),
            ),
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(image,
                    width: 40, height: 40, fit: BoxFit.cover),
              )
            else
              const Icon(Icons.cloud_upload_outlined,
                  color: _green, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final isLastStep = _currentStep == 3;
    final error      = _validateCurrentStep();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFEF5350), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(error,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFFEF5350))),
                  ),
                ],
              ),
            ),
          ElevatedButton.icon(
            onPressed: (_isLoading || error != null)
                ? null
                : () async {
                    if (_currentStep < 3) {
                      setState(() => _currentStep++);
                    } else {
                      await _handleRegister();
                    }
                  },
            icon: _isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(
                    isLastStep ? Icons.check : Icons.arrow_forward,
                    color: Colors.white),
            label: Text(
              _isLoading
                  ? 'Envoi en cours...'
                  : (isLastStep
                      ? 'Envoyer la demande'
                      : 'Étape suivante'),
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: RichText(
              text: TextSpan(
                text: 'Déjà un compte ? ',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _subText),
                children: [
                  TextSpan(
                    text: 'Se connecter',
                    style: const TextStyle(
                        color: _green, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
