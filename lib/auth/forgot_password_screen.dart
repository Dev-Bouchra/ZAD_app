// lib/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import 'login_screen.dart';
import '../shared/zad_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  void _sendResetEmail() {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer votre adresse email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // استعمال then بدل async/await باش نتفادو مشكلة Future
    FirebaseAuth.instance.sendPasswordResetEmail(email: email).then((_) {
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    }).catchError((e) {
      setState(() => _isLoading = false);
      
      String message = 'Erreur lors de l\'envoi';
      if (e.toString().contains('user-not-found')) {
        message = 'Aucun compte associé à cet email';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    });
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
              const SizedBox(height: 60),
              
              Icon(Icons.lock_reset, size: 80, color: ZADColors.primary),
              
              const SizedBox(height: 20),
              
              const Text(
                'Mot de passe oublié',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: ZADColors.textDark,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: ZADColors.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 56),
              
              if (!_emailSent) ...[
                ZADTextField(
                  label: 'Email',
                  hint: 'exemple@email.com',
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 40),
                
                ZADButton(
                  label: _isLoading ? 'Envoi...' : 'Envoyer le lien',
                  onTap: _sendResetEmail,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ZADColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ZADColors.primary),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.send, size: 60, color: ZADColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Email envoyé !',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ZADColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Un lien de réinitialisation a été envoyé à :',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: ZADColors.textMedium),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ZADColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vérifiez votre boîte de réception (et vos spams).',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: ZADColors.textLight),
                      ),
                      const SizedBox(height: 24),
                      ZADButton(
                        label: 'Retour à la connexion',
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        outlined: true,
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 30),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: ZADColors.textLight),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}