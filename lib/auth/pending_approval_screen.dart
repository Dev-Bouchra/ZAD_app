// lib/auth/pending_approval_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  static const _green = Color(0xFF2E7D32);
  static const _greenPale = Color(0xFFE8F5E9);

  // ── écoute en temps réel le statut du compte ──────────────
  // Si l'admin approuve pendant que l'écran est ouvert,
  // l'utilisateur sera automatiquement redirigé.
  late Stream<DocumentSnapshot> _statutStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _statutStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _redirectByRole(String role, String statut) {
    if (statut != 'Approuvé') return;
    String route;
    switch (role.toLowerCase()) {
      case 'benevole':
        route = '/ben/dashboard';
        break;
      case 'donateur':
        route = '/don/home';
        break;
      case 'association':
        route = '/assoc/home';
        break;
      default:
        return;
    }
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
          context, route, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _statutStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final statut = data['statut'] ?? 'En attente';
          final role = data['role'] ?? '';

          // ── إذا تم القبول تلقائياً → انتقل فوراً ──────────
          if (statut == 'Approuvé') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _redirectByRole(role, statut);
            });
          }

          // ── إذا تم الرفض → أظهر رسالة رفض ────────────────
          if (statut == 'Rejeté') {
            return _buildRejectedScreen();
          }
        }

        // ── الحالة الافتراضية: En attente ──────────────────
        return _buildPendingScreen();
      },
    );
  }

  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // ── أيقونة الانتظار ────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _green.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('⏳', style: TextStyle(fontSize: 56)),
                ),
              ),
              const SizedBox(height: 32),

              // ── العنوان ────────────────────────────────────
              const Text(
                'Demande envoyée !',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre demande d\'inscription est en cours\nd\'examen par notre équipe.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF388E3C),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── بطاقة المعلومات ────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _infoRow('⏱️', 'Délai de traitement', '24 à 48 heures'),
                    const Divider(height: 24),
                    _infoRow('📧', 'Notification', 'Par email dès validation'),
                    const Divider(height: 24),
                    _infoRow('🔄', 'Statut actuel', 'En attente de validation'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── ملاحظة ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: _green, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vous pouvez fermer l\'application. Votre demande reste enregistrée et sera traitée par l\'administrateur.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _green,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // ── زر الخروج ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('❌', style: TextStyle(fontSize: 56)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Demande refusée',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB71C1C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre demande d\'inscription a été refusée.\nVeuillez contacter l\'administration pour plus d\'informations.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFE53935),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Retour à la connexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF757575))),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B))),
            ],
          ),
        ),
      ],
    );
  }
}
