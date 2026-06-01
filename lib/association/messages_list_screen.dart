// ============================================================
// 📄 lib/association/messages_list_screen.dart  (VERSION FINALE)
// نفس الملف يتستعمل في benevole/ و donateur/ — غير اللون
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:a/chat_service.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  final _chat = ChatService();
  String _searchQuery = '';

  // ─── لون التطبيق — غيريه حسب كل app ───
  // association : Color(0xFF1B5E20)  أخضر غامق
  // benevole    : Color(0xFFE65100)  برتقالي
  // donateur    : Color(0xFF1565C0)  أزرق
  static const _primaryColor = Color(0xFF1B5E20);
  static const _lightBg = Color(0xFFE8F5E9);

  // ─── Modal اختيار شخص لمحادثة جديدة ───
  void _openNewConversationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Column(
          children: [
            // ── مقبض ──
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nouvelle conversation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),

            // ── قائمة المستخدمين ──
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chat.getUsersToChat(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    );
                  }

                  final users = snapshot.data ?? [];

                  if (users.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun utilisateur disponible',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (ctx, i) {
                      final user = users[i];
                      final name = (user['name'] ?? 'Utilisateur') as String;
                      final role = (user['role'] ?? '') as String;
                      final uid = user['uid'] as String;
                      final initials = _chat.getInitials(name);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(role),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _roleLabel(role),
                          style: TextStyle(
                            color: _roleColor(role),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                contactName: name,
                                contactInitials: initials,
                                contactId: uid,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'association':
        return const Color(0xFF1B5E20);
      case 'donateur':
        return const Color(0xFF1565C0);
      case 'benevole':
        return const Color(0xFFE65100);
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'association':
        return 'Association';
      case 'donateur':
        return 'Donateur';
      case 'benevole':
        return 'Bénévole';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.conversationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                final uid = _chat.currentUserId;
                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      (data['contactName_$uid'] as String? ?? '').toLowerCase();
                  return _searchQuery.isEmpty ||
                      name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[350]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aucune conversation'
                              : 'Aucun résultat',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Appuyez sur + pour commencer',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13),
                          ),
                        ]
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final contactName =
                        data['contactName_$uid'] as String? ?? 'Contact';
                    final contactInitials =
                        data['contactInitials_$uid'] as String? ?? '??';
                    final contactId = (data['participants'] as List)
                        .firstWhere((id) => id != uid, orElse: () => '');
                    final lastMsg = data['lastMessage'] as String? ?? '';
                    final unread = (data['unreadCount_$uid'] as int? ?? 0) > 0;
                    final time = _chat.formatConversationTime(
                        data['lastMessageAt'] as Timestamp?);

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            contactName: contactName,
                            contactInitials: contactInitials,
                            contactId: contactId,
                          ),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: unread ? _lightBg : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(16),
                          border: unread
                              ? Border.all(
                                  color: _primaryColor.withOpacity(0.3))
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _primaryColor,
                              radius: 24,
                              child: Text(
                                contactInitials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contactName,
                                    style: TextStyle(
                                      fontWeight: unread
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      color: const Color(0xFF1B1B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lastMsg.isEmpty
                                        ? 'Démarrer la conversation'
                                        : lastMsg,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: unread ? _primaryColor : Colors.grey,
                                      fontWeight: unread
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: unread ? _primaryColor : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (unread)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: _primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewConversationModal,
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 25),
      decoration: const BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 28),
                onPressed: _openNewConversationModal,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
