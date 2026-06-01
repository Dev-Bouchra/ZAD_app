// ============================================================
// 📄 lib/benevole/missions_screen.dart
// ✅ معدل بالكامل:
// 1. اختفاء زر Évaluer بعد التقييم الكامل
// 2. نظام نقاط حقيقي (أول تقييم +10، ثاني +5)
// 3. تحديث النقاط أتوماتيكياً
// 4. ❌ تمت إزالة عرض +15 pts من البطاقات
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evaluate_association_screen.dart';
import 'evaluate_donor_screen.dart';
import 'dashboard_screen.dart';
import '../notification_service.dart';

class BenevoleMissionsScreen extends StatefulWidget {
  const BenevoleMissionsScreen({super.key});

  @override
  State<BenevoleMissionsScreen> createState() =>
      _BenevoleMissionsScreenState();
}

class _BenevoleMissionsScreenState extends State<BenevoleMissionsScreen> {
  static const _green = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _orange = Color(0xFFFF8F00);
  static const _blue = Color(0xFF1565C0);
  static const _blueBg = Color(0xFFE3F2FD);
  static const _red = Color(0xFFD32F2F);
  static const _redBg = Color(0xFFFFEBEE);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  String _activeFilter = 'Toutes';
  List<Map<String, dynamic>> _missions = [];
  bool _isLoading = true;
  int _realPoints = 0;
  
  // ✅ متغير جديد: يحفظ التبرعات التي تم تقييمها بالكامل
  Set<String> _fullyEvaluatedDonations = {};

  @override
  void initState() {
    super.initState();
    _loadMissions();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _realPoints = (doc.data()?['points'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      print("❌ Erreur loadPoints: $e");
    }
  }

  Future<void> _loadMissions() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('volunteerId', isEqualTo: user.uid)
          .get();

      print("📋 Missions trouvées: ${snapshot.docs.length}");

      final Set<String> allIds = {};
      for (final doc in snapshot.docs) {
        final d = doc.data();
        final assocId = d['associationId']?.toString() ?? '';
        final donorId = d['donorId']?.toString() ?? '';
        if (assocId.isNotEmpty) allIds.add(assocId);
        if (donorId.isNotEmpty) allIds.add(donorId);
      }

      final Map<String, String> userNames = {};
      for (final uid in allIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (userDoc.exists) {
            final name = userDoc.data()?['name']?.toString() ?? '';
            if (name.isNotEmpty) userNames[uid] = name;
          }
        } catch (_) {}
      }

      _fullyEvaluatedDonations.clear();

      if (mounted) {
        setState(() {
          _missions = snapshot.docs.map((doc) {
            final d = doc.data();
            final status = d['status'] as String? ?? 'en_route';

            final String associationId = d['associationId']?.toString() ?? '';
            final String donorId = d['donorId']?.toString() ?? '';

            final String associationName = userNames[associationId] 
                ?? d['associationName']?.toString()
                ?? d['associationNom']?.toString()
                ?? 'Association';

            final String donorName = userNames[donorId]
                ?? d['donorName']?.toString()
                ?? 'Donateur';

            return {
              'donId': doc.id,
              'associationId': associationId,
              'donorId': donorId,
              'icon': _getIcon(d['title']),
              'title': '${d['title'] ?? 'Don'} — ${donorName}',
              'assoc': '${associationName} · ${d['quantity'] ?? ''}',
              'associationName': associationName,
              'donorName': donorName,
              'quantity': d['quantity'] ?? '',
              'status': _mapStatus(status),
              'statusCode': status,
              'statusLabel': _getStatusLabel(status),
              'date': _formatDate(d['updatedAt']),
              'hasEvaluatedAssociation': d['hasEvaluatedAssociation'] ?? false,
              'hasEvaluatedDonor': d['hasEvaluatedDonor'] ?? false,
            };
          }).toList();
          
          _missions.sort((a, b) {
            const order = {'en_cours': 0, 'termine': 1, 'annule': 2};
            return (order[a['status']] ?? 1)
                .compareTo(order[b['status']] ?? 1);
          });
          _isLoading = false;
        });
        
        for (final mission in _missions) {
          final hasEvalAssoc = mission['hasEvaluatedAssociation'] == true;
          final hasEvalDonor = mission['hasEvaluatedDonor'] == true;
          if (hasEvalAssoc && hasEvalDonor) {
            _fullyEvaluatedDonations.add(mission['donId']);
          }
        }
      }
    } catch (e) {
      print("❌ Erreur loadMissions: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapStatus(String firestoreStatus) {
    switch (firestoreStatus) {
      case 'en_route':           return 'en_cours';
      case 'en_livraison':       return 'en_cours';
      case 'recu_par_benevole':  return 'en_cours';
      case 'livre':              return 'termine';
      case 'annule':             return 'annule';
      case 'refuse':             return 'annule';
      default:                   return 'en_cours';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'en_route':          return 'En attente de confirmations';
      case 'en_livraison':      return 'En cours de livraison';
      case 'recu_par_benevole': return '📦 En route vers l\'association';
      case 'livre':             return 'Livré avec succès';
      case 'annule':            return 'Annulée · Avertissement reçu';
      case 'refuse':            return 'Refusée';
      default:                  return 'En cours';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Récent';
    try {
      final dt = (timestamp as dynamic).toDate() as DateTime;
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return "Aujourd'hui";
      if (diff.inDays == 1) return 'Hier';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return 'Récent';
    }
  }

  String _getIcon(String? title) {
    if (title == null) return '🍽️';
    final t = title.toLowerCase();
    if (t.contains('pain') || t.contains('boulangerie')) return '🍞';
    if (t.contains('repas') || t.contains('plat')) return '🍲';
    if (t.contains('légume') || t.contains('fruit')) return '🥦';
    if (t.contains('pâtisserie') || t.contains('gâteau')) return '🍰';
    if (t.contains('conserve')) return '🥫';
    return '🍽️';
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_activeFilter) {
      case '🔄 En cours':
        return _missions
            .where((m) => m['statusCode'] == 'en_route' || m['statusCode'] == 'en_livraison')
            .toList();
      case '⏳ En attente':
        return _missions
            .where((m) => m['statusCode'] == 'en_route')
            .toList();
      case '✅ Terminées':
        return _missions.where((m) => m['status'] == 'termine').toList();
      case '❌ Annulées':
        return _missions.where((m) => m['status'] == 'annule').toList();
      default:
        return _missions;
    }
  }

  Future<void> _accepterMission(Map<String, dynamic> mission) async {
    try {
      await FirebaseFirestore.instance
          .collection('dons')
          .doc(mission['donId'])
          .update({
        'status': 'en_livraison',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Mission acceptée !')),
        );
        await _loadMissions();
      }
    } catch (e) {
      print("❌ Erreur acceptation: $e");
    }
  }

  Future<void> _refuserMission(Map<String, dynamic> mission) async {
    try {
      await FirebaseFirestore.instance
          .collection('dons')
          .doc(mission['donId'])
          .update({
        'status': 'refuse',
        'refusedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Mission refusée')),
        );
        await _loadMissions();
      }
    } catch (e) {
      print("❌ Erreur refus: $e");
    }
  }

  Future<void> _marquerLivre(Map<String, dynamic> mission) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final benDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final benName = benDoc.data()?['name'] ?? 'Bénévole';

      await FirebaseFirestore.instance
          .collection('dons')
          .doc(mission['donId'])
          .update({
        'status': 'livre',
        'livraisonAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mission['associationId'].toString().isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: mission['associationId'],
          title: 'Don livré avec succès ! 📦',
          body: '$benName a livré "${mission['title'].split('—').first.trim()}"',
          type: 'livraison',
          extraData: {'donId': mission['donId']},
        );
      }

      if (mission['donorId'].toString().isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: mission['donorId'],
          title: 'Votre don a été livré ! ✅',
          body: '$benName a livré votre don à ${mission['associationName']}',
          type: 'livraison',
          extraData: {'donId': mission['donId']},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Don marqué comme livré !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadMissions();
      }
    } catch (e) {
      print("❌ Erreur livraison: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _buildStats(),
            _buildFilterRow(),
            Expanded(
              child: _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadMissions,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildMissionCard(_filtered[i]),
                      ),
                    ),
            ),
          ],
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
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const BenevoleDashboardScreen()),
            ),
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
            child: Text('Mes missions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_missions.length} total',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final termine = _missions.where((m) => m['status'] == 'termine').length;
    final enCours = _missions.where((m) => m['statusCode'] == 'en_route' || m['statusCode'] == 'en_livraison').length;
    final annule = _missions.where((m) => m['status'] == 'annule').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem('✅', '$termine', 'Terminées', _green),
          _dividerV(),
          _statItem('🔄', '$enCours', 'En cours', _blue),
          _dividerV(),
          _statItem('❌', '$annule', 'Annulées', _red),
          _dividerV(),
          _statItem('⭐', '$_realPoints', 'Points', _orange),
        ],
      ),
    );
  }

  Widget _statItem(String icon, String val, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 3),
          Text(val,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              )),
          Text(label,
              style: const TextStyle(fontSize: 9, color: _subText)),
        ],
      ),
    );
  }

  Widget _dividerV() {
    return Container(
      width: 1,
      height: 40,
      color: _divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildFilterRow() {
    final filters = [
      'Toutes',
      '⏳ En attente',
      '🔄 En cours',
      '✅ Terminées',
      '❌ Annulées',
    ];
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
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: active ? const LinearGradient(colors: [_greenDark, _green]) : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? _green : _divider, width: 1.5),
                  boxShadow: active
                      ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Text(filters[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : _subText,
                    )),
              ),
            );
          },
        ),
      ),
    );
  }

  // ✅ بطاقة المهمة الرئيسية - بدون عرض +15 pts
  Widget _buildMissionCard(Map<String, dynamic> m) {
    final status = m['status'] as String;
    final statusCode = m['statusCode'] as String? ?? 'en_route';
    final isEnCours = status == 'en_cours';
    final isAnnule = status == 'annule';
    final isTermine = status == 'termine';
    
    final donId = m['donId'];
    final alreadyFullyRated = _fullyEvaluatedDonations.contains(donId);
    final hasRatedAssoc = m['hasEvaluatedAssociation'] == true;
    final hasRatedDonor = m['hasEvaluatedDonor'] == true;

    Color borderColor = _green;
    Color statusColor = _green;
    Color statusBg = _greenPale;
    IconData statusIcon = Icons.check_circle;

    if (isEnCours) {
      borderColor = _blue;
      statusColor = _blue;
      statusBg = _blueBg;
      statusIcon = Icons.sync;
    } else if (isAnnule) {
      borderColor = _red;
      statusColor = _red;
      statusBg = _redBg;
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isAnnule ? _redBg : (isEnCours ? _blueBg : _greenPale),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(m['icon'], style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['assoc'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: _subText),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 11),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    m['statusLabel'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ✅ تمت إزالة عرض +15 pts نهائياً
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          m['date'],
                          style: const TextStyle(fontSize: 9, color: _subText),
                        ),
                      ],
                    ),
                  ],
                ),

                if (statusCode == 'en_route') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _accepterMission(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_greenDark, _green]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('Accepter',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _refuserMission(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _redBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _red, width: 1),
                            ),
                            child: Center(
                              child: Text('Refuser',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _red)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (statusCode == 'en_livraison') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => _showCodeDialog(m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_greenDark, _green]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open_outlined, color: Colors.white, size: 15),
                              SizedBox(width: 6),
                              Text('Récupéré chez donateur',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (statusCode == 'recu_par_benevole') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _orange),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_run, color: _orange, size: 15),
                            SizedBox(width: 6),
                            Text('En route vers l\'association...',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _orange)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                if (isTermine) ...[
                  const SizedBox(height: 10),
                  if (!alreadyFullyRated) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showEvaluationDialog(m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF9A825), Color(0xFFFF8F00)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text('Évaluer',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasRatedAssoc || hasRatedDonor) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasRatedAssoc ? Icons.check_circle : Icons.pending,
                              size: 12,
                              color: hasRatedAssoc ? _green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Association ${hasRatedAssoc ? "✓" : "⏳"}',
                              style: TextStyle(fontSize: 9, color: hasRatedAssoc ? _green : _subText),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              hasRatedDonor ? Icons.check_circle : Icons.pending,
                              size: 12,
                              color: hasRatedDonor ? _green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Donateur ${hasRatedDonor ? "✓" : "⏳"}',
                              style: TextStyle(fontSize: 9, color: hasRatedDonor ? _green : _subText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _green, width: 1),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: _green, size: 14),
                            SizedBox(width: 6),
                            Text('✅ Évaluations complètes',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _green)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCodeDialog(Map<String, dynamic> mission) {
    final codeController = TextEditingController();
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 4,
                    decoration: BoxDecoration(color: _divider, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: _greenPale,
                    shape: BoxShape.circle,
                    border: Border.all(color: _green, width: 2),
                  ),
                  child: const Icon(Icons.lock_open, color: _green, size: 30),
                ),
                const SizedBox(height: 14),
                const Text('Code de remise',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 6),
                const Text('Demandez le code 4 chiffres au donateur',
                    style: TextStyle(fontSize: 12, color: _subText)),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _green, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                      letterSpacing: 12,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                      hintText: '••••',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 32, letterSpacing: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      final enteredCode = codeController.text.trim();
                      if (enteredCode.length != 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Entrez un code à 4 chiffres'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      setModalState(() => isVerifying = true);
                      try {
                        final donDoc = await FirebaseFirestore.instance
                            .collection('dons').doc(mission['donId']).get();
                        final correctCode = donDoc.data()?['pickupCode'] as String? ?? '';
                        final codeUsed   = donDoc.data()?['pickupCodeUsed'] as bool? ?? false;

                        if (codeUsed) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('⚠️ Ce code a déjà été utilisé'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        if (enteredCode == correctCode) {
                          final user = FirebaseAuth.instance.currentUser;
                          final benName = (await FirebaseFirestore.instance
                              .collection('users').doc(user?.uid).get())
                              .data()?['name'] ?? 'Bénévole';

                          await FirebaseFirestore.instance
                              .collection('dons').doc(mission['donId']).update({
                            'status': 'recu_par_benevole',
                            'pickupCodeUsed': true,
                            'pickupConfirmedAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (mission['associationId'].toString().isNotEmpty) {
                            await NotificationService.sendNotificationToUser(
                              userId: mission['associationId'],
                              title: '📦 Le bénévole arrive !',
                              body: '$benName est en route vers votre association avec "${mission['title'].split('—').first.trim()}"',
                              type: 'benevole_en_route',
                              extraData: {'donId': mission['donId']},
                            );
                          }

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Code vérifié ! En route vers l\'association'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          await _loadMissions();
                        } else {
                          setModalState(() => isVerifying = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('❌ Code incorrect'), backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isVerifying = false);
                        debugPrint('❌ $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isVerifying
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Vérifier le code',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: _subText)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEvaluationDialog(Map<String, dynamic> mission) {
    final String associationName = mission['associationName']?.toString().isNotEmpty == true
        ? mission['associationName']
        : 'Association';
    final String donorName = mission['donorName']?.toString().isNotEmpty == true
        ? mission['donorName']
        : 'Donateur';
    
    final hasRatedAssoc = mission['hasEvaluatedAssociation'] == true;
    final hasRatedDonor = mission['hasEvaluatedDonor'] == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Évaluer votre expérience',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textDark)),
            const SizedBox(height: 8),
            Text('Mission : ${mission['title']}',
                style: const TextStyle(fontSize: 12, color: _subText)),
            const SizedBox(height: 20),

            if (!hasRatedAssoc)
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EvaluateAssociationScreen(
                        associationName: associationName,
                        missionTitle: mission['title'],
                        quantity: mission['quantity'],
                        associationId: mission['associationId'],
                        donationId: mission['donId'],
                      ),
                    ),
                  );
                  if (result == true) {
                    await _loadMissions();
                    await _loadPoints();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _greenPale,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.people, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Évaluer l'association",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                            Text(associationName,
                                style: const TextStyle(fontSize: 11, color: _subText)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: _subText),
                    ],
                  ),
                ),
              ),

            if (!hasRatedAssoc) const SizedBox(height: 12),

            if (!hasRatedDonor)
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EvaluateDonorScreen(
                        donorName: donorName,
                        missionTitle: mission['title'],
                        quantity: mission['quantity'],
                        donorId: mission['donorId'],
                        donationId: mission['donId'],
                      ),
                    ),
                  );
                  if (result == true) {
                    await _loadMissions();
                    await _loadPoints();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _blueBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _blue, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.store, color: Colors.white, size: 28),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Évaluer le donateur',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
                            Text(donorName,
                                style: const TextStyle(fontSize: 11, color: _subText)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: _subText),
                    ],
                  ),
                ),
              ),

            if (hasRatedAssoc && hasRatedDonor) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: _green, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Vous avez déjà évalué les deux parties !',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _green)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer', style: TextStyle(fontSize: 13, color: _subText)),
            ),
            const SizedBox(height: 8),
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
          const Text('📋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Aucune mission',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textDark)),
          const SizedBox(height: 6),
          const Text('Acceptez des missions depuis le dashboard',
              style: TextStyle(fontSize: 12, color: _subText)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadMissions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _greenPale,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _green),
              ),
              child: const Text('🔄 Actualiser',
                  style: TextStyle(fontSize: 13, color: _greenDark, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}