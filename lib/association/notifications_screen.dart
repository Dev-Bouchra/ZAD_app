// lib/association/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';

class ZadColors {
  static const Color darkNavy  = Color(0xFF1A2B4A);
  static const Color teal      = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg    = Color(0xFFF5F7FA);
}

class _NotifData {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  _NotifData({required this.id, required this.title, required this.body,
      required this.type, required this.isRead, this.createdAt});

  factory _NotifData.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _NotifData(
      id: doc.id,
      // ✅ يقرأ 'titre' (أدمين) أو 'title' (ZAD)
      title: d['titre'] ?? d['title'] ?? '',
      // ✅ يقرأ 'message' (أدمين) أو 'body' (ZAD)
      body: d['message'] ?? d['body'] ?? '',
      type: d['type'] ?? 'system',
      // ✅ يقرأ 'lu' (أدمين) أو 'isRead' (ZAD)
      isRead: d['lu'] ?? d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  IconData get icon {
    switch (type) {
      case 'don':        return Icons.volunteer_activism;
      case 'benevole':   return Icons.directions_bike;
      case 'evaluation': return Icons.star_outline;
      case 'livraison':  return Icons.check_circle_outline;
      case 'urgent':     return Icons.flash_on;
      default:           return Icons.notifications_outlined;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'don':        return const Color(0xFF2E7D32);
      case 'benevole':   return const Color(0xFF1565C0);
      case 'evaluation': return const Color(0xFFFFB800);
      case 'livraison':  return const Color(0xFF2E7D32);
      case 'urgent':     return const Color(0xFFE53935);
      default:           return const Color(0xFF6A1B9A);
    }
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'il y a ${diff.inHours}h';
    if (diff.inDays == 1)    return 'Hier';
    return 'il y a ${diff.inDays} jours';
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'Tous';
  final List<String> _filters = ['Tous', 'Non lus', 'Dons', 'Bénévoles', 'Système'];

  // ✅ المسار الموحّد — يستقبل من الأدمين ومن ZAD
  Stream<List<_NotifData>> get _notifsStream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.uid)
        .collection('messages')
        .snapshots()
        .handleError((e) => debugPrint('notif error: $e'))
        .map((snap) {
          final docs = snap.docs.toList()
            ..sort((a, b) {
              final aT = (a.data() as Map)['createdAt'] as Timestamp?;
              final bT = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aT == null || bT == null) return 0;
              return bT.compareTo(aT);
            });
          return docs.map(_NotifData.fromDoc).toList();
        });
  }

  List<_NotifData> _applyFilter(List<_NotifData> all) {
    switch (_filter) {
      case 'Non lus':   return all.where((n) => !n.isRead).toList();
      case 'Dons':      return all.where((n) => n.type == 'don' || n.type == 'urgent' || n.type == 'livraison').toList();
      case 'Bénévoles': return all.where((n) => n.type == 'benevole' || n.type == 'evaluation').toList();
      case 'Système':   return all.where((n) => n.type == 'system').toList();
      default:          return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZadColors.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Notifications',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () async => await NotificationService.markAllAsRead(),
                  child: const Text('Tout lire', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<_NotifData>>(
              stream: _notifsStream,
              builder: (context, snapshot) {
                // ✅ معالجة الخطأ — لا شاشة حمراء
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Impossible de charger les notifications',
                        style: TextStyle(color: ZadColors.labelGrey)),
                  );
                }

                final all = snapshot.data ?? [];
                final filtered = _applyFilter(all);
                final nonLus = filtered.where((n) => !n.isRead).toList();
                final lus    = filtered.where((n) =>  n.isRead).toList();
                final unreadTotal = all.where((n) => !n.isRead).length;

                return Column(
                  children: [
                    // ── Filters ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final active = _filter == f;
                            final badge = f == 'Non lus' && unreadTotal > 0 ? ' ($unreadTotal)' : '';
                            return GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: active ? ZadColors.darkNavy : ZadColors.cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$f$badge',
                                    style: TextStyle(
                                      color: active ? Colors.white : ZadColors.labelGrey,
                                      fontSize: 12,
                                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                    )),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // ── Liste ────────────────────────────
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator(color: ZadColors.leafGreen))
                          : filtered.isEmpty
                              ? _buildEmpty()
                              : ListView(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  children: [
                                    if (nonLus.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text('NON LUS',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                color: ZadColors.labelGrey, letterSpacing: 0.8)),
                                      ),
                                      ...nonLus.map((n) => _NotifCard(
                                          data: n, onTap: () => NotificationService.markAsRead(n.id))),
                                    ],
                                    if (lus.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text('DÉJÀ LUS',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                color: ZadColors.labelGrey, letterSpacing: 0.8)),
                                      ),
                                      ...lus.map((n) => _NotifCard(data: n, onTap: () {})),
                                    ],
                                  ],
                                ),
                    ),
                  ],
                );
              },
            ),
          ),

          _BottomNav(active: 0),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🔔', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('Aucune notification',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ZadColors.darkNavy)),
        SizedBox(height: 6),
        Text('Vous êtes à jour !', style: TextStyle(fontSize: 12, color: ZadColors.labelGrey)),
      ]),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final _NotifData data;
  final VoidCallback onTap;
  const _NotifCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: data.isRead ? ZadColors.cardBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: data.isRead ? null : Border.all(color: const Color(0xFFE8F5E9), width: 1),
          boxShadow: data.isRead ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: data.iconColor.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(data.icon, color: data.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: TextStyle(fontSize: 13,
                          fontWeight: data.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: ZadColors.darkNavy)),
                  if (data.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(data.body, style: const TextStyle(fontSize: 12, color: ZadColors.labelGrey)),
                  ],
                  const SizedBox(height: 4),
                  Text(data.timeAgo, style: const TextStyle(fontSize: 11, color: ZadColors.labelGrey)),
                ],
              ),
            ),
            if (!data.isRead)
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: ZadColors.leafGreen, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int active;
  const _BottomNav({required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_outlined, label: 'Home', active: active == 0,
              onTap: () => Navigator.pushReplacementNamed(context, '/assoc/home')),
          _NavItem(icon: Icons.people_outline, label: 'Bénéficiaires', active: active == 1,
              onTap: () => Navigator.pushReplacementNamed(context, '/assoc/beneficiaires')),
          _NavItem(icon: Icons.volunteer_activism, label: 'Dons', active: active == 2,
              onTap: () => Navigator.pushReplacementNamed(context, '/assoc/dons')),
          _NavItem(icon: Icons.chat_outlined, label: 'Chat', active: active == 3,
              onTap: () => Navigator.pushReplacementNamed(context, '/assoc/messages')),
          _NavItem(icon: Icons.person_outline, label: 'Profil', active: active == 4,
              onTap: () => Navigator.pushReplacementNamed(context, '/assoc/profil')),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: active ? ZadColors.leafGreen : ZadColors.labelGrey, size: 22),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10,
            color: active ? ZadColors.leafGreen : ZadColors.labelGrey,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}
