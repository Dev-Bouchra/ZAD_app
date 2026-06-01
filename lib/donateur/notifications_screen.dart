// lib/donateur/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'home_screen.dart';
import '../notification_service.dart';
import '../shared/zad_colors.dart';

// ─── Données d'une notification ───────────────────────────────
class _NotifData {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  _NotifData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

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
      case 'benevole':   return Icons.directions_car;
      case 'evaluation': return Icons.star;
      case 'livraison':  return Icons.check_circle;
      case 'don':        return Icons.person_add_outlined;
      case 'urgent':     return Icons.warning_amber_rounded;
      default:           return Icons.notifications_outlined;
    }
  }

  Color get iconBg {
    switch (type) {
      case 'benevole':   return ZADColors.primarySoft;
      case 'evaluation': return const Color(0xFFFFF8E1);
      case 'livraison':  return const Color(0xFFE8F5E9);
      case 'don':        return ZADColors.primarySoft;
      case 'urgent':     return const Color(0xFFFFF3E0);
      default:           return ZADColors.primarySoft;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'benevole':
      case 'don':        return ZADColors.primary;
      case 'evaluation': return ZADColors.accentYellow;
      case 'livraison':  return ZADColors.success;
      case 'urgent':     return ZADColors.accentOrange;
      default:           return ZADColors.primary;
    }
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1)    return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }
}

// ─────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0;

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
    switch (_selectedFilter) {
      case 1: return all.where((n) => !n.isRead).toList();
      case 2: return all.where((n) => n.type == 'don' || n.type == 'livraison' || n.type == 'urgent').toList();
      case 3: return all.where((n) => n.type == 'benevole').toList();
      default: return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: StreamBuilder<List<_NotifData>>(
        stream: _notifsStream,
        builder: (context, snapshot) {
          // ✅ معالجة الخطأ — لا شاشة حمراء
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les notifications',
                  style: TextStyle(color: ZADColors.textLight)),
            );
          }

          final all = snapshot.data ?? [];
          final filtered = _applyFilter(all);
          final unreadCount = all.where((n) => !n.isRead).length;

          return Column(
            children: [
              // ── Header ──────────────────────────────
              Container(
                color: ZADColors.headerBg,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                        const Expanded(
                          child: Text('Notifications',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                        const SizedBox(width: 26),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Filters ─────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _FilterChip(label: 'Tout', active: _selectedFilter == 0,
                        onTap: () => setState(() => _selectedFilter = 0)),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Non lus ($unreadCount)', active: _selectedFilter == 1,
                        onTap: () => setState(() => _selectedFilter = 1)),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Dons', active: _selectedFilter == 2,
                        onTap: () => setState(() => _selectedFilter = 2)),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Bénévoles', active: _selectedFilter == 3,
                        onTap: () => setState(() => _selectedFilter = 3)),
                  ],
                ),
              ),

              // ── Liste ───────────────────────────────
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: ZADColors.primary))
                    : filtered.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🔔', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('Aucune notification',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ZADColors.textDark)),
                                SizedBox(height: 6),
                                Text('Vous êtes à jour !',
                                    style: TextStyle(fontSize: 12, color: ZADColors.textLight)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final n = filtered[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NotifItem(
                                  data: n,
                                  onTap: () {
                                    if (!n.isRead) NotificationService.markAsRead(n.id);
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 3),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ZADColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? ZADColors.primary : ZADColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
              color: active ? Colors.white : ZADColors.textMedium,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _NotifItem extends StatelessWidget {
  final _NotifData data;
  final VoidCallback onTap;
  const _NotifItem({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: !data.isRead ? ZADColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: !data.isRead ? Border.all(color: ZADColors.accent.withOpacity(0.4)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: data.iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(data.icon, color: data.iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: TextStyle(
                        fontWeight: !data.isRead ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                        color: ZADColors.textDark,
                      )),
                  if (data.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(data.body, style: const TextStyle(color: ZADColors.textMedium, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (data.timeAgo.isNotEmpty)
              Text(data.timeAgo, style: const TextStyle(color: ZADColors.textLight, fontSize: 10)),
            if (!data.isRead)
              Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: const BoxDecoration(color: ZADColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
