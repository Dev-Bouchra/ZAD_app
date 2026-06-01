// 📄 lib/benevole/mes_recompenses_screen.dart
// ✅ نظام كوبونات حقيقي — Firestore + QR Code + عتبات النقاط

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ============================================================
// 🎁 الكوبونات الثابتة — مرتبطة بعتبات النقاط
// ============================================================
class CouponTemplate {
  final String id;
  final String title;
  final String partner;
  final String description;
  final String icon;
  final int pointsRequired;
  final int validityDays; // -1 = بدون انتهاء
  final String type; // 'discount' | 'gift'

  const CouponTemplate({
    required this.id,
    required this.title,
    required this.partner,
    required this.description,
    required this.icon,
    required this.pointsRequired,
    required this.validityDays,
    required this.type,
  });
}

const List<CouponTemplate> kCouponTemplates = [
  CouponTemplate(
    id: 'coupon_50pts',
    title: '10% de réduction',
    partner: 'Boulangerie Atlas',
    description: 'Réduction de 10% sur tout achat',
    icon: '🥐',
    pointsRequired: 50,
    validityDays: 30,
    type: 'discount',
  ),
  CouponTemplate(
    id: 'coupon_100pts',
    title: 'Boisson gratuite',
    partner: 'Café Bab El Qarmadine',
    description: 'Une boisson offerte au choix',
    icon: '☕',
    pointsRequired: 100,
    validityDays: 60,
    type: 'gift',
  ),
  CouponTemplate(
    id: 'coupon_200pts',
    title: '20% de réduction',
    partner: 'Restaurant El Baraka',
    description: 'Réduction de 20% sur votre repas',
    icon: '🍽️',
    pointsRequired: 200,
    validityDays: 45,
    type: 'discount',
  ),
  CouponTemplate(
    id: 'coupon_500pts',
    title: 'Repas complet offert',
    partner: 'Restaurant El Baraka',
    description: 'Entrée + Plat offerts',
    icon: '🏆',
    pointsRequired: 500,
    validityDays: 90,
    type: 'gift',
  ),
];

// ============================================================
// 🖥️ الشاشة الرئيسية
// ============================================================
class MesRecompensesScreen extends StatefulWidget {
  const MesRecompensesScreen({super.key});

  @override
  State<MesRecompensesScreen> createState() => _MesRecompensesScreenState();
}

class _MesRecompensesScreenState extends State<MesRecompensesScreen> {
  static const _green = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _orange = Color(0xFFFF8F00);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  List<Map<String, dynamic>> _coupons = [];
  int _userPoints = 0;
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final points = (userDoc.data()?['points'] as num?)?.toInt() ?? 0;

      final snapshot = await FirebaseFirestore.instance
          .collection('coupons')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final coupons = snapshot.docs.map((doc) {
        return {'docId': doc.id, ...doc.data()};
      }).toList();

      if (mounted) {
        setState(() {
          _userPoints = points;
          _coupons = coupons;
          _isLoading = false;
        });
      }

      await _checkAndGenerateCoupons(user.uid, points, coupons);
    } catch (e) {
      debugPrint('❌ Erreur loadData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndGenerateCoupons(
      String userId, int points, List<Map<String, dynamic>> existingCoupons) async {
    if (_isGenerating) return;
    _isGenerating = true;

    try {
      final existingIds =
          existingCoupons.map((c) => c['templateId'] as String? ?? '').toSet();
      bool generated = false;

      for (final template in kCouponTemplates) {
        if (points >= template.pointsRequired && !existingIds.contains(template.id)) {
          await _generateCoupon(userId, template);
          generated = true;
        }
      }

      if (generated && mounted) await _loadData();
    } catch (e) {
      debugPrint('❌ Erreur génération: $e');
    } finally {
      _isGenerating = false;
    }
  }

  Future<void> _generateCoupon(String userId, CouponTemplate template) async {
    final userSuffix = userId.substring(0, 4).toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final suffix = template.id.split('_').last.toUpperCase();
    final code = 'ZAD-$suffix-$userSuffix-$timestamp';

    String expiry = 'Indéfiniment';
    DateTime? expiryDate;
    if (template.validityDays > 0) {
      expiryDate = DateTime.now().add(Duration(days: template.validityDays));
      expiry =
          '${expiryDate.day.toString().padLeft(2, '0')}/${expiryDate.month.toString().padLeft(2, '0')}/${expiryDate.year}';
    }

    await FirebaseFirestore.instance.collection('coupons').add({
      'userId': userId,
      'templateId': template.id,
      'title': template.title,
      'partner': template.partner,
      'description': template.description,
      'icon': template.icon,
      'code': code,
      'type': template.type,
      'expiry': expiry,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
      'pointsRequired': template.pointsRequired,
      'used': false,
      'usedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markAsUsed(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('coupons')
          .doc(docId)
          .update({'used': true, 'usedAt': FieldValue.serverTimestamp()});
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Coupon marqué comme utilisé'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ $e');
    }
  }

  void _showQRCode(Map<String, dynamic> coupon) {
    final qrData = jsonEncode({
      'code': coupon['code'],
      'title': coupon['title'],
      'partner': coupon['partner'],
      'expiry': coupon['expiry'],
      'type': coupon['type'],
      'templateId': coupon['templateId'],
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(coupon['icon'] ?? '🎁',
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            Text(coupon['title'],
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textDark)),
            const SizedBox(height: 4),
            Text(coupon['partner'],
                style: const TextStyle(fontSize: 13, color: _subText)),
            const SizedBox(height: 20),

            // ✅ QR Code حقيقي
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.circle, color: _greenDark),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: _green),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _green.withOpacity(0.4)),
                    ),
                    child: Text(coupon['code'],
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _greenDark,
                            letterSpacing: 3)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.event_available, size: 14, color: _subText),
              const SizedBox(width: 6),
              Text('Valable jusqu\'au ${coupon['expiry']}',
                  style: const TextStyle(fontSize: 12, color: _subText)),
            ]),
            const SizedBox(height: 4),
            const Row(children: [
              Icon(Icons.info_outline, size: 14, color: _subText),
              SizedBox(width: 6),
              Text('Une utilisation uniquement',
                  style: TextStyle(fontSize: 12, color: _subText)),
            ]),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmMarkAsUsed(coupon['docId']);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Marquer utilisé'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmMarkAsUsed(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer l\'utilisation',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Êtes-vous sûr d\'avoir utilisé ce coupon ? Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Annuler', style: TextStyle(color: _subText))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _markAsUsed(docId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _coupons.where((c) => c['used'] == false).toList();
    final used = _coupons.where((c) => c['used'] == true).toList();
    final existingIds =
        _coupons.map((c) => c['templateId'] as String? ?? '').toSet();
    final upcoming = kCouponTemplates
        .where((t) =>
            t.pointsRequired > _userPoints && !existingIds.contains(t.id))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStats(available.length, used.length),
                    const SizedBox(height: 20),
                    if (available.isNotEmpty) ...[
                      _sectionTitle('🎁 Disponibles', available.length),
                      const SizedBox(height: 10),
                      ...available.map((c) => _CouponCard(
                            coupon: c,
                            onShowQR: () => _showQRCode(c),
                            onMarkUsed: () => _confirmMarkAsUsed(c['docId']),
                          )),
                      const SizedBox(height: 20),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _sectionTitle('🔒 Prochainement', upcoming.length),
                      const SizedBox(height: 10),
                      ...upcoming.map((t) => _UpcomingCouponCard(
                            template: t,
                            currentPoints: _userPoints,
                          )),
                      const SizedBox(height: 20),
                    ],
                    if (used.isNotEmpty) ...[
                      _sectionTitle('✅ Utilisés', used.length),
                      const SizedBox(height: 10),
                      ...used.map((c) => _CouponCard(
                            coupon: c,
                            onShowQR: null,
                            onMarkUsed: null,
                          )),
                    ],
                    if (_coupons.isEmpty && upcoming.isEmpty)
                      _buildEmpty(),
                  ],
                ),
              ),
            ),
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
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
        left: 18,
        right: 18,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Mes récompenses',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('$_userPoints pts',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(int available, int used) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          _statItem('🎁', '$available', 'Disponibles', _green),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _statItem('✅', '$used', 'Utilisés', _subText),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _statItem('⭐', '$_userPoints', 'Points', _orange),
        ],
      ),
    );
  }

  Widget _statItem(String icon, String val, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Text(val,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 9, color: _subText)),
      ]),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Row(children: [
      Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textDark)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: _greenPale, borderRadius: BorderRadius.circular(8)),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _greenDark)),
      ),
    ]);
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        const Text('🎁', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('Aucune récompense',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textDark)),
        const SizedBox(height: 6),
        Text(
          'Commencez dès ${kCouponTemplates.first.pointsRequired} points !',
          style: const TextStyle(fontSize: 12, color: _subText),
        ),
      ]),
    );
  }
}

// ============================================================
// 🃏 كارت الكوبون
// ============================================================
class _CouponCard extends StatelessWidget {
  final Map<String, dynamic> coupon;
  final VoidCallback? onShowQR;
  final VoidCallback? onMarkUsed;

  const _CouponCard(
      {required this.coupon,
      required this.onShowQR,
      required this.onMarkUsed});

  @override
  Widget build(BuildContext context) {
    final isUsed = coupon['used'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUsed ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUsed
              ? Colors.grey.shade300
              : const Color(0xFF4CAF50).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: isUsed
            ? null
            : [
                BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isUsed
                  ? Colors.grey.shade200
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
                child: Text(coupon['icon'] ?? '🎁',
                    style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon['title'],
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isUsed
                            ? Colors.grey
                            : const Color(0xFF1B1B1B))),
                const SizedBox(height: 2),
                Text(coupon['partner'],
                    style: TextStyle(
                        fontSize: 12,
                        color: isUsed
                            ? Colors.grey.shade400
                            : const Color(0xFF757575))),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.event_available,
                      size: 11,
                      color: isUsed
                          ? Colors.grey
                          : const Color(0xFF4CAF50)),
                  const SizedBox(width: 4),
                  Text(coupon['expiry'] ?? '',
                      style: TextStyle(
                          fontSize: 10,
                          color: isUsed
                              ? Colors.grey
                              : const Color(0xFF4CAF50))),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isUsed)
            GestureDetector(
              onTap: onShowQR,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('QR Code',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Utilisé',
                  style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
            ),
        ]),
      ),
    );
  }
}

// ============================================================
// 🔒 كارت الكوبون القادم (مقفول مع progress bar)
// ============================================================
class _UpcomingCouponCard extends StatelessWidget {
  final CouponTemplate template;
  final int currentPoints;

  const _UpcomingCouponCard(
      {required this.template, required this.currentPoints});

  @override
  Widget build(BuildContext context) {
    final progress =
        (currentPoints / template.pointsRequired).clamp(0.0, 1.0);
    final remaining = template.pointsRequired - currentPoints;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: Text(template.icon,
                    style: const TextStyle(fontSize: 26))),
          ),
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(14)),
          ),
          const Icon(Icons.lock, color: Colors.grey, size: 20),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.grey)),
              const SizedBox(height: 2),
              Text(template.partner,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(
                      Color(0xFF4CAF50)),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text('Encore $remaining pts pour débloquer',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF757575))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFFF8F00).withOpacity(0.4)),
          ),
          child: Text('${template.pointsRequired} pts',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF8F00))),
        ),
      ]),
    );
  }
}
