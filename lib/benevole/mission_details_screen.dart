// ============================================================
// 📄 lib/screens/benevole/mission_details_screen.dart
// ✅ تفاصيل المهمة للبينيفول: معلومات التبرع + معلومات الجمعية
// ============================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MissionDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> don;

  const MissionDetailsScreen({super.key, required this.don});

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  static const _green     = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _greenBg   = Color(0xFFF1F8E9);
  static const _red       = Color(0xFFD32F2F);
  static const _redBg     = Color(0xFFFFEBEE);
  static const _orange    = Color(0xFFFF8F00);
  static const _subText   = Color(0xFF757575);
  static const _textDark  = Color(0xFF1B1B1B);
  static const _divider   = Color(0xFFEEEEEE);

  Map<String, dynamic>? _donData;
  Map<String, dynamic>? _associationData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final donId = widget.don['donId'] as String? ?? '';

      // 1. جلب تفاصيل التبرع الكاملة من Firestore
      if (donId.isNotEmpty) {
        final donDoc = await FirebaseFirestore.instance
            .collection('dons')
            .doc(donId)
            .get();
        if (donDoc.exists) {
          _donData = {'id': donDoc.id, ...donDoc.data()!};
        }
      }
      _donData ??= widget.don;

      // 2. جلب معلومات الجمعية
      final associationId = (_donData?['associationId'] as String?) ?? '';
      if (associationId.isNotEmpty) {
        final assocDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(associationId)
            .get();
        if (assocDoc.exists) {
          _associationData = {'id': assocDoc.id, ...assocDoc.data()!};
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement détails: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.don['urgent'] == true;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : CustomScrollView(
              slivers: [
                // ── AppBar مع صورة التبرع ──
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: _greenDark,
                  iconTheme: const IconThemeData(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      _donData?['title'] ?? widget.don['title'] ?? 'Détails',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                    background: _buildDonImage(),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── شارة Urgent ──
                      if (isUrgent)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 20),
                          color: _redBg,
                          child: const Row(
                            children: [
                              Icon(Icons.flash_on, color: _red, size: 16),
                              SizedBox(width: 6),
                              Text('Don URGENT — Action rapide requise',
                                  style: TextStyle(
                                    color: _red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ════════════════════════════
                            // SECTION 1 — Détails du don
                            // ════════════════════════════
                            _sectionHeader(
                                Icons.card_giftcard, 'Détails du don'),
                            const SizedBox(height: 14),

                            _infoTile(Icons.fastfood_outlined, 'Produit',
                                _donData?['title'] ?? widget.don['title'] ?? '—'),

                            _infoTile(Icons.shopping_bag_outlined, 'Quantité',
                                _donData?['quantity']?.toString()
                                    ?? widget.don['qty']?.toString()
                                    ?? '—'),

                            if ((_donData?['description'] ?? '').toString().isNotEmpty)
                              _infoTile(Icons.info_outline, 'Description',
                                  _donData!['description'].toString()),

                            _infoTile(
                              Icons.timer_outlined,
                              'Expiration',
                              _formatExpiry(
                                  _donData?['expiryDate']?.toString()
                                  ?? _donData?['expiration']?.toString()
                                  ?? '—'),
                            ),

                            _infoTile(Icons.location_on_outlined, 'Adresse de collecte',
                                _donData?['address']
                                    ?? widget.don['place']
                                    ?? '—'),

                            _infoTile(Icons.person_outline, 'Donateur',
                                _donData?['donorName']
                                    ?? widget.don['donorName']
                                    ?? '—'),

                            // Distance
                            if (widget.don['distLabel'] != null)
                              _infoTile(Icons.directions_outlined, 'Distance',
                                  widget.don['distLabel']),

                            const SizedBox(height: 24),

                            // ════════════════════════════════
                            // SECTION 2 — Informations Association
                            // ════════════════════════════════
                            _sectionHeader(
                                Icons.business, 'Informations de l\'association'),
                            const SizedBox(height: 14),

                            _buildAssociationCard(),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── صورة التبرع ──
  Widget _buildDonImage() {
    final imageUrl = _donData?['imageUrl'] as String?;
    final hasImage = imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.contains('placeholder');

    return Stack(
      fit: StackFit.expand,
      children: [
        hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : Container(color: _greenPale),
                errorBuilder: (_, __, ___) => _defaultDonImage(),
              )
            : _defaultDonImage(),
        // تدرج داكن أسفل الصورة لإظهار العنوان
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultDonImage() {
    return Container(
      color: _greenBg,
      child: Center(
        child: Text(
          widget.don['icon'] ?? '🍽️',
          style: const TextStyle(fontSize: 72),
        ),
      ),
    );
  }

  // ── بطاقة الجمعية ──
  Widget _buildAssociationCard() {
    if (_associationData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _greenBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.business, color: _green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.don['associationName'] ?? 'Association',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final assoc        = _associationData!;
    final assocName    = assoc['associationName'] ?? assoc['name'] ?? '—';
    final assocPhone   = assoc['phone'] ?? '—';
    final assocAddress = assoc['quartier'] ?? assoc['address'] ?? '—';
    final assocEmail   = assoc['email'] ?? '';
    final assocImageUrl = assoc['profileImageUrl'] as String?;
    final hasAssocImage = assocImageUrl != null && assocImageUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_greenDark, _green]),
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // صورة الجمعية + الاسم
                Row(
                  children: [
                    // صورة البروفايل
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _green, width: 2),
                        color: _greenPale,
                      ),
                      child: ClipOval(
                        child: hasAssocImage
                            ? Image.network(
                                assocImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _assocInitials(assocName),
                              )
                            : _assocInitials(assocName),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(assocName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              )),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _greenPale,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('✅ Association partenaire',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _greenDark,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: _divider),
                const SizedBox(height: 12),

                // تفاصيل الجمعية
                _assocInfoRow(Icons.location_on_outlined, assocAddress),
                const SizedBox(height: 8),
                if (assocPhone != '—')
                  _assocInfoRow(Icons.phone_outlined, assocPhone),
                if (assocEmail.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _assocInfoRow(Icons.email_outlined, assocEmail),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _assocInitials(String name) {
    final parts = name.split(' ');
    String initials = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return Container(
      color: _greenPale,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _greenDark,
            )),
      ),
    );
  }

  Widget _assocInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: _green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                fontSize: 12,
                color: _subText,
                height: 1.4,
              )),
        ),
      ],
    );
  }

  // ── عنوان القسم ──
  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: _green, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textDark,
            )),
      ],
    );
  }

  // ── صف معلومات ──
  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _greenDark, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _subText,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatExpiry(String raw) {
    if (raw == '—' || raw.isEmpty) return '—';
    // تحويل ISO 8601 → تاريخ مقروء
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
