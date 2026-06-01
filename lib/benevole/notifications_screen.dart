// lib/benevole/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';

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
      title: d['titre'] ?? d['title'] ?? '',
      body: d['message'] ?? d['body'] ?? '',
      type: d['type'] ?? 'system',
      isRead: d['lu'] ?? d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get emoji {
    switch (type) {
      case 'new_don':       return '🍽️';
      case 'mission_accepted': return '✅';
      case 'mission_completed': return '🎉';
      case 'livraison':     return '📦';
      case 'new_rating':    return '⭐';
      case 'new_recompense': return '🏅';
      case 'new_message':   return '📩';
      case 'evaluation':    return '⭐';
      case 'don':           return '🍽️';
      case 'urgent':        return '⚡';
      case 'mission':       return '✅';
      case 'badge':         return '🏅';
      case 'recompense':    return '🎟️';
      case 'alerte':        return '⚠️';
      default:              return '🔔';
    }
  }

  Color get iconBg {
    switch (type) {
      case 'new_don':
      case 'mission_accepted':
      case 'mission_completed':
      case 'don':
      case 'mission':
        return const Color(0xFFE8F5E9);
      case 'livraison':
        return const Color(0xFFE8F5E9);
      case 'new_rating':
      case 'evaluation':
        return const Color(0xFFFFF9C4);
      case 'new_recompense':
      case 'badge':
      case 'recompense':
        return const Color(0xFFFFE0B2);
      case 'new_message':
        return const Color(0xFFE3F2FD);
      case 'urgent':
      case 'alerte':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }
}

class BenevoleNotificationsScreen extends StatefulWidget {
  const BenevoleNotificationsScreen({super.key});

  @override
  State<BenevoleNotificationsScreen> createState() =>
      _BenevoleNotificationsScreenState();
}

class _BenevoleNotificationsScreenState
    extends State<BenevoleNotificationsScreen> {
  static const _green = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);
  static const _red = Color(0xFFD32F2F);
  static const _greenBg = Color(0xFFF1F8E9);

  String _activeFilter = 'Tout';

  Stream<List<_NotifData>> get _notifsStream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.uid)
        .collection('messages')  // ✅ المسار الصحيح
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
    switch (_activeFilter) {
      case 'Non lus':
        return all.where((n) => !n.isRead).toList();
      case '🍽️ Dons':
        return all
            .where((n) => n.type == 'new_don' || n.type == 'mission_accepted' || n.type == 'mission_completed' || n.type == 'livraison')
            .toList();
      case '🏅 Badges':
        return all
            .where((n) => n.type == 'new_recompense' || n.type == 'new_rating')
            .toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: StreamBuilder<List<_NotifData>>(
        stream: _notifsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les notifications',
                  style: TextStyle(color: _subText)),
            );
          }

          final all = snapshot.data ?? [];
          final filtered = _applyFilter(all);
          final unreadCount = all.where((n) => !n.isRead).length;

          return Column(
            children: [
              _buildHeader(unreadCount),
              _buildFilterRow(unreadCount),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: CircularProgressIndicator(color: _green))
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : _buildList(filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x554CAF50),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 18,
        left: 18,
        right: 18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (unreadCount > 0)
            GestureDetector(
              onTap: () => NotificationService.markAllAsRead(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Tout lire',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(int unreadCount) {
    final filters = ['Tout', 'Non lus', '🍽️ Dons', '🏅 Badges'];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          itemBuilder: (_, i) {
            final active = _activeFilter == filters[i];
            final isNonLus = filters[i] == 'Non lus';
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(colors: [_greenDark, _green])
                      : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? _green : _divider,
                    width: 1.5,
                  ),
                  boxShadow: active
                      ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Row(
                  children: [
                    Text(
                      filters[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : _subText,
                      ),
                    ),
                    if (isNonLus && unreadCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: active ? Colors.white.withOpacity(0.3) : _red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<_NotifData> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final n = items[i];
        final showUnreadSection = i == 0 && !n.isRead;
        final showReadSection = !n.isRead ? false : (i == 0 || !items[i - 1].isRead);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showUnreadSection) _sectionLabel('NON LUS'),
            if (showReadSection) _sectionLabel('DÉJÀ LUS'),
            _buildNotifCard(n),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: _subText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotifCard(_NotifData n) {
    return GestureDetector(
      onTap: () {
        if (!n.isRead) NotificationService.markAsRead(n.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: !n.isRead ? _greenBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !n.isRead ? _green.withOpacity(0.3) : _divider,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: !n.isRead ? _green.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: n.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(n.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: !n.isRead ? FontWeight.w700 : FontWeight.w500,
                      color: _textDark,
                    ),
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style: const TextStyle(fontSize: 10, color: _subText, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    n.timeAgo,
                    style: TextStyle(
                      fontSize: 9,
                      color: !n.isRead ? _green : _subText,
                      fontWeight: !n.isRead ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔔', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Aucune notification',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
          SizedBox(height: 6),
          Text('Vous êtes à jour !', style: TextStyle(fontSize: 12, color: _subText)),
        ],
      ),
    );
  }
}