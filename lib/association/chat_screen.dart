import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:a/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactInitials;
  final String contactId;
  final String? myName;
  final String? myInitials;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactInitials,
    required this.contactId,
    this.myName,
    this.myInitials,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chat = ChatService();

  static const _primaryColor = Color(0xFF1B5E20);

  bool _isReady = false;

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
      otherName: widget.contactName,
      otherInitials: widget.contactInitials,
    );

    await _chat.markAsRead(widget.contactId);

    if (mounted) {
      setState(() => _isReady = true);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await _chat.sendMessage(otherUid: widget.contactId, text: text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          if (!_isReady)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _primaryColor),
              ),
            )
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chat.messagesStream(widget.contactId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primaryColor),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.waving_hand_outlined,
                              size: 48, color: Colors.grey[350]),
                          const SizedBox(height: 12),
                          Text(
                            'Dites bonjour à ${widget.contactName} 👋',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
      padding: const EdgeInsets.fromLTRB(10, 50, 20, 20),
      decoration: const BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 20,
            child: Text(
              widget.contactInitials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const Text(
                  'En ligne',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.contactId)
                  .get();
              final phone = doc.data()?['phone']?.toString() ?? '';
              if (phone.isEmpty) return;
              final uri = Uri(scheme: 'tel', path: phone);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(String messageId, String text, bool isMe, String time) {
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: isMe ? _primaryColor : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 0),
          bottomRight: Radius.circular(isMe ? 0 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
                color: isMe ? Colors.white : Colors.black87, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                time,
                style: TextStyle(
                    fontSize: 9,
                    color: isMe ? Colors.white60 : Colors.grey),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                const Icon(Icons.done_all, size: 11, color: Colors.white60),
              ],
            ],
          ),
        ],
      ),
    );

    if (!isMe) return Align(alignment: Alignment.centerLeft, child: bubble);

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _confirmDelete(messageId),
        child: bubble,
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}