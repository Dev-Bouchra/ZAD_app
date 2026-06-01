// ============================================================
// 📄 lib/donateur/messages_screen.dart  (VERSION FINALE)
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'package:a/chat_service.dart';
import 'chat_screen.dart';
import '../shared/zad_colors.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _chat = ChatService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Modal nouvelle conversation ───
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
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chat.getUsersToChat(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: ZADColors.primary),
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
                                contactBgColor: ZADColors.primary,
                                contactPhone: '',
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
      case 'association': return const Color(0xFF1B5E20);
      case 'donateur':    return const Color(0xFF1565C0);
      case 'benevole':    return const Color(0xFFE65100);
      default:            return Colors.grey;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'association': return 'Association';
      case 'donateur':    return 'Donateur';
      case 'benevole':    return 'Bénévole';
      default:            return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.conversationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: ZADColors.primary),
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
                        const Text('Aucune conversation',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Appuyez sur + pour commencer',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final contactId = (data['participants'] as List)
                        .firstWhere((id) => id != uid, orElse: () => '');
                    final name = data['contactName_$uid'] as String? ?? 'Contact';
                    final initials = data['contactInitials_$uid'] as String? ?? '??';
                    final unread = data['unreadCount_$uid'] as int? ?? 0;
                    final lastMsg = data['lastMessage'] as String? ?? '';
                    final time = _chat.formatConversationTime(
                        data['lastMessageAt'] as Timestamp?);

                    return _buildItem(
                      contactId: contactId,
                      name: name,
                      initials: initials,
                      lastMsg: lastMsg,
                      unread: unread,
                      time: time,
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
        backgroundColor: ZADColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 4),
    );
  }

  Widget _buildItem({
    required String contactId,
    required String name,
    required String initials,
    required String lastMsg,
    required int unread,
    required String time,
  }) {
    final hasUnread = unread > 0;
    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            contactName: name,
            contactInitials: initials,
            contactBgColor: ZADColors.primary,
            contactPhone: '',
            contactId: contactId,
          ),
        ),
      ),
      tileColor: hasUnread ? ZADColors.primarySoft : null,
      leading: CircleAvatar(
        backgroundColor: ZADColors.primary,
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      title: Text(name,
          style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
              color: ZADColors.textDark)),
      subtitle: Text(
        lastMsg.isEmpty ? 'Démarrer la conversation' : lastMsg,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: hasUnread ? ZADColors.primary : ZADColors.textLight,
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time,
              style: TextStyle(
                  fontSize: 11,
                  color: hasUnread ? ZADColors.primary : ZADColors.textLight)),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: ZADColors.primary, shape: BoxShape.circle),
              child: Text('$unread',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: ZADColors.headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Messages',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: _openNewConversationModal,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
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
        ),
      ),
    );
  }
}
