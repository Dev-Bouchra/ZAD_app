// lib/screens/association/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'ajouter_beneficiare_screen.dart';
import 'don_details_screen.dart';
import 'evaluer_benevole_screen.dart';
import 'dons_disponibles_screen.dart';
import 'beneficiaires_screen.dart';
import 'profil_screen.dart';
import 'statistiques_screen.dart';
import 'publier_bessoin_screen.dart';
import 'benevoles_screen.dart';
import 'messages_list_screen.dart';
import 'notifications_screen.dart';
import 'mes_besoins.dart';
import 'package:a/notification_service.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  static final List<Widget> _screens = [
    const HomeContent(),
    const BeneficiairesScreen(),
    const DonsDisponiblesScreen(),
    const MessagesListScreen(),
    const ProfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _updateAssociationLocation(); // ✅ تحديث موقع الجمعية عند كل فتح
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("❌ Erreur: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ تحديث موقع الجمعية في Firestore (يُستدعى عند كل فتح)
  Future<void> _updateAssociationLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint("📍 Localisation association mise à jour: ${pos.latitude}, ${pos.longitude}");
    } catch (e) {
      debugPrint("❌ Erreur localisation: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZadColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: ZadColors.leafGreen,
          unselectedItemColor: ZadColors.labelGrey,
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Bénéficiaires',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.volunteer_activism_outlined),
              activeIcon: Icon(Icons.volunteer_activism),
              label: 'Dons',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined),
              activeIcon: Icon(Icons.chat),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  Stream<int> _unreadNotificationsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.uid)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<String> _loadAssociationName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Association';
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['associationName'] ?? data['name'] ?? 'Association';
      }
      return 'Association';
    } catch (e) {
      return 'Association';
    }
  }

  Future<Map<String, dynamic>> _loadRealStats() async {
    try {
      final donsSnapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('status', whereIn: ['accepte_par_association', 'en_route', 'livre'])
          .get();
      
      int donsCount = donsSnapshot.docs.length;
      int repasCount = 0;
      double kgCount = 0;
      
      for (var doc in donsSnapshot.docs) {
        final data = doc.data();
        final quantity = data['quantity'] ?? '';
        if (quantity.contains('kg')) {
          final kg = double.tryParse(quantity.replaceAll('kg', '').trim());
          if (kg != null) kgCount += kg;
        } else if (quantity.contains('portion')) {
          final portions = int.tryParse(quantity.replaceAll('portion', '').trim());
          if (portions != null) repasCount += portions;
        }
      }
      
      final benevolesCount = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'benevole')
          .get()
          .then((snap) => snap.docs.length);
      
      final beneficiairesCount = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'beneficiaire')
          .get()
          .then((snap) => snap.docs.length);
      
      return {
        'dons': donsCount,
        'repas': repasCount,
        'kg': kgCount.toStringAsFixed(0),
        'benevoles': benevolesCount,
        'beneficiaires': beneficiairesCount,
      };
    } catch (e) {
      return {
        'dons': 0,
        'repas': 0,
        'kg': '0',
        'benevoles': 0,
        'beneficiaires': 0,
      };
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ZadColors.leafGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToTab(BuildContext context, int index) {
    final homeScreenState =
        context.findAncestorStateOfType<_HomeScreenState>();
    if (homeScreenState != null) {
      homeScreenState._onItemTapped(index);
    }
  }

  Map<String, dynamic> _buildDonData(
      String docId, Map<String, dynamic> d) {
    return {
      'donId': docId,
      'titre': d['title'] ?? 'Don',
      'source': d['donorName'] ?? '',
      'adresse': d['address'] ?? '',
      'quantite': d['quantity'] ?? '',
      'expiration': d['expiryDate'] ?? '',
      'description': d['description'] ?? '',
      'isUrgent': d['isUrgent'] ?? false,
      'statut': d['isUrgent'] == true ? 'Urgent' : 'En attente',
    };
  }

  DateTime? _parseExpiryDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadAssociationName(),
      builder: (context, snapshot) {
        final associationName = snapshot.data ?? 'Association';

        return Scaffold(
          backgroundColor: ZadColors.background,
          body: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B5E20),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        top: -10,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ZadColors.leafGreen.withAlpha(40),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 40,
                        top: -20,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ZadColors.teal.withAlpha(50),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ZAD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                ),
                                child: StreamBuilder<int>(
                                  stream: _unreadNotificationsCount(),
                                  builder: (context, snapshot) {
                                    final count = snapshot.data ?? 0;
                                    return Badge(
                                      label: count > 0
                                          ? Text('$count',
                                              style: const TextStyle(fontSize: 10))
                                          : null,
                                      backgroundColor: Colors.red,
                                      child: Icon(
                                        Icons.notifications_outlined,
                                        color: Colors.white.withAlpha(230),
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Bienvenue 🌿',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            associationName,
                            style: const TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FutureBuilder<Map<String, dynamic>>(
                            future: _loadRealStats(),
                            builder: (context, statsSnapshot) {
                              final stats = statsSnapshot.data ?? {
                                'dons': 0,
                                'repas': 0,
                                'kg': '0',
                                'benevoles': 0,
                                'beneficiaires': 0,
                              };
                              return Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const StatistiquesScreen(),
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(30),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.white.withAlpha(38)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Ce mois-ci : ${stats['kg']} kg de nourriture sauvée !',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.white.withAlpha(179),
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const StatistiquesScreen(),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _HeaderStat(value: '${stats['dons']}', label: 'Dons reçus'),
                                        _Divider(),
                                        _HeaderStat(value: '${stats['repas']}', label: 'Repas'),
                                        _Divider(),
                                        _HeaderStat(value: '${stats['beneficiaires']}', label: 'Bénéficiaires'),
                                        _Divider(),
                                        _HeaderStat(value: '${stats['benevoles']}', label: 'Bénévoles'),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('dons')
                            .where('status', isEqualTo: 'disponible')
                            .where('isUrgent', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }

                          final urgentDons = snapshot.data?.docs ?? [];

                          if (urgentDons.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return SizedBox(
                            height: 140,
                            child: PageView.builder(
                              itemCount: urgentDons.length,
                              itemBuilder: (context, index) {
                                final doc = urgentDons[index];
                                final d =
                                    doc.data() as Map<String, dynamic>;
                                final donTitle = d['title'] ?? 'Don';
                                final donorName = d['donorName'] ?? '';
                                final quantity = d['quantity'] ?? '';

                                final expiryDate =
                                    _parseExpiryDate(d['expiryDate']);

                                String timeLeft = '';
                                if (expiryDate != null) {
                                  final diff =
                                      expiryDate.difference(DateTime.now());
                                  if (diff.isNegative) {
                                    timeLeft = 'Expiré';
                                  } else if (diff.inMinutes < 60) {
                                    timeLeft =
                                        'expire dans ${diff.inMinutes} min';
                                  } else if (diff.inHours < 24) {
                                    timeLeft =
                                        'expire dans ${diff.inHours}h';
                                  } else {
                                    timeLeft =
                                        'expire dans ${diff.inDays}j';
                                  }
                                }

                                final progress = expiryDate != null
                                    ? (DateTime.now()
                                                .difference(expiryDate)
                                                .inMinutes
                                                .abs() /
                                            60)
                                        .clamp(0.0, 1.0)
                                    : 0.35;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFFF9800),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Don urgent disponible !',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        Color(0xFFE65100),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$donorName · $donTitle · $quantity',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Color(0xFF795548),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      DonDetailsScreen(
                                                    donId: doc.id,
                                                    donData: _buildDonData(
                                                        doc.id, d),
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFF9800),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Text(
                                              'Voir',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(
                                            begin: 0.0, end: progress),
                                        duration: const Duration(
                                            milliseconds: 800),
                                        builder: (context, value, _) =>
                                            ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: value,
                                            backgroundColor:
                                                const Color(0xFFFFCC80),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                        Color>(
                                                    Color(0xFFFF9800)),
                                            minHeight: 5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeLeft.isNotEmpty
                                            ? timeLeft
                                            : 'Urgent',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF795548),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Mission en cours',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ZadColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('dons')
                            .where('status', whereIn: [
                              'en_route',
                              'en_livraison',
                              'recu_par_benevole',
                            ])
                            .snapshots(),
                        builder: (context, snapshot) {
                          final enRouteCount =
                              snapshot.data?.docs.length ?? 0;

                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BenevolesScreen(
                                  initialFilter: 'En mission',
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: ZadColors.cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFC8E6C9),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1B5E20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.directions_bike,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      if (enRouteCount > 0)
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE65100),
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                              minHeight: 20,
                                            ),
                                            child: Text(
                                              '$enRouteCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Missions en cours',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: ZadColors.darkNavy,
                                          ),
                                        ),
                                        Text(
                                          enRouteCount == 0
                                              ? 'Aucun bénévole en route'
                                              : '$enRouteCount bénévole${enRouteCount > 1 ? 's' : ''} en route',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ZadColors.labelGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: ZadColors.labelGrey,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Actions Rapides',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ZadColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Publier un Besoin',
                        iconBg: const Color(0xFFE3F2FD),
                        iconColor: const Color(0xFF1565C0),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PublierBesoinScreen(),
                          ),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.list_alt_outlined,
                        label: 'Mes Besoins',
                        iconBg: const Color(0xFFE8F5E9),
                        iconColor: const Color(0xFF2E7D32),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MesBesoinsScreen(),
                          ),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.person_add_outlined,
                        label: 'Ajouter un bénéficiaire',
                        iconBg: const Color(0xFFE8F5E9),
                        iconColor: ZadColors.leafGreen,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AjouterBeneficiaireScreen(),
                          ),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.volunteer_activism,
                        label: 'Dons reçus',
                        iconBg: const Color(0xFFFFF3E0),
                        iconColor: const Color(0xFFE65100),
                        onTap: () => _navigateToTab(context, 2),
                      ),
                      _ActionButton(
                        icon: Icons.directions_bike,
                        label: 'Liste des bénévoles',
                        iconBg: const Color(0xFFE3F2FD),
                        iconColor: const Color(0xFF1565C0),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BenevolesScreen(),
                          ),
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.people_outline,
                        label: 'Liste des bénéficiaires',
                        iconBg: const Color(0xFFF3E5F5),
                        iconColor: const Color(0xFF6A1B9A),
                        onTap: () => _navigateToTab(context, 1),
                      ),
                      _ActionButton(
                        icon: Icons.star_rate_outlined,
                        label: 'Évaluer un bénévole',
                        iconBg: const Color(0xFFFFF8E1),
                        iconColor: const Color(0xFFFFB300),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BenevolesScreen(
                              selectionMode: true,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Dernières notifications',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ZadColors.darkNavy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection('messages')
                            .orderBy('createdAt', descending: true)
                            .limit(3)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                height: 100,
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final docs = snapshot.data?.docs ?? [];
                          
                          if (docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: ZadColors.cardBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  'Aucune notification',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ZadColors.labelGrey,
                                  ),
                                ),
                              ),
                            );
                          }
                          
                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final title = data['titre'] ?? data['title'] ?? '';
                              final body = data['message'] ?? data['body'] ?? '';
                              final createdAt = data['createdAt'] as Timestamp?;
                              final isRead = data['lu'] ?? data['isRead'] ?? false;
                              
                              String timeAgo = '';
                              if (createdAt != null) {
                                final diff = DateTime.now().difference(createdAt.toDate());
                                if (diff.inMinutes < 1) {
                                  timeAgo = 'À l\'instant';
                                } else if (diff.inMinutes < 60) {
                                  timeAgo = 'il y a ${diff.inMinutes} min';
                                } else if (diff.inHours < 24) {
                                  timeAgo = 'il y a ${diff.inHours}h';
                                } else if (diff.inDays == 1) {
                                  timeAgo = 'Hier';
                                } else {
                                  timeAgo = 'il y a ${diff.inDays} jours';
                                }
                              }
                              
                              IconData icon = Icons.notifications_outlined;
                              if (data['type'] == 'don' || data['type'] == 'new_donation') {
                                icon = Icons.restaurant;
                              } else if (data['type'] == 'mission_accepted') {
                                icon = Icons.directions_bike;
                              } else if (data['type'] == 'livraison') {
                                icon = Icons.check_circle_outline;
                              } else if (data['type'] == 'evaluation') {
                                icon = Icons.star_outline;
                              }
                              
                              return GestureDetector(
                                onTap: () {
                                  if (!isRead) {
                                    final uid = FirebaseAuth.instance.currentUser?.uid;
                                    if (uid != null) {
                                      FirebaseFirestore.instance
                                          .collection('notifications')
                                          .doc(uid)
                                          .collection('messages')
                                          .doc(doc.id)
                                          .update({'isRead': true, 'lu': true});
                                    }
                                  }
                                  _showSnackbar(context, body);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isRead ? ZadColors.cardBg : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isRead
                                        ? null
                                        : Border.all(
                                            color: ZadColors.leafGreen.withOpacity(0.3),
                                            width: 1,
                                          ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(icon, color: ZadColors.leafGreen, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                                color: ZadColors.darkNavy,
                                              ),
                                            ),
                                            if (body.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                body,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: ZadColors.labelGrey,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isRead ? ZadColors.labelGrey : ZadColors.leafGreen,
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(left: 8),
                                          decoration: const BoxDecoration(
                                            color: ZadColors.leafGreen,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value, label;
  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withAlpha(179), fontSize: 10),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 30, color: Colors.white.withAlpha(51));
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBg, iconColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ZadColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: ZadColors.darkNavy,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: ZadColors.labelGrey, size: 20),
          ],
        ),
      ),
    );
  }
}