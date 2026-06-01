import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/pending_approval_screen.dart';              // ← إضافة

class RegisterStep2Screen extends StatefulWidget {
  final String nom;
  final String email;
  final String phone;
  final String quartier;
  final String genre;
  final String donorType;
  final DateTime birthDate;

  const RegisterStep2Screen({
    super.key,
    required this.nom,
    required this.email,
    required this.phone,
    required this.quartier,
    required this.genre,
    required this.donorType,
    required this.birthDate,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String? _passwordError;
  String? _confirmError;

  static const _green = Color(0xFF2E7D32);
  static const _greenBg = Color(0xFFF1F8E9);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-çèéàù]'));
    bool hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    return hasNumber && hasSpecialChar && hasUpperCase;
  }

  String _getPasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) return '';
    if (password.length < 8) return 'Faible - Minimum 8 caractères';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Moyen - Ajoutez un chiffre';
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-çèéàù]'))) return 'Moyen - Ajoutez un symbole (!@#...)';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Bon - Ajoutez une majuscule';
    return 'Fort ✓';
  }

  Color _getPasswordStrengthColor() {
    final strength = _getPasswordStrength();
    if (strength.startsWith('Faible')) return Colors.red;
    if (strength.startsWith('Moyen')) return Colors.orange;
    if (strength.startsWith('Bon')) return Colors.blue;
    if (strength == 'Fort ✓') return _green;
    return _divider;
  }

  double _getPasswordStrengthProgress() {
    final password = _passwordController.text;
    if (password.isEmpty) return 0;
    if (password.length < 8) return 0.25;
    if (!password.contains(RegExp(r'[0-9]'))) return 0.5;
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-çèéàù]'))) return 0.5;
    if (!password.contains(RegExp(r'[A-Z]'))) return 0.75;
    return 1.0;
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = null;
      } else if (value.length < 8) {
        _passwordError = 'Le mot de passe doit contenir au moins 8 caractères';
      } else if (!value.contains(RegExp(r'[0-9]'))) {
        _passwordError = 'Le mot de passe doit contenir au moins un chiffre';
      } else if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-çèéàù]'))) {
        _passwordError = 'Le mot de passe doit contenir au moins un symbole (!@#...etc)';
      } else {
        _passwordError = null;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _confirmError = null;
      } else if (_passwordController.text != value) {
        _confirmError = 'Les mots de passe ne correspondent pas';
      } else {
        _confirmError = null;
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
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
                  child: _buildStep2(),
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
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
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
                Text('Créer un compte',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _green)),
                Text('🔒 Donateur — Étape 2/2',
                  style: TextStyle(fontSize: 11, color: _subText)),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, color: _green, size: 28),
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
              _stepCircle(1, isCompleted: true),
              Expanded(child: _stepLine(isCompleted: true)),
              _stepCircle(2, isActive: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepLabel('Infos', isCompleted: true),
              _stepLabel('Sécurité', isActive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(int step, {bool isActive = false, bool isCompleted = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: isCompleted ? _green : (isActive ? _green : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: (isCompleted || isActive) ? _green : _divider,
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : Text('$step', style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFFBDBDBD),
              fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _stepLine({bool isCompleted = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 2.5,
      decoration: BoxDecoration(
        color: isCompleted ? _green : _divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _stepLabel(String label, {bool isActive = false, bool isCompleted = false}) {
    return Text(label, style: TextStyle(
      fontSize: 10,
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      color: (isActive || isCompleted) ? _green : const Color(0xFFBDBDBD),
    ));
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(label, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _passwordError != null ? Colors.red : _divider,
              width: 1.5,
            ),
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
                  onChanged: (value) {
                    _validatePassword(value);
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    hintText: 'Mot de passe (minimum 8 caractères)',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                  color: _subText, size: 20,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ],
          ),
        ),
        if (_passwordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _getPasswordStrengthProgress(),
              backgroundColor: _divider,
              color: _getPasswordStrengthColor(),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_getPasswordStrength(), style: TextStyle(
                fontSize: 11,
                color: _getPasswordStrengthColor(),
                fontWeight: FontWeight.w600,
              )),
              Text('8 caractères min', style: TextStyle(
                fontSize: 10,
                color: _passwordController.text.length >= 8 ? _green : Colors.grey,
              )),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _greenPale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Le mot de passe doit contenir :',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(
                    _passwordController.text.length >= 8
                      ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: _passwordController.text.length >= 8 ? _green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  const Text('Au moins 8 caractères', style: TextStyle(fontSize: 10)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                    _passwordController.text.contains(RegExp(r'[0-9]'))
                      ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: _passwordController.text.contains(RegExp(r'[0-9]'))
                      ? _green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  const Text('Au moins 1 chiffre', style: TextStyle(fontSize: 10)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                    _passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-çèéàù]'))
                      ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: _passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-çèéàù]'))
                      ? _green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  const Text('Au moins 1 symbole (!@#_-çè...etc)', style: TextStyle(fontSize: 10)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(
                    _passwordController.text.contains(RegExp(r'[A-Z]'))
                      ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: _passwordController.text.contains(RegExp(r'[A-Z]'))
                      ? _green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  const Text('Au moins 1 lettre majuscule (optionnel)',
                    style: TextStyle(fontSize: 10)),
                ]),
              ],
            ),
          ),
        ],
        if (_passwordError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Text(_passwordError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
            ]),
          ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _confirmError != null ? Colors.red : _divider,
              width: 1.5,
            ),
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
                  obscureText: !_showConfirmPassword,
                  onChanged: _validateConfirmPassword,
                  decoration: const InputDecoration(
                    hintText: 'Confirmer le mot de passe',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  color: _subText, size: 20,
                ),
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
            ],
          ),
        ),
        if (_confirmError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Text(_confirmError!, style: const TextStyle(color: Colors.red, fontSize: 11)),
            ]),
          ),
      ],
    );
  }

  bool _isStep2Valid() {
    if (_passwordController.text.isEmpty) return false;
    if (_confirmController.text.isEmpty) return false;
    if (_passwordError != null) return false;
    if (_confirmError != null) return false;
    if (_passwordController.text != _confirmController.text) return false;
    if (!_isValidPassword(_passwordController.text)) return false;
    return true;
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('🔒 Sécurité du compte'),
        _buildPasswordField(),
        const SizedBox(height: 16),
        _buildConfirmPasswordField(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _greenPale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              text: 'En créant un compte, vous acceptez nos ',
              style: TextStyle(color: _subText, fontSize: 12),
              children: [
                TextSpan(
                  text: "conditions d'utilisation",
                  style: TextStyle(color: _green, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: ' et vous engagez à respecter la charte du bénévole ZAD.',
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
            onTap: () async {
              if (_isStep2Valid()) {
                setState(() => _isLoading = true);
                try {
                  await AuthService.register(
                    email: widget.email,
                    password: _passwordController.text.trim(),
                    name: widget.nom,
                    role: 'donateur',
                    phone: widget.phone,
                    donorType: widget.donorType,
                    quartier: widget.quartier,
                    genre: widget.genre,
                    birthDate: widget.birthDate,
                  );
                  if (mounted) {
                    // ← التعديل الوحيد: بدل '/don/home' → PendingApprovalScreen
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PendingApprovalScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    String msg = 'Erreur lors de la création du compte';
                    if (e.toString().contains('email-already-in-use')) {
                      msg = 'Cet email est déjà utilisé';
                    } else if (e.toString().contains('weak-password')) {
                      msg = 'Mot de passe trop faible';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              } else {
                String message = '';
                if (_passwordController.text.isEmpty) {
                  message = 'Veuillez entrer un mot de passe';
                } else if (_passwordError != null) {
                  message = _passwordError!;
                } else if (_confirmController.text.isEmpty) {
                  message = 'Veuillez confirmer votre mot de passe';
                } else if (_confirmError != null) {
                  message = _confirmError!;
                } else if (_passwordController.text != _confirmController.text) {
                  message = 'Les mots de passe ne correspondent pas';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
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
              child: Center(
                child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('Créer mon compte',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
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
