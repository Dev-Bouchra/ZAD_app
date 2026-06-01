// lib/donateur/my_dons_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'publish_don_screen.dart';
import 'tracking_screen.dart';
import 'home_screen.dart';
import 'don_details_screen.dart'; // ✅ صفحة التفاصيل الجديدة
import '../../auth/auth_service.dart';
import '../shared/zad_colors.dart';

class MyDonsScreen extends StatefulWidget {
  const MyDonsScreen({super.key});

  @override
  State<MyDonsScreen> createState() => _MyDonsScreenState();
}

class _MyDonsScreenState extends State<MyDonsScreen> {
  int _tab = 0;
  final _tabs = ['Tous', 'En cours', 'Livrés', 'Expirés'];

  List<Map<String, dynamic>> _myDons = [];
  bool _isLoading = true;
  String _donorId = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _donorId = user.uid;
      print("👤 Mon UID: $_donorId");
      await _loadMyDons();
    } catch (e) {
      print("❌ Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyDons() async {
    setState(() => _isLoading = true);

    try {
      // ✅ جلب تبرعات المتبرع الحالي فقط
      final querySnapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('donorId', isEqualTo: _donorId)
          .orderBy('createdAt', descending: true)
          .get();

      print("📦 Nombre de mes dons: ${querySnapshot.docs.length}");

      final List<Map<String, dynamic>> dons = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id; // ✅ حفظ id الوثيقة
        print("📝 Don: ${data['title']} - status: ${data['status']}");
        dons.add(data);
      }

      setState(() {
        _myDons = dons;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Erreur chargement dons: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDons {
    switch (_tab) {
      case 1:
        return _myDons
            .where((don) =>
                don['status'] == 'accepté' ||
                don['status'] == 'en_route' ||
                don['status'] == 'en cours' ||
                don['status'] == 'disponible')
            .toList();
      case 2:
        return _myDons
            .where((don) =>
                don['status'] == 'livré' ||
                don['status'] == 'livre' ||
                don['status'] == 'completed')
            .toList();
      case 3:
        return _myDons
            .where((don) =>
                don['status'] == 'expiré' || don['status'] == 'expired')
            .toList();
      default:
        return _myDons;
    }
  }

  String getStatusLabel(String status) {
    switch (status) {
      case 'disponible': return 'En attente';
      case 'accepté':    return 'Accepté';
      case 'en_route':   return 'En route';
      case 'livré':      return 'Livré';
      case 'expiré':     return 'Expiré';
      case 'en cours':   return 'En cours';
      default:           return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'disponible': return ZADColors.warning;
      case 'accepté':    return ZADColors.primary;
      case 'en_route':   return ZADColors.primary;
      case 'en cours':   return ZADColors.primary;
      case 'livré':      return ZADColors.success;
      case 'expiré':     return ZADColors.danger;
      default:           return ZADColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            color: ZADColors.headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const Text(
                      'Mes dons',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PublishDonScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Tabs ──────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final active = i == _tab;
                  return GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? ZADColors.primary.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active
                                ? ZADColors.primary
                                : ZADColors.divider,
                            width: active ? 2 : 1),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          color: active
                              ? ZADColors.primary
                              : ZADColors.textMedium,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── Liste ─────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDons.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('🎁', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text(
                              'Aucun don trouvé',
                              style: TextStyle(
                                  color: ZADColors.textMedium,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMyDons,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDons.length,
                          itemBuilder: (context, index) {
                            final don = _filteredDons[index];
                            return _MyDonItem(
                              emoji: _getEmoji(don['title']),
                              title: don['title'] ?? 'Don',
                              meta: _getMeta(don),
                              statusLabel: getStatusLabel(
                                  don['status'] ?? 'disponible'),
                              statusColor: getStatusColor(
                                  don['status'] ?? 'disponible'),
                              imageUrl: don['imageUrl'] as String?,
                              // ✅ الضغط يفتح صفحة التفاصيل دائماً
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DonDetailsScreen(don: don),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 1),
    );
  }

  String _getEmoji(String? title) {
    if (title == null) return '🍽️';
    if (title.contains('Plat') || title.contains('Fast-food')) return '🍲';
    if (title.contains('Produit sec') || title.contains('Conserve')) return '🥫';
    if (title.contains('Boulangerie') || title.contains('Pain')) return '🥖';
    if (title.contains('Fruits')) return '🍎';
    if (title.contains('Boisson')) return '🥤';
    if (title.contains('Laitier')) return '🥛';
    if (title.contains('Repas')) return '🍲';
    return '🍽️';
  }

  String _getMeta(Map<String, dynamic> don) {
    String meta = don['quantity'] ?? 'Quantité inconnue';

    if (don['createdAt'] != null) {
      final timestamp = don['createdAt'] as Timestamp;
      final date = timestamp.toDate();
      meta += ' · ${date.day}/${date.month}/${date.year}';
    }

    if (don['isUrgent'] == true) {
      meta += ' ⚡ Urgent';
    }

    return meta;
  }
}

// ── _MyDonItem ────────────────────────────────────────────────────────────────

class _MyDonItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String meta;
  final String statusLabel;
  final Color statusColor;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _MyDonItem({
    required this.emoji,
    required this.title,
    required this.meta,
    required this.statusLabel,
    required this.statusColor,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRealImage = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        !imageUrl!.contains('placeholder');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // ── صورة مصغّرة أو إيموجي ──────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: hasRealImage
                  ? Image.network(
                      imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _EmojiBox(emoji: emoji),
                    )
                  : _EmojiBox(emoji: emoji),
            ),

            // ── معلومات التبرع ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: ZADColors.textDark)),
                    const SizedBox(height: 3),
                    Text(meta,
                        style: const TextStyle(
                            color: ZADColors.textLight, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),

            // ── سهم للتفاصيل ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, color: ZADColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiBox extends StatelessWidget {
  final String emoji;
  const _EmojiBox({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: ZADColors.primarySoft,
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}
