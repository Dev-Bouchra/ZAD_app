import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'package:a/chat_service.dart';
import 'messages_screen.dart';
import '../shared/zad_colors.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactInitials;
  final Color contactBgColor;
  final String contactPhone;
  final String contactId;
  final String? myName;
  final String? myInitials;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactInitials,
    required this.contactBgColor,
    required this.contactPhone,
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

  Future<void> _makePhoneCall() async {
    if (widget.contactPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: widget.contactPhone);
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
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
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.messagesStream(widget.contactId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: ZADColors.primary),
                  );
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
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _chat.currentUserId;
                    final time = _chat.formatTime(
                      data['timestamp'] as Timestamp?,
                    );
                    return Column(
                      children: [
                        _ChatBubble(
                          messageId: docs[i].id,
                          message: data['text'] ?? '',
                          isMine: isMe,
                          time: time,
                          onLongPress: isMe
                              ? () => _confirmDelete(docs[i].id)
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
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
      color: ZADColors.headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.contactBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    widget.contactInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.contactPhone.isNotEmpty)
                GestureDetector(
                  onTap: _makePhoneCall,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(Icons.phone,
                        color: Colors.white, size: 22),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ZADColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Écrivez votre message...',
                  hintStyle: TextStyle(
                    color: ZADColors.textLight,
                    fontSize: 14,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ZADColors.primary,
                borderRadius: BorderRadius.circular(12),
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

class _ChatBubble extends StatelessWidget {
  final String messageId;
  final String message;
  final bool isMine;
  final String time;
  final VoidCallback? onLongPress;

  const _ChatBubble({
    required this.messageId,
    required this.message,
    required this.isMine,
    required this.time,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? ZADColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: isMine
                  ? ZADColors.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMine ? Colors.white : ZADColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 9,
                color: isMine ? Colors.white70 : ZADColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );

    if (onLongPress == null) return bubble;

    return GestureDetector(
      onLongPress: onLongPress,
      child: bubble,
    );
  }
}