// lib/donateur/profile_screen.dart
// ✅ إصلاح جذري: إحصائيات حقيقية من collection dons + donorType حقيقي
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'edit_profile_screen.dart';
import 'historique_dons_screen.dart';
import 'notif_settings_screen.dart';
import 'home_screen.dart';
import 'mes_offres_screen.dart';
import '../../auth/login_screen.dart';
import '../shared/zad_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Donateur';
  String _userInitials = 'D';
  String _userQuartier = '';
  String _userAddress = '';
  String _userPhotoUrl = '';
  String _donorType = 'Donateur'; // ✅ نوع الدوناتور الحقيقي
  bool _isLoading = true;

  // ✅ إحصائيات حقيقية من dons
  int _totalDons = 0;
  int _totalLivres = 0;
  double _totalKgSauves = 0.0;
  double _noteMoyenne = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUserData(), _loadRealStats()]);
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] ?? 'Donateur';
          _userInitials = _getInitials(_userName);
          _userQuartier = data['quartier'] ?? '';
          _userAddress = data['address'] ?? '';
          _userPhotoUrl = data['photoUrl'] ?? '';
          // ✅ الحل الجذري: donorType من Firestore مع fallback
          _donorType = data['donorType']?.toString().isNotEmpty == true
              ? data['donorType']
              : 'Donateur';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRealStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ جلب كل الدونات من collection dons مباشرة
      final donsSnap = await FirebaseFirestore.instance
          .collection('dons')
          .where('donorId', isEqualTo: user.uid)
          .get();

      int livres = 0;
      double kgSauves = 0.0;

      for (final doc in donsSnap.docs) {
        final data = doc.data();
        final status = data['status']?.toString() ?? '';

        if (status == 'livre') {
          livres++;
          // ✅ حساب الكيلوغرامات من quantity الحقيقي
          final qty = data['quantity']?.toString() ?? '';
          final qtyNum =
              double.tryParse(qty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          kgSauves += qtyNum > 0 ? qtyNum : 0.5;
        }
      }

      // ✅ التقييم من collection ratings
      final ratingsSnap = await FirebaseFirestore.instance
          .collection('ratings')
          .where('donorId', isEqualTo: user.uid)
          .get();

      double noteMoyenne = 0.0;
      if (ratingsSnap.docs.isNotEmpty) {
        double totalNotes = 0.0;
        for (var doc in ratingsSnap.docs) {
          final raw = doc.data()['note'] ?? doc.data()['rating'] ?? 0;
          totalNotes += (raw is num) ? raw.toDouble() : 0.0;
        }
        noteMoyenne = totalNotes / ratingsSnap.docs.length;
      } else {
        // fallback: rating من users
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final r = userDoc.data()?['rating'];
        if (r is num) noteMoyenne = r.toDouble();
      }

      setState(() {
        _totalDons = donsSnap.docs.length;
        _totalLivres = livres;
        _totalKgSauves = kgSauves;
        _noteMoyenne = noteMoyenne;
      });
    } catch (e) {
      debugPrint("❌ Erreur stats profil: $e");
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: ZADColors.headerBg,
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HomeScreen(),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const Spacer(),
                              // ✅ زر تحديث
                              GestureDetector(
                                onTap: _loadAll,
                                child: const Icon(Icons.refresh,
                                    color: Colors.white70, size: 20),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: ZADColors.primaryLight,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipOval(
                                child: _userPhotoUrl.isNotEmpty
                                    ? Image.network(
                                        _userPhotoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              _userInitials,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 28,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Text(
                                          _userInitials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 28,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DonateurEditProfileScreen(),
                                  ),
                                );
                                _loadAll();
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: ZADColors.accentYellow,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.store_outlined,
                                color: ZADColors.accent,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              // ✅ نوع الدوناتور الحقيقي + الحي
                              Text(
                                '$_donorType${_userQuartier.isNotEmpty ? ' · $_userQuartier' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_userAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '📍 $_userAddress',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // ✅ إحصائيات حقيقية
                        Container(
                          margin: const EdgeInsets.all(16),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _ProfileStat(
                                  value: '$_totalDons', label: 'Dons'),
                              const _ProfileStatDivider(),
                              _ProfileStat(
                                  value:
                                      '${_totalKgSauves.toStringAsFixed(1)}kg',
                                  label: 'Sauvés'),
                              const _ProfileStatDivider(),
                              _ProfileStat(
                                  value: _noteMoyenne > 0
                                      ? '⭐${_noteMoyenne.toStringAsFixed(1)}'
                                      : '⭐--',
                                  label: 'Note'),
                              const _ProfileStatDivider(),
                              _ProfileStat(
                                  value: '$_totalLivres', label: 'Livrés'),
                            ],
                          ),
                        ),

                        // ── قائمة الخيارات ─────────────────────────────────
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
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
                            children: [
                              _ProfileMenuItem(
                                icon: Icons.person_outline,
                                label: 'Modifier le profil',
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const DonateurEditProfileScreen(),
                                    ),
                                  );
                                  _loadAll();
                                },
                              ),
                              const _ProfileMenuDivider(),
                              _ProfileMenuItem(
                                icon: Icons.history,
                                label: 'Historique des dons',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HistoriqueDonsScreen(),
                                    ),
                                  );
                                },
                              ),
                              const _ProfileMenuDivider(),
                              _ProfileMenuItem(
                                icon: Icons.notifications_outlined,
                                label: 'Paramètres notifications',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const NotifSettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                              const _ProfileMenuDivider(),
                              _ProfileMenuItem(
                                icon: Icons.card_giftcard,
                                label: 'Mes offres de récompense',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MesOffresScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── زر تسجيل الخروج ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: GestureDetector(
                            onTap: () {
                              FirebaseAuth.instance.signOut();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ZADColors.danger.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: ZADColors.danger.withOpacity(0.3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.logout,
                                      color: ZADColors.danger, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'Se déconnecter',
                                    style: TextStyle(
                                      color: ZADColors.danger,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 4),
    );
  }
}

// ── Widgets مساعدة ─────────────────────────────────────────────────────────────

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: ZADColors.textDark)),
        Text(label,
            style:
                const TextStyle(color: ZADColors.textLight, fontSize: 11)),
      ],
    );
  }
}

class _ProfileStatDivider extends StatelessWidget {
  const _ProfileStatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: ZADColors.divider);
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileMenuItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ZADColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ZADColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: ZADColors.textDark)),
            ),
            const Icon(Icons.chevron_right,
                color: ZADColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuDivider extends StatelessWidget {
  const _ProfileMenuDivider();
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 66, endIndent: 16, color: ZADColors.divider);
  }
}
