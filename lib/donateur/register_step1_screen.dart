import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../auth/onboarding_screen2.dart';
import '../../auth/login_screen.dart';
import 'register_step2_screen.dart';
import 'package:a/cloudinary_service.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  String? _selectedDonorType;
  bool _showTypeDropdown = false;
  String? _pdfFileName;
  PlatformFile? _pdfFile;
  String _selectedQuartier = '';
  String _selectedGenre = '';
  DateTime? _selectedDate;

  final TextEditingController _autreQuartierController =
      TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _emailError;
  String? _phoneError;

  static const _green = Color(0xFF2E7D32);
  static const _greenBg = Color(0xFFF1F8E9);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  final List<String> _quartiers = [
    'Centre-ville',
    'Boudghène',
    'Imama',
    'Kiffan El Ouad',
    'Hay Salam',
    'Plateau',
    'Bab El Karmadine',
    'Ain El Houtz',
    'Mansourah',
    'Chetouane',
    'El Kalaa',
    'Bouhanak',
    'Azail',
    'Maghnia',
    'Remchi',
    'Hennaya',
    'Nedroma',
    'Sebdou',
    'Oulad Mimoun',
    'Beni Saf',
    'Ghazaouet',
    'Beni Mester',
    'Terny',
    'Abou Tachfine',
    'Ain Defla',
    'Saf Saf',
    'Autre',
  ];

  final List<String> _donorTypes = [
    'Restaurant',
    'Commerce de produits alimentaires',
    'Boulangerie',
  ];

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool _isValidAlgerianPhone(String phone) {
    String cleaned = phone.replaceAll(' ', '');
    final phoneRegex = RegExp(r'^(0[567]\d{8})|(\+213[567]\d{8})$');
    return phoneRegex.hasMatch(cleaned);
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = null;
      } else if (!_isValidEmail(value)) {
        _emailError = 'Email invalide (exemple: nom@domaine.com)';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePhone(String value) {
    setState(() {
      if (value.isEmpty) {
        _phoneError = null;
      } else if (!_isValidAlgerianPhone(value)) {
        _phoneError = 'Numéro invalide (ex: 0555123456 ou +213555123456)';
      } else {
        _phoneError = null;
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textDark,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _getFormattedDate() {
    if (_selectedDate == null) return '';
    return '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      
      if (result != null) {
        final file = File(result.files.single.path!);
        
        // ✅ استخدام uploadAuto لرفع PDF إلى Cloudinary
        final pdfUrl = await CloudinaryService.uploadAuto(file);
        
        if (pdfUrl != null) {
          setState(() {
            _pdfFile = result.files.single;
            _pdfFileName = result.files.single.name;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ PDF téléchargé: $_pdfFileName'),
              backgroundColor: _green,
            ),
          );
        } else {
          throw Exception('Échec du téléchargement du PDF');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickQuartier() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: _green, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Choisir votre quartier',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sel ? _greenPale : const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.place_outlined,
                        color: sel ? _green : _subText,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      q,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? _green : _textDark,
                      ),
                    ),
                    trailing: sel
                        ? Icon(Icons.check_circle, color: _green, size: 20)
                        : null,
                    onTap: () {
                      setState(() => _selectedQuartier = q);
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

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _autreQuartierController.dispose();
    super.dispose();
  }

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
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildStep1(),
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
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen2()),
                (route) => false,
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: _green, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Créer un compte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
                Text(
                  '🌱 Donateur — Étape 1/2',
                  style: TextStyle(fontSize: 11, color: _subText),
                ),
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
          Row(
            children: [
              _stepCircle(1, isActive: true),
              Expanded(child: _stepLine(isActive: true)),
              _stepCircle(2, isActive: false),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepLabel('Infos', isActive: true),
              _stepLabel('Sécurité', isActive: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(int step, {required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isActive ? _green : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isActive ? _green : _divider, width: 2),
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFFBDBDBD),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _stepLine({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 2.5,
      decoration: BoxDecoration(
        color: isActive ? _green : _divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _stepLabel(String label, {required bool isActive}) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        color: isActive ? _green : const Color(0xFFBDBDBD),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _emailError != null ? Colors.red : _divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: _green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _validateEmail,
                  style: const TextStyle(color: _textDark, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'exemple@email.com',
                    hintStyle: TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_emailError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Text(
                  _emailError!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _phoneError != null ? Colors.red : _divider,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  color: _green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '+213',
                  style: TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: _validatePhone,
                  style: const TextStyle(color: _textDark, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '5 55 12 34 56',
                    hintStyle: TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Text(
                  _phoneError!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _greenPale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: _green,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _getFormattedDate().isEmpty
                      ? 'JJ/MM/AAAA'
                      : _getFormattedDate(),
                  style: TextStyle(
                    color: _getFormattedDate().isEmpty
                        ? const Color(0xFFBDBDBD)
                        : _textDark,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: _green, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    IconData icon,
    String hint,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _greenPale,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _green, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(color: _textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFBDBDBD),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isStep1Valid() {
    if (_nomController.text.trim().isEmpty) return false;
    if (_emailController.text.trim().isEmpty) return false;
    if (_emailError != null) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    if (_phoneError != null) return false;
    if (_selectedDate == null) return false;
    if (_selectedGenre.isEmpty) return false;
    if (_selectedQuartier.isEmpty) return false;
    if (_selectedDonorType == null) return false;
    return true;
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('👤 Informations personnelles'),
        _buildField(Icons.person_outline, 'Nom complet', _nomController),
        _buildEmailField(),
        _buildPhoneField(),
        _buildDateField(),
        _sectionLabel('⚥ Genre'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGenre = 'Homme'),
                child: Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedGenre == 'Homme'
                        ? _greenPale
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedGenre == 'Homme' ? _green : _divider,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Homme',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedGenre == 'Homme' ? _green : _subText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGenre = 'Femme'),
                child: Container(
                  margin: const EdgeInsets.only(left: 8, bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedGenre == 'Femme'
                        ? _greenPale
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedGenre == 'Femme' ? _green : _divider,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Femme',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedGenre == 'Femme' ? _green : _subText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        _sectionLabel('📍 Quartier'),
        GestureDetector(
          onTap: _pickQuartier,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedQuartier.isNotEmpty ? _green : _divider,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _greenPale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: _selectedQuartier.isNotEmpty ? _green : _subText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedQuartier.isNotEmpty
                        ? _selectedQuartier
                        : 'Choisir votre quartier · Tlemcen',
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedQuartier.isNotEmpty
                          ? _textDark
                          : const Color(0xFFBDBDBD),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: _selectedQuartier.isNotEmpty ? _green : _subText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (_selectedQuartier == 'Autre')
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildField(
              Icons.edit_location_alt_outlined,
              'Précisez votre ville/quartier',
              _autreQuartierController,
            ),
          ),
        _sectionLabel('🏪 Type de donateur'),
        GestureDetector(
          onTap: () => setState(() => _showTypeDropdown = !_showTypeDropdown),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showTypeDropdown ? _green : _divider,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _greenPale,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: _green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDonorType ?? 'Sélectionner le type',
                    style: TextStyle(
                      color: _selectedDonorType != null
                          ? _textDark
                          : const Color(0xFFBDBDBD),
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _showTypeDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: _green,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        if (_showTypeDropdown)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _donorTypes.map((type) {
                final isSelected = _selectedDonorType == type;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDonorType = type;
                    _showTypeDropdown = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _greenPale : Colors.white,
                      border: Border(
                        bottom: BorderSide(color: _divider, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? _green : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? _green : _divider,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? _green : _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        _sectionLabel("📄 Justificatif d'agrément"),
        GestureDetector(
          onTap: _pickPdfFile,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _pdfFile != null ? _greenPale : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _pdfFile != null ? _green : _divider,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _pdfFile != null ? _green : _greenPale,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _pdfFile != null ? Icons.cloud_done : Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pdfFile != null
                            ? _pdfFileName!
                            : 'Ajouter un fichier PDF',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _pdfFile != null ? _green : _textDark,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _pdfFile != null
                            ? '✅ Téléchargé sur Cloudinary'
                            : 'PDF uniquement · max 10 MB',
                        style: const TextStyle(color: _subText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (_pdfFile == null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _greenPale,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Parcourir',
                      style: TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => setState(() {
                      _pdfFile = null;
                      _pdfFileName = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (_isStep1Valid()) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterStep2Screen(
                      nom: _nomController.text.trim(),
                      email: _emailController.text.trim(),
                      phone: _phoneController.text.trim(),
                      quartier: _selectedQuartier == 'Autre'
                          ? _autreQuartierController.text.trim()
                          : _selectedQuartier,
                      genre: _selectedGenre,
                      donorType: _selectedDonorType!,
                      birthDate: _selectedDate!,
                    ),
                  ),
                );
              } else {
                String message = '';
                if (_nomController.text.trim().isEmpty)
                  message = 'Veuillez entrer votre nom complet';
                else if (_emailController.text.trim().isEmpty)
                  message = 'Veuillez entrer votre adresse email';
                else if (_emailError != null)
                  message = _emailError!;
                else if (_phoneController.text.trim().isEmpty)
                  message = 'Veuillez entrer votre numéro de téléphone';
                else if (_phoneError != null)
                  message = _phoneError!;
                else if (_selectedDate == null)
                  message = 'Veuillez sélectionner votre date de naissance';
                else if (_selectedGenre.isEmpty)
                  message = 'Veuillez sélectionner votre genre';
                else if (_selectedQuartier.isEmpty)
                  message = 'Veuillez sélectionner votre quartier';
                else if (_selectedDonorType == null)
                  message = 'Veuillez sélectionner le type de donateur';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Suivant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      const TextSpan(
                        text: 'Déjà un compte ? ',
                        style: TextStyle(color: _subText),
                      ),
                      TextSpan(
                        text: 'Se connecter',
                        style: TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}