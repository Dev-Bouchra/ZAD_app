// lib/donateur/home_screen.dart
// ✅ إصلاح جذري: إحصائيات حقيقية من collection dons + سلايدر البنيفولين
// ✅ إصلاح إشعارات: عرض عدد الإشعارات غير المقروءة على أيقونة الجرس
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'evaluate_volunteer_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'tracking_screen.dart';
import 'my_dons_screen.dart';
import 'besoins_screen.dart';
import 'stats_screen.dart';
import 'money_donation_screen.dart';
import '../shared/zad_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'Donateur';
  bool _isLoading = true;
  int _totalDons = 0;
  int _totalLivres = 0;
  double _totalKgSauves = 0;

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

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'Donateur';
        });
      }

      final donsSnap = await FirebaseFirestore.instance
          .collection('dons')
          .where('donorId', isEqualTo: user.uid)
          .get();

      int livres = 0;
      double kgSauves = 0.0;

      for (final d in donsSnap.docs) {
        final data = d.data();
        final status = data['status']?.toString() ?? '';
        if (status == 'livre') {
          livres++;
          final qty = data['quantity']?.toString() ?? '';
          final qtyNum = double.tryParse(qty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          kgSauves += qtyNum > 0 ? qtyNum : 0.5;
        }
      }

      setState(() {
        _totalDons = donsSnap.docs.length;
        _totalLivres = livres;
        _totalKgSauves = kgSauves;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur chargement: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: ZADColors.primary))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadUserData,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BenevolesEnMissionSlider(),
                          const SizedBox(height: 4),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Mes dons récents',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: ZADColors.textDark),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const MyDonsScreen()),
                                ),
                                child: const Text(
                                  'Tout voir →',
                                  style: TextStyle(
                                      color: ZADColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('dons')
                                .where('donorId',
                                    isEqualTo:
                                        FirebaseAuth.instance.currentUser?.uid)
                                .where('status', isEqualTo: 'livre')
                                .orderBy('createdAt', descending: true)
                                .limit(3)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 20),
                                    child: CircularProgressIndicator(
                                        color: ZADColors.primary),
                                  ),
                                );
                              }

                              final docs = snapshot.data?.docs ?? [];

                              if (docs.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: ZADColors.divider),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.card_giftcard_outlined,
                                          color: ZADColors.textLight,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Aucun don livré pour le moment',
                                        style: TextStyle(
                                            color: ZADColors.textLight,
                                            fontSize: 14),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Column(
                                children: docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final benevoleNom =
                                      data['volunteerName'] ??
                                          data['benevoleNom'] ??
                                          '';
                                  final String volunteerId =
                                      data['volunteerId']?.toString() ?? '';
                                  return _DonCard(
                                    emoji: _getEmojiForProduit(
                                        data['title'] ?? ''),
                                    title: data['title'] ?? '',
                                    subtitle:
                                        '${data['quantity'] ?? ''} · Publié ${_getTimeAgo(data['createdAt'])}',
                                    status: 'Livré',
                                    statusColor: ZADColors.success,
                                    assignee: benevoleNom.isNotEmpty
                                        ? benevoleNom
                                        : 'Bénévole',
                                    assigneeColor: ZADColors.primarySoft,
                                    onHeartTap: benevoleNom.isNotEmpty &&
                                            volunteerId.isNotEmpty
                                        ? () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EvaluateVolunteerScreen(
                                                  volunteerName: benevoleNom,
                                                  volunteerInitials:
                                                      _getInitials(benevoleNom),
                                                  currentRating: 4.5,
                                                  volunteerId: volunteerId,
                                                  donationId: doc.id,
                                                  missionTitle:
                                                      'Collecte · ${data['title'] ?? ''} · ${_getTimeAgo(data['createdAt'])}',
                                                ),
                                              ),
                                            )
                                        : null,
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Besoins des associations',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: ZADColors.textDark),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const BesoinsScreen()),
                                ),
                                child: const Text(
                                  'Tout voir →',
                                  style: TextStyle(
                                      color: ZADColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('besoins')
                                .where('statut', isEqualTo: 'actif')
                                .orderBy('createdAt', descending: true)
                                .limit(3)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 20),
                                  child: CircularProgressIndicator(
                                      color: ZADColors.primary),
                                ));
                              }
                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: ZADColors.divider),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          Icons
                                              .volunteer_activism_outlined,
                                          color: ZADColors.textLight,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text('Aucun besoin pour le moment',
                                          style: TextStyle(
                                              color: ZADColors.textLight,
                                              fontSize: 14)),
                                    ],
                                  ),
                                );
                              }
                              return Column(
                                children: docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return _BesoinMiniCard(data: data);
                                }).toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                          _DonEnArgentBanner(
                            onTap: () => Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, a, __) =>
                                    const MoneyDonationScreen(),
                                transitionsBuilder: (_, a, __, child) =>
                                    SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                      parent: a,
                                      curve: Curves.easeOut)),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: const BoxDecoration(
        color: ZADColors.headerBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── شعار ZAD ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.eco, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('ZAD',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      // ══════════════════════════════════════════════
                      // ✅ زر الجرس مع عداد الإشعارات غير المقروءة
                      // يجمع: notifications/{uid}/messages (lu == false)
                      // ══════════════════════════════════════════════
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            // ✅ المسار الصحيح: notifications/{uid}/messages
                            stream: uid == null
                                ? const Stream.empty()
                                : FirebaseFirestore.instance
                                    .collection('notifications')
                                    .doc(uid)
                                    .collection('messages')
                                    .where('lu', isEqualTo: false)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              final count =
                                  snapshot.data?.docs.length ?? 0;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.notifications_outlined,
                                      color: Colors.white, size: 22),

                                  // ✅ يظهر عداد الأرقام إذا count > 0
                                  if (count > 0)
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: ZADColors.accentYellow,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: ZADColors.headerBg,
                                              width: 1.5),
                                        ),
                                        child: Text(
                                          // ✅ إذا أكثر من 9 يعرض 9+
                                          count > 9 ? '9+' : '$count',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // ── زر الملف الشخصي ───────────────────────
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text('Bonjour 👋',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(_userName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              // ── كارت الإحصائيات ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.eco,
                            color: ZADColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                            '${_totalKgSauves.toStringAsFixed(1)} kg sauvés',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        Container(
                          width: 1,
                          height: 14,
                          color: Colors.white30,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        Text('$_totalDons dons publiés',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StatsScreen()),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart_outlined,
                                color: ZADColors.primary, size: 16),
                            SizedBox(width: 6),
                            Text('Voir les statistiques',
                                style: TextStyle(
                                    color: ZADColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                color: ZADColors.primary, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEmojiForProduit(String produit) {
    if (produit.contains('Pain') || produit.contains('pain')) return '🍞';
    if (produit.contains('Repas') || produit.contains('repas')) return '🍲';
    if (produit.contains('Boisson') || produit.contains('boisson')) return '🥤';
    if (produit.contains('Fruits') || produit.contains('fruits')) return '🍎';
    if (produit.contains('Légumes') || produit.contains('légumes')) return '🥕';
    if (produit.contains('Fast') || produit.contains('fast')) return '🍕';
    if (produit.contains('Conserve') || produit.contains('conserve')) return '🥫';
    if (produit.contains('Biscuit') || produit.contains('biscuit')) return '🍪';
    return '🎁';
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'récemment';
    try {
      final date = (timestamp as Timestamp).toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return 'il y a ${diff.inDays}j';
      if (diff.inHours > 0) return 'il y a ${diff.inHours}h';
      if (diff.inMinutes > 0) return 'il y a ${diff.inMinutes}min';
      return 'à l\'instant';
    } catch (_) {
      return 'récemment';
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ✅ سلايدر البنيفولين النشطين
// ══════════════════════════════════════════════════════════════════════════════
class _BenevolesEnMissionSlider extends StatefulWidget {
  @override
  State<_BenevolesEnMissionSlider> createState() =>
      _BenevolesEnMissionSliderState();
}

class _BenevolesEnMissionSliderState extends State<_BenevolesEnMissionSlider> {
  @override
  void dispose() {
    super.dispose();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty
        ? name.substring(0, name.length.clamp(0, 2)).toUpperCase()
        : 'BN';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('dons')
          .where('donorId', isEqualTo: uid)
          .where('status', isEqualTo: 'en_livraison')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final count = docs.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'EN DIRECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count bénévole${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF8F00),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: count,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final benevoleNom =
                        data['volunteerName']?.toString() ??
                            data['benevoleNom']?.toString() ??
                            'Bénévole';
                    final title = data['title']?.toString() ?? '';
                    final donId = docs[i].id;

                    return SizedBox(
                      width: MediaQuery.of(ctx).size.width * 0.88,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFFFB300).withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300).withOpacity(0.15),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(benevoleNom),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    benevoleNom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Color(0xFF1B1B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.local_shipping_outlined,
                                                size: 11,
                                                color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text('En livraison',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.orange,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrackingScreen(donId: donId),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Suivi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Widgets مساعدة ────────────────────────────────────────────────────────────

class _BesoinMiniCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BesoinMiniCard({required this.data});

  Color _urgenceColor(String urgence) {
    switch (urgence) {
      case 'Haute':
        return ZADColors.accentOrange;
      case 'Moyen':
        return ZADColors.accentOrange;
      default:
        return ZADColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgence = data['niveauUrgence'] as String? ?? 'Moyen';
    final color = _urgenceColor(urgence);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              urgence == 'Haute'
                  ? Icons.warning_amber_rounded
                  : urgence == 'Moyen'
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['typeBesoin'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ZADColors.textDark),
                ),
                Text(
                  '${data['quantiteEstimee'] ?? ''} · ${data['associationNom'] ?? ''}',
                  style: const TextStyle(
                      color: ZADColors.textLight, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    urgence,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: ZADColors.textLight),
        ],
      ),
    );
  }
}

class _DonEnArgentBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DonEnArgentBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('💳', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Don en argent',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Soutenez les associations financièrement',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

class _DonCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final String assignee;
  final Color assigneeColor;
  final VoidCallback? onHeartTap;

  const _DonCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.assignee,
    required this.assigneeColor,
    this.onHeartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ZADColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: ZADColors.textDark)),
                Text(subtitle,
                    style: const TextStyle(
                        color: ZADColors.textLight, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: statusColor, size: 12),
                          const SizedBox(width: 4),
                          Text(status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    if (assignee != 'En attente') ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onHeartTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: assigneeColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.favorite,
                                  color: ZADColors.primary, size: 12),
                              const SizedBox(width: 4),
                              Text(assignee,
                                  style: const TextStyle(
                                      color: ZADColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
