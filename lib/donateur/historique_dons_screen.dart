import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../shared/zad_colors.dart';

class HistoriqueDonsScreen extends StatefulWidget {
  const HistoriqueDonsScreen({super.key});

  @override
  State<HistoriqueDonsScreen> createState() => _HistoriqueDonsScreenState();
}

class _HistoriqueDonsScreenState extends State<HistoriqueDonsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  int _totalDons = 0;
  int _totalLivres = 0;
  int _totalExpires = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('donorId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> donsList = [];
      int totalDons = 0, totalLivres = 0, totalExpires = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final statut = data['status'] ?? data['statut'] ?? 'En attente';
        final titre = data['title'] ?? data['titre'] ?? data['type'] ?? 'Offre';
        final quantite = data['quantity'] ?? data['quantite'] ?? '';
        final icon = data['icon'] ?? '';
        final type = data['type'] ?? 'Autre';
        final benevole = data['volunteerName'] ?? data['benevoleNom'];
        final rating = data['rating'];

        donsList.add({
          'id': doc.id,
          'emoji': _getEmojiForType(type, icon),
          'title': quantite.toString().isNotEmpty
              ? '$titre — $quantite'
              : titre,
          'date': _formatDate(data['createdAt']),
          'status': statut,
          // ✅ التعديل 1: إضافة 'livre' و 'refuse_par_association'
          'color': statut == 'Livré' || statut == 'delivered' || statut == 'livre'
              ? ZADColors.success
              : (statut == 'Expiré' || statut == 'expired' || statut == 'refuse_par_association'
                  ? ZADColors.danger
                  : ZADColors.warning),
          'benevole': benevole,
          'rating': rating,
        });

        // ✅ التعديل 2: إضافة 'livre' و 'refuse_par_association'
        totalDons++;
        if (statut == 'Livré' || statut == 'delivered' || statut == 'livre') totalLivres++;
        if (statut == 'Expiré' || statut == 'expired' || statut == 'refuse_par_association') totalExpires++;
      }

      setState(() {
        _history = donsList;
        _totalDons = totalDons;
        _totalLivres = totalLivres;
        _totalExpires = totalExpires;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur chargement historique: $e");
      setState(() => _isLoading = false);
    }
  }

  String _getEmojiForType(String type, String icon) {
    if (icon.isNotEmpty && icon.length <= 4) return icon;

    switch (type.toLowerCase()) {
      case 'pain':
        return '🍞';
      case 'legumes':
      case 'légumes':
        return '🥦';
      case 'fruits':
        return '🍎';
      case 'lait':
        return '🥛';
      case 'viande':
        return '🍖';
      case 'plat cuisine':
      case 'repas':
        return '🍲';
      case 'boisson':
        return '🥤';
      default:
        return '📦';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Date inconnue';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      date = DateTime.now();
    }

    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── Header ───────────────────────────────────────────────
                Container(
                  color: ZADColors.headerBg,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 18),
                          ),
                          const Expanded(
                            child: Text(
                              'Historique des dons',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 26),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Stats bar ────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HistoStat(value: '$_totalDons', label: 'Total dons'),
                      Container(
                          width: 1, height: 30, color: ZADColors.divider),
                      _HistoStat(value: '$_totalLivres', label: 'Livrés'),
                      Container(
                          width: 1, height: 30, color: ZADColors.divider),
                      _HistoStat(value: '$_totalExpires', label: 'Expirés'),
                    ],
                  ),
                ),

                // ─── List ─────────────────────────────────────────────────
                Expanded(
                  child: _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 64, color: ZADColors.textLight),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun don pour le moment',
                                style: TextStyle(
                                    color: ZADColors.textLight, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _history.length,
                          itemBuilder: (ctx, i) {
                            final item = _history[i];
                            final color = item['color'] as Color;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Emoji icon
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(item['emoji'] as String,
                                            style: const TextStyle(
                                                fontSize: 22)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Title + date + bénévole
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item['title'] as String,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: ZADColors.textDark)),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  color: ZADColors.textLight,
                                                  size: 11),
                                              const SizedBox(width: 4),
                                              Text(item['date'] as String,
                                                  style: const TextStyle(
                                                      color:
                                                          ZADColors.textLight,
                                                      fontSize: 11)),
                                              if (item['benevole'] !=
                                                  null) ...[
                                                const SizedBox(width: 8),
                                                const Text('·',
                                                    style: TextStyle(
                                                        color: ZADColors
                                                            .textLight)),
                                                const SizedBox(width: 8),
                                                Text(
                                                    item['benevole']
                                                        as String,
                                                    style: const TextStyle(
                                                        color:
                                                            ZADColors.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 11)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Status badge + rating
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(item['status'] as String,
                                              style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11)),
                                        ),
                                        if (item['rating'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star,
                                                  color:
                                                      ZADColors.accentYellow,
                                                  size: 12),
                                              const SizedBox(width: 2),
                                              Text('${item['rating']}',
                                                  style: const TextStyle(
                                                      color:
                                                          ZADColors.textMedium,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Widget: Stat header ──────────────────────────────────────────────────────

class _HistoStat extends StatelessWidget {
  final String value;
  final String label;

  const _HistoStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: ZADColors.primary)),
        Text(label,
            style:
                const TextStyle(color: ZADColors.textLight, fontSize: 12)),
      ],
    );
  }
}