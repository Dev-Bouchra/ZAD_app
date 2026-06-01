// lib/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import 'onboarding_screen2.dart';
import 'forgot_password_screen.dart';
import '../auth/auth_service.dart';
import '../shared/zad_colors.dart';
import '../notification_service.dart';
import 'pending_approval_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _usePhoneLogin = false;
  final _phoneController = TextEditingController();

  void _handleLogin() async {
    String emailOrPhone = _usePhoneLogin
        ? _phoneController.text.trim()
        : _emailController.text.trim();

    if (emailOrPhone.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String email;

      if (_usePhoneLogin) {
        final userData = await AuthService.getUserByPhone(emailOrPhone);
        if (userData == null) {
          throw Exception('Aucun compte associé à ce numéro de téléphone');
        }
        email = userData['email'];
      } else {
        email = emailOrPhone;
      }

      final enteredPassword = _passwordController.text.trim();

      final cred = await AuthService.login(
        email: email,
        password: enteredPassword,
      );

      if (cred != null) {
        await NotificationService().saveTokenAfterLogin();

        final userData = await AuthService.getUserData(cred.user!.uid);
        final role = userData?['role'] ?? 'donateur';

        // ✅ FIX: إذا ما فيهاش field 'statut' → الحساب قديم → نسمح بالدخول مباشرة
        // فقط نبلوك إذا statut موجود وقيمته مش 'Approuvé'
        final bool hasStatut = userData?.containsKey('statut') ?? false;
        final String statut = userData?['statut'] ?? '';

        if (hasStatut && statut != 'Approuvé') {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (_) => const PendingApprovalScreen()),
              (route) => false,
            );
          }
          return;
        }

        // ✅ إذا ما فيهاش statut → نضيف 'Approuvé' تلقائياً للحسابات القديمة
        if (!hasStatut) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cred.user!.uid)
              .update({'statut': 'Approuvé'});
        }

        String route;
        if (role == 'association') {
          route = '/assoc/home';
        } else if (role == 'benevole') {
          route = '/ben/dashboard';
        } else {
          route = '/don/home';
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, route);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        String message = 'Erreur de connexion';
        if (e.toString().contains('Aucun compte associé')) {
          message = e.toString();
        } else if (e.toString().contains('incorrect') ||
            e.toString().contains('wrong-password')) {
          message = 'Email/Numéro ou mot de passe incorrect';
        } else if (e.toString().contains('user-not-found')) {
          message = 'Aucun compte associé à cet email';
        } else {
          message = e.toString().replaceAll('Exception:', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Text(
                'Se connecter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: ZADColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🍃', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    'Bienvenue sur ZAD',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ZADColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLoginOptionButton('Email', !_usePhoneLogin, () {
                    setState(() => _usePhoneLogin = false);
                  }),
                  const SizedBox(width: 16),
                  _buildLoginOptionButton('Téléphone', _usePhoneLogin, () {
                    setState(() => _usePhoneLogin = true);
                  }),
                ],
              ),
              const SizedBox(height: 24),
              ZADTextField(
                hint: _usePhoneLogin
                    ? 'Entrez votre numéro de téléphone'
                    : 'Entrez votre email',
                icon: _usePhoneLogin
                    ? Icons.phone_outlined
                    : Icons.email_outlined,
                controller:
                    _usePhoneLogin ? _phoneController : _emailController,
                keyboardType: _usePhoneLogin
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              ZADTextField(
                hint: 'Entrez votre mot de passe',
                icon: Icons.lock_outline,
                obscure: _obscurePassword,
                controller: _passwordController,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(
                      color: ZADColors.linkBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ZADButton(
                label: _isLoading ? 'Connexion...' : 'Se connecter',
                onTap: _isLoading ? () {} : _handleLogin,
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider(color: ZADColors.divider)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: TextStyle(color: ZADColors.textLight),
                    ),
                  ),
                  Expanded(child: Divider(color: ZADColors.divider)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: ZADColors.signupBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🍃', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          'Pas encore de compte ?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Rejoignez ZAD en tant que :',
                      style: TextStyle(
                        fontSize: 14,
                        color: ZADColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ZADButton(
                label: 'Créer un compte',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OnboardingScreen2(),
                    ),
                  );
                },
                outlined: true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginOptionButton(
      String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ZADColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? ZADColors.primary : ZADColors.textLight,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : ZADColors.textLight,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}