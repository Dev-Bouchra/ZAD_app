// ============================================================
// 📄 lib/benevole/messages_screen.dart  (VERSION FINALE)
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:a/chat_service.dart';
import 'chat_screen.dart';
import 'dashboard_screen.dart';

class BenevoleMessagesScreen extends StatefulWidget {
  const BenevoleMessagesScreen({super.key});

  @override
  State<BenevoleMessagesScreen> createState() => _BenevoleMessagesScreenState();
}

class _BenevoleMessagesScreenState extends State<BenevoleMessagesScreen> {
  static const _green     = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _textDark  = Color(0xFF1B1B1B);
  static const _subText   = Color(0xFF757575);

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
                      child: CircularProgressIndicator(color: _green),
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
                      final user  = users[i];
                      final name  = (user['name']  ?? 'Utilisateur') as String;
                      final role  = (user['role']  ?? '')             as String;
                      final uid   =  user['uid']                      as String;
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
                          style: TextStyle(color: _roleColor(role), fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BenevoleChatScreen(
                                name: name,
                                avatar: initials,
                                avatarColor: _roleColor(role),
                                isOnline: false,
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
      case 'benevole':    return _green;
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
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearch(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.conversationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _green));
                }

                final uid  = _chat.currentUserId;
                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name =
                      (data['contactName_$uid'] as String? ?? '').toLowerCase();
                  return _searchQuery.isEmpty ||
                      name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (docs.isEmpty) return _buildEmpty();

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data      = docs[i].data() as Map<String, dynamic>;
                    final contactId = (data['participants'] as List)
                        .firstWhere((id) => id != uid, orElse: () => '');
                    final name    = data['contactName_$uid']     as String? ?? 'Contact';
                    final avatar  = data['contactInitials_$uid'] as String? ?? '??';
                    final unread  = data['unreadCount_$uid']     as int?    ?? 0;
                    final lastMsg = data['lastMessage']          as String? ?? '';
                    final time    = _chat.formatConversationTime(
                        data['lastMessageAt'] as Timestamp?);

                    return _buildItem(
                      contactId:   contactId,
                      name:        name,
                      avatar:      avatar,
                      lastMessage: lastMsg,
                      unread:      unread,
                      time:        time,
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
        backgroundColor: _green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildItem({
    required String contactId,
    required String name,
    required String avatar,
    required String lastMessage,
    required int    unread,
    required String time,
  }) {
    final hasUnread = unread > 0;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BenevoleChatScreen(
            name:        name,
            avatar:      avatar,
            avatarColor: _green,
            isOnline:    false,
            contactId:   contactId,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? const Color(0xFFF1F8E9) : Colors.white,
          border: const Border(
              bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration:
                  const BoxDecoration(color: _green, shape: BoxShape.circle),
              child: Center(
                child: Text(avatar,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w500,
                          color: _textDark)),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage.isEmpty ? 'Démarrer la conversation' : lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: hasUnread ? _greenDark : _subText,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.w400),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(time,
                    style: TextStyle(
                        fontSize: 10,
                        color: hasUnread ? _green : _subText)),
                const SizedBox(height: 4),
                if (hasUnread)
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$unread',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [_greenDark, _green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24)),
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
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const BenevoleDashboardScreen()),
            ),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Messages',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          // زر + في الـ header
          GestureDetector(
            onTap: _openNewConversationModal,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.search, color: _subText, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher une conversation...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  hintStyle:
                      TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                ),
                style: const TextStyle(fontSize: 12, color: _textDark),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.close, color: _subText, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Aucune conversation',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _textDark)),
          const SizedBox(height: 8),
          Text('Appuyez sur + pour commencer',
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
