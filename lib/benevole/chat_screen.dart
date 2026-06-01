import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:a/chat_service.dart';

class BenevoleChatScreen extends StatefulWidget {
  final String name;
  final String avatar;
  final Color avatarColor;
  final bool isOnline;
  final String contactId;
  final String? myName;
  final String? myInitials;

  const BenevoleChatScreen({
    super.key,
    required this.name,
    required this.avatar,
    required this.avatarColor,
    required this.isOnline,
    required this.contactId,
    this.myName,
    this.myInitials,
  });

  @override
  State<BenevoleChatScreen> createState() => _BenevoleChatScreenState();
}

class _BenevoleChatScreenState extends State<BenevoleChatScreen> {
  static const _green = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _textDark = Color(0xFF1B1B1B);
  static const _subText = Color(0xFF757575);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chat = ChatService();

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    String myName = widget.myName ?? '';
    String myInitials = widget.myInitials ?? '';
    if (myName.isEmpty) {
      final info = await _chat.getUserInfo(_chat.currentUserId);
      myName = info['name']!;
      myInitials = info['initials']!;
    }
    await _chat.openConversation(
      otherUid: widget.contactId,
      myName: myName,
      myInitials: myInitials,
      otherName: widget.name,
      otherInitials: widget.avatar,
    );
    await _chat.markAsRead(widget.contactId);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    _messageController.clear();
    await _chat.sendMessage(otherUid: widget.contactId, text: text);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmDelete(String messageId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer le message ?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text('Ce message sera supprimé pour les deux côtés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _chat.deleteMessage(
                otherUid: widget.contactId,
                messageId: messageId,
              );
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.messagesStream(widget.contactId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _green));
                }

                final docs = snapshot.data?.docs ?? [];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && docs.isNotEmpty) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun message',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _chat.currentUserId;
                    final time =
                        _chat.formatTime(data['timestamp'] as Timestamp?);
                    return _buildBubble(
                        docs[i].id, data['text'] ?? '', isMe, time);
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 12,
        right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(widget.avatar,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              if (widget.isOnline)
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE),
                      shape: BoxShape.circle,
                      border: Border.all(color: _green, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text(
                  widget.isOnline ? '🟢 En ligne' : '⚫ Hors ligne',
                  style:
                      const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String messageId, String text, bool isMe, String time) {
    final bubbleContent = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(
                    colors: [_greenDark, _green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: isMe ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: isMe
                    ? _green.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white : _textDark,
                  height: 1.4)),
        ),
        const SizedBox(height: 3),
        Text(time,
            style: const TextStyle(fontSize: 9, color: _subText)),
      ],
    );

    final row = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: widget.avatarColor, shape: BoxShape.circle),
              child: Center(
                child: Text(widget.avatar,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 6),
          ],
          bubbleContent,
        ],
      ),
    );

    if (!isMe) return row;

    return GestureDetector(
      onLongPress: () => _confirmDelete(messageId),
      child: row,
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _greenPale,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  hintStyle:
                      TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                ),
                style: const TextStyle(fontSize: 12, color: _textDark),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_greenDark, _green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}