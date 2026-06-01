// ============================================================
// 📄 lib/screens/benevole/register_screen.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dashboard_screen.dart';
import '../../auth/login_screen.dart';
import '../../auth/onboarding_screen2.dart';
import '../../auth/auth_service.dart';
import '../../auth/pending_approval_screen.dart';           // ← إضافة
import 'package:a/cloudinary_service.dart';

class BenevoleRegisterScreen extends StatefulWidget {
  const BenevoleRegisterScreen({super.key});
  @override
  State<BenevoleRegisterScreen> createState() => _BenevoleRegisterScreenState();
}

class _BenevoleRegisterScreenState extends State<BenevoleRegisterScreen> {
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  int _currentStep = 1;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  String _selectedGenre = '';
  String _selectedTransport = '';
  String _selectedQuartier = '';
  DateTime? _selectedDate;

  final List<String> _selectedZones = [];
  final List<String> _selectedDispos = [];

  String? _errNom;
  String? _errEmail;
  String? _errPhone;
  String? _errGenre;
  String? _errDate;
  String? _errQuartier;
  String? _errTransport;
  String? _errZones;
  String? _errDispos;
  String? _errPassword;
  String? _errConfirm;

  File? _profileImage;
  File? _cinImage;
  final _picker = ImagePicker();

  static const _green = Color(0xFF2E7D32);
  static const _greenBg = Color(0xFFF1F8E9);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);
  static const _red = Color(0xFFD32F2F);

  final List<String> _quartiers = [
    'Centre-ville', 'Boudghène', 'Imama', 'Kiffan El Ouad',
    'Hay Salam', 'Plateau', 'Bab El Karmadine', 'Ain El Houtz',
    'Mansourah', 'Chetouane', 'El Kalaa', 'Bouhanak', 'Azail', 'Autre',
  ];

  final List<Map<String, String>> transports = [
    {'icon': '🚶', 'name': 'À pied'},
    {'icon': '🚲', 'name': 'Vélo'},
    {'icon': '🛵', 'name': 'Moto'},
    {'icon': '🚗', 'name': 'Voiture'},
  ];

  final List<String> zones = [
    'Centre-ville', 'Boudghène', 'Imama', 'Mansourah',
    'Chetouane', 'El Kalaa', 'Bouhanak', 'Hay Salam',
  ];

  final List<String> dispos = [
    'Matin', 'Après-midi', 'Soir', 'Weekend', 'Jours fériés', 'Flexible',
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validateStep1() {
    bool ok = true;
    setState(() {
      final nom = _nomController.text.trim();
      if (nom.isEmpty) { _errNom = 'Le nom est obligatoire'; ok = false; }
      else if (nom.length < 3) { _errNom = 'Au moins 3 caractères'; ok = false; }
      else if (RegExp(r'[0-9]').hasMatch(nom)) { _errNom = 'Le nom ne doit pas contenir de chiffres'; ok = false; }
      else { _errNom = null; }

      final email = _emailController.text.trim();
      if (email.isEmpty) { _errEmail = 'L\'email est obligatoire'; ok = false; }
      else if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) { _errEmail = 'Format invalide (ex: nom@gmail.com)'; ok = false; }
      else { _errEmail = null; }

      final phone = _phoneController.text.trim();
      if (phone.isEmpty) { _errPhone = 'Le téléphone est obligatoire'; ok = false; }
      else if (!RegExp(r'^0[567]\d{8}$').hasMatch(phone)) { _errPhone = 'Format invalide (ex: 0661234567)'; ok = false; }
      else { _errPhone = null; }

      if (_selectedDate == null) { _errDate = 'La date de naissance est obligatoire'; ok = false; }
      else { _errDate = null; }

      if (_selectedGenre.isEmpty) { _errGenre = 'Veuillez choisir votre genre'; ok = false; }
      else { _errGenre = null; }

      if (_selectedQuartier.isEmpty) { _errQuartier = 'Veuillez choisir votre quartier'; ok = false; }
      else { _errQuartier = null; }
    });
    return ok;
  }

  bool _validateStep2() {
    bool ok = true;
    setState(() {
      if (_selectedTransport.isEmpty) { _errTransport = 'Veuillez choisir un moyen de transport'; ok = false; }
      else { _errTransport = null; }
      if (_selectedZones.isEmpty) { _errZones = 'Veuillez choisir au moins une zone'; ok = false; }
      else { _errZones = null; }
      if (_selectedDispos.isEmpty) { _errDispos = 'Veuillez choisir au moins une disponibilité'; ok = false; }
      else { _errDispos = null; }
    });
    return ok;
  }

  bool _validateStep3() {
    bool ok = true;
    setState(() {
      final pass = _passwordController.text;
      if (pass.isEmpty) { _errPassword = 'Le mot de passe est obligatoire'; ok = false; }
      else if (pass.length < 8) { _errPassword = 'Au moins 8 caractères'; ok = false; }
      else { _errPassword = null; }

      final confirm = _confirmController.text;
      if (confirm.isEmpty) { _errConfirm = 'Veuillez confirmer le mot de passe'; ok = false; }
      else if (confirm != pass) { _errConfirm = 'Les mots de passe ne correspondent pas'; ok = false; }
      else { _errConfirm = null; }
    });
    return ok;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 16),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _green, onPrimary: Colors.white, onSurface: _textDark),
          textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _green)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() { _selectedDate = picked; _errDate = null; });
  }

  Future<void> _pickLocation() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: _divider, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Icon(Icons.location_on, color: _green, size: 22),
                SizedBox(width: 8),
                Text('Choisir votre quartier',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
              ]),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _quartiers.length,
                itemBuilder: (_, i) {
                  final q = _quartiers[i];
                  final sel = _selectedQuartier == q;
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: sel ? _greenPale : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle),
                      child: Icon(Icons.place_outlined,
                          color: sel ? _green : _subText, size: 18),
                    ),
                    title: Text(q,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel ? _green : _textDark)),
                    trailing: sel
                        ? const Icon(Icons.check_circle, color: _green, size: 20)
                        : null,
                    onTap: () {
                      setState(() { _selectedQuartier = q; _errQuartier = null; });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool isProfile}) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(isProfile ? 'Photo de profil' : 'Carte d\'identité',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt, color: _green),
              ),
              title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (picked != null) {
                  final file = File(picked.path);
                  final imageUrl = await CloudinaryService.uploadAuto(file);
                  if (imageUrl != null) {
                    setState(() { if (isProfile) { _profileImage = file; } else { _cinImage = file; } });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${isProfile ? "Photo" : "CIN"} téléchargée avec succès'),
                        backgroundColor: _green,
                      ));
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ Échec du téléchargement'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library, color: _green),
              ),
              title: const Text('Choisir depuis la galerie', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) {
                  final file = File(picked.path);
                  final imageUrl = await CloudinaryService.uploadAuto(file);
                  if (imageUrl != null) {
                    setState(() { if (isProfile) { _profileImage = file; } else { _cinImage = file; } });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${isProfile ? "Photo" : "CIN"} téléchargée avec succès'),
                        backgroundColor: _green,
                      ));
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ Échec du téléchargement'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  int _passwordStrength() {
    final p = _passwordController.text;
    if (p.length < 4) return 0;
    if (p.length < 8) return 1;
    return 2;
  }

  String _passwordStrengthLabel() {
    switch (_passwordStrength()) {
      case 1: return 'Faible';
      case 2: return 'Fort ✓';
      default: return '';
    }
  }

  Color _passwordStrengthColor() {
    switch (_passwordStrength()) {
      case 1: return _red;
      case 2: return _green;
      default: return _divider;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _greenBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildStepIndicator(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _currentStep == 1
                      ? _buildStep1()
                      : _currentStep == 2 ? _buildStep2() : _buildStep3(),
                ),
              ),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _greenBg,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 16, right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_currentStep > 1) {
                setState(() => _currentStep--);
              } else {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen2()),
                    (route) => false);
              }
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
              ),
              child: const Icon(Icons.arrow_back, color: _green, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Créer un compte',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _green)),
                Text('🤝 Bénévole — Étape $_currentStep/3',
                    style: const TextStyle(fontSize: 11, color: _subText)),
              ],
            ),
          ),
          const Text('🌿', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: _greenBg,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          Row(children: [
            _stepCircle(1), _stepLine(1), _stepCircle(2), _stepLine(2), _stepCircle(3),
          ]),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_stepLabel('Infos', 1), _stepLabel('Transport', 2), _stepLabel('Sécurité', 3)],
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(int step) {
    final isDone = _currentStep > step;
    final isActive = _currentStep == step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: isDone || isActive ? _green : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isDone || isActive ? _green : _divider, width: 2),
        boxShadow: isActive ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 10)] : [],
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : Text('$step', style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFBDBDBD),
                fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _stepLine(int step) => Expanded(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 2.5,
      decoration: BoxDecoration(
          color: _currentStep > step ? _green : _divider,
          borderRadius: BorderRadius.circular(2)),
    ),
  );

  Widget _stepLabel(String label, int step) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    return Text(label, style: TextStyle(
        fontSize: 10,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        color: isActive || isDone ? _green : const Color(0xFFBDBDBD)));
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('👤 Informations personnelles'),
        _buildField(Icons.person_outline, 'Nom complet *', _nomController,
            errorText: _errNom, onChanged: (_) => setState(() => _errNom = null)),
        _buildField(Icons.email_outlined, 'Adresse email *', _emailController,
            keyboardType: TextInputType.emailAddress,
            errorText: _errEmail, onChanged: (_) => setState(() => _errEmail = null)),
        _buildField(Icons.phone_outlined, 'Téléphone (06XXXXXXXX) *', _phoneController,
            keyboardType: TextInputType.phone,
            errorText: _errPhone, onChanged: (_) => setState(() => _errPhone = null)),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _errDate != null ? _red : (_selectedDate != null ? _green : _divider),
                  width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: _errDate != null ? _red : (_selectedDate != null ? _green : _subText),
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null ? _formatDate(_selectedDate!) : 'Date de naissance *',
                    style: TextStyle(
                        fontSize: 13,
                        color: _selectedDate != null ? _textDark : const Color(0xFFBDBDBD)),
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: _selectedDate != null ? _green : _subText, size: 22),
              ],
            ),
          ),
        ),
        if (_errDate != null) _errorText(_errDate!),
        const SizedBox(height: 10),
        _sectionLabel('⚥ Genre *'),
        Row(
          children: ['Homme', 'Femme'].map((g) {
            final sel = _selectedGenre == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() { _selectedGenre = g; _errGenre = null; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? _greenPale : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _errGenre != null ? _red : (sel ? _green : _divider), width: 1.5),
                  ),
                  child: Center(
                    child: Text(g, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? _green : _subText)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_errGenre != null) _errorText(_errGenre!),
        const SizedBox(height: 10),
        _sectionLabel('📍 Quartier *'),
        GestureDetector(
          onTap: _pickLocation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _errQuartier != null ? _red : (_selectedQuartier.isNotEmpty ? _green : _divider),
                  width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: _errQuartier != null ? _red : (_selectedQuartier.isNotEmpty ? _green : _subText),
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedQuartier.isNotEmpty ? _selectedQuartier : 'Choisir votre quartier · Tlemcen *',
                    style: TextStyle(
                        fontSize: 13,
                        color: _selectedQuartier.isNotEmpty ? _textDark : const Color(0xFFBDBDBD)),
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: _selectedQuartier.isNotEmpty ? _green : _subText, size: 22),
              ],
            ),
          ),
        ),
        if (_errQuartier != null) _errorText(_errQuartier!),
        const SizedBox(height: 10),
        _sectionLabel('🤳 Photo de profil (optionnelle)'),
        GestureDetector(
          onTap: () => _pickImage(isProfile: true),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _profileImage != null ? _greenPale : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green, width: 1.5),
            ),
            child: Row(
              children: [
                _profileImage != null
                    ? ClipOval(child: Image.file(_profileImage!, width: 50, height: 50, fit: BoxFit.cover))
                    : Container(
                        width: 50, height: 50,
                        decoration: const BoxDecoration(color: _greenPale, shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: _green, size: 28),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profileImage != null ? 'Photo ajoutée ✅' : 'Ajouter une photo',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: _profileImage != null ? _green : _textDark),
                      ),
                      const Text('Optionnel · JPG/PNG',
                          style: TextStyle(fontSize: 10, color: _subText)),
                    ],
                  ),
                ),
                const Icon(Icons.camera_alt_outlined, color: _green, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🚗 Moyen de transport *'),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.4,
          children: transports.map((t) {
            final sel = _selectedTransport == t['name'];
            return GestureDetector(
              onTap: () => setState(() { _selectedTransport = t['name']!; _errTransport = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? _greenPale : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _errTransport != null ? _red : (sel ? _green : _divider),
                      width: sel ? 2 : 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t['icon']!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(t['name']!, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? _green : _subText)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_errTransport != null) ...[const SizedBox(height: 4), _errorText(_errTransport!)],
        const SizedBox(height: 16),
        _sectionLabel('📍 Zones de livraison *'),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: zones.map((z) {
            final sel = _selectedZones.contains(z);
            return GestureDetector(
              onTap: () => setState(() {
                sel ? _selectedZones.remove(z) : _selectedZones.add(z);
                _errZones = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _greenPale : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _errZones != null ? _red : (sel ? _green : _divider), width: 1.5),
                ),
                child: Text(z, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: sel ? _green : _subText)),
              ),
            );
          }).toList(),
        ),
        if (_errZones != null) ...[const SizedBox(height: 4), _errorText(_errZones!)],
        const SizedBox(height: 16),
        _sectionLabel('🕐 Disponibilités *'),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 3.2,
          children: dispos.map((d) {
            final sel = _selectedDispos.contains(d);
            return GestureDetector(
              onTap: () => setState(() {
                sel ? _selectedDispos.remove(d) : _selectedDispos.add(d);
                _errDispos = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? _greenPale : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _errDispos != null ? _red : (sel ? _green : _divider), width: 1.5),
                ),
                child: Center(
                  child: Text(d, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: sel ? _green : _subText)),
                ),
              ),
            );
          }).toList(),
        ),
        if (_errDispos != null) ...[const SizedBox(height: 4), _errorText(_errDispos!)],
        const SizedBox(height: 16),
        _sectionLabel('🪪 Carte d\'identité nationale (optionnelle)'),
        GestureDetector(
          onTap: () => _pickImage(isProfile: false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cinImage != null ? _greenPale : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green, width: 1.5),
            ),
            child: Row(
              children: [
                _cinImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_cinImage!, width: 64, height: 44, fit: BoxFit.cover))
                    : Container(
                        width: 64, height: 44,
                        decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.credit_card, color: _green, size: 28),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cinImage != null ? 'CIN ajoutée ✅' : 'Ajouter votre CIN',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: _cinImage != null ? _green : _textDark),
                      ),
                      Text(
                        _cinImage != null ? 'Appuyer pour changer' : 'Optionnel · Recto · JPG/PDF',
                        style: const TextStyle(fontSize: 10, color: _subText),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.camera_alt_outlined, color: _green, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🔒 Sécurité du compte'),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _errPassword != null ? _red : _divider, width: 1.5),
          ),
          child: Row(
            children: [
              const Padding(padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.lock_outline, color: _subText, size: 20)),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  onChanged: (_) => setState(() => _errPassword = null),
                  decoration: const InputDecoration(
                    hintText: 'Mot de passe * (min. 8 caractères)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              IconButton(
                icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off,
                    color: _subText, size: 20),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ],
          ),
        ),
        if (_errPassword != null) _errorText(_errPassword!),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 5),
          Row(
            children: List.generate(3, (i) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 4), height: 4,
                decoration: BoxDecoration(
                    color: i < _passwordStrength() + 1 ? _passwordStrengthColor() : _divider,
                    borderRadius: BorderRadius.circular(3)),
              ),
            )),
          ),
          const SizedBox(height: 4),
          Text(_passwordStrengthLabel(), style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: _passwordStrengthColor())),
        ],
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _errConfirm != null
                    ? _red
                    : (_confirmController.text.isNotEmpty &&
                              _confirmController.text == _passwordController.text
                          ? _green : _divider),
                width: 1.5),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Icon(Icons.lock_outline,
                    color: _errConfirm != null
                        ? _red
                        : (_confirmController.text.isNotEmpty &&
                                  _confirmController.text == _passwordController.text
                              ? _green : _subText),
                    size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _confirmController,
                  obscureText: !_showConfirm,
                  onChanged: (_) => setState(() => _errConfirm = null),
                  decoration: const InputDecoration(
                    hintText: 'Confirmer le mot de passe *',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              IconButton(
                icon: Icon(_showConfirm ? Icons.visibility : Icons.visibility_off,
                    color: _subText, size: 20),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ],
          ),
        ),
        if (_errConfirm != null) _errorText(_errConfirm!),
        if (_errConfirm == null && _confirmController.text.isNotEmpty &&
            _confirmController.text == _passwordController.text)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 4),
            child: Text('✅ Mots de passe identiques',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _green)),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── BOTTOM BUTTON — التعديل الوحيد هنا ───────────────────
  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                bool ok = false;
                if (_currentStep == 1) ok = _validateStep1();
                else if (_currentStep == 2) ok = _validateStep2();
                else ok = _validateStep3();

                if (ok) {
                  if (_currentStep < 3) {
                    setState(() => _currentStep++);
                  } else {
                    setState(() => _isLoading = true);
                    try {
                      await AuthService.register(
                        email: _emailController.text.trim(),
                        password: _passwordController.text,
                        name: _nomController.text.trim(),
                        phone: _phoneController.text.trim(),
                        role: 'benevole',
                      );
                      if (mounted) {
                        // ← التعديل الوحيد: بدل '/ben/dashboard' → PendingApprovalScreen
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PendingApprovalScreen()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 6, shadowColor: _green.withOpacity(0.4),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep < 3 ? 'Étape suivante' : '✅ Créer mon compte',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        if (_currentStep < 3) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: RichText(
              text: const TextSpan(
                text: 'Déjà un compte ? ',
                style: TextStyle(fontSize: 12, color: _subText),
                children: [
                  TextSpan(
                    text: 'Se connecter',
                    style: TextStyle(
                        color: _green, fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline, decorationColor: _green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorText(String msg) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 8, left: 4),
    child: Row(children: [
      const Icon(Icons.error_outline, color: _red, size: 12),
      const SizedBox(width: 4),
      Text(msg, style: const TextStyle(fontSize: 10, color: _red, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _green)),
      const SizedBox(width: 8),
      const Expanded(child: Divider(color: Color(0xFFE8F5E9), thickness: 1.5)),
    ]),
  );

  Widget _buildField(IconData icon, String hint, TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: errorText != null ? _red : _divider, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
          ),
          child: Row(
            children: [
              Padding(padding: const EdgeInsets.only(left: 14),
                  child: Icon(icon, color: errorText != null ? _red : _subText, size: 20)),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hint, border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 13, color: _textDark),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) _errorText(errorText),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
  );
}
