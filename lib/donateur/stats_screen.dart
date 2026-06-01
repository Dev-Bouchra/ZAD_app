// 📄 lib/donateur/stats_screen.dart
// ✅ إصلاح جذري: كل الإحصائيات من collection dons حقيقية
// ✅ donorType من collection users (مع fallback 'Donateur')

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'home_screen.dart';
import '../shared/zad_colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _period = 2; // 0=Ce mois, 1=Cette année, 2=Total
  final _periods = ['Ce mois', 'Cette année', 'Total'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;

  // ✅ نوع الدوناتور من Firestore
  String _donorType = 'Donateur';

  Map<String, dynamic> _stats = {
    'totalDons': 0,
    'donsLivres': 0,
    'noteMoyenne': 0.0,
    'nourritureSauveeKg': 0.0,
    'donsParSemaine': <int>[0, 0, 0, 0],
    'donsParMois': <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'donsParType': <String, int>{},
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ✅ 1. جلب نوع الدوناتور من users
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      // ✅ الحل الجذري لـ donorType: إذا غير موجود → 'Donateur'
      _donorType = userData['donorType']?.toString().isNotEmpty == true
          ? userData['donorType']
          : 'Donateur';

      // ✅ 2. جلب كل الدونات من collection dons (مش offres!)
      final donsSnap = await _firestore
          .collection('dons')
          .where('donorId', isEqualTo: uid)
          .get();

      final dons = donsSnap.docs;

      // ✅ 3. الدونات المسلمة: status == 'livre'
      final donsLivres = dons.where((doc) {
        final s = doc.data()['status']?.toString() ?? '';
        return s == 'livre';
      }).toList();

      // ✅ 4. حساب الكيلوغرامات الحقيقية من quantity
      double nourritureSauveeKg = 0.0;
      for (var doc in donsLivres) {
        final data = doc.data();
        final qty = data['quantity']?.toString() ?? '';
        final qtyNum =
            double.tryParse(qty.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (qtyNum > 0) {
          nourritureSauveeKg += qtyNum;
        } else {
          // تقدير حسب نوع التبرع
          final title = (data['title'] ?? '').toString().toLowerCase();
          if (title.contains('pain')) {
            nourritureSauveeKg += 0.5;
          } else if (title.contains('repas')) {
            nourritureSauveeKg += 1.0;
          } else if (title.contains('boisson')) {
            nourritureSauveeKg += 0.3;
          } else {
            nourritureSauveeKg += 0.4;
          }
        }
      }

      // ✅ 5. التقييم الحقيقي من collection ratings
      final ratingsSnap = await _firestore
          .collection('ratings')
          .where('donorId', isEqualTo: uid)
          .get();

      double noteMoyenne = 0.0;
      if (ratingsSnap.docs.isNotEmpty) {
        double total = 0.0;
        for (var doc in ratingsSnap.docs) {
          final raw = doc.data()['note'] ?? doc.data()['rating'] ?? 0;
          total += (raw is num) ? raw.toDouble() : 0.0;
        }
        noteMoyenne = total / ratingsSnap.docs.length;
      } else {
        // fallback: rating من users
        final userRating = userData['rating'];
        if (userRating is num) noteMoyenne = userRating.toDouble();
      }

      // ✅ 6. الدونات حسب الأسبوع (الشهر الحالي)
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final donsParSemaine = [0, 0, 0, 0];

      for (var doc in dons) {
        final ts = doc.data()['createdAt'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        if (date.isAfter(firstDayOfMonth)) {
          final weekIndex = ((date.day - 1) / 7).floor().clamp(0, 3);
          donsParSemaine[weekIndex]++;
        }
      }

      // ✅ 7. الدونات حسب الشهر (السنة الحالية)
      final donsParMois = List.filled(12, 0);
      for (var doc in dons) {
        final ts = doc.data()['createdAt'];
        if (ts is! Timestamp) continue;
        final date = ts.toDate();
        if (date.year == now.year) {
          donsParMois[date.month - 1]++;
        }
      }

      // ✅ 8. الدونات حسب النوع (من title)
      final donsParType = <String, int>{};
      for (var doc in dons) {
        final data = doc.data();
        final title = data['title']?.toString() ?? '';
        final label = _getTypeLabel(title);
        donsParType[label] = (donsParType[label] ?? 0) + 1;
      }

      setState(() {
        _stats = {
          'totalDons': dons.length,
          'donsLivres': donsLivres.length,
          'noteMoyenne': noteMoyenne,
          'nourritureSauveeKg': nourritureSauveeKg,
          'donsParSemaine': donsParSemaine,
          'donsParMois': donsParMois,
          'donsParType': donsParType,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur stats: $e");
      setState(() => _isLoading = false);
    }
  }

  // ✅ تصنيف حسب title من dons
  String _getTypeLabel(String title) {
    final t = title.toLowerCase();
    if (t.contains('pain') || t.contains('boulangerie')) return 'Pain 🍞';
    if (t.contains('fast') || t.contains('pizza') || t.contains('burger'))
      return 'Fast-food 🍕';
    if (t.contains('repas') || t.contains('plat')) return 'Repas 🍲';
    if (t.contains('boisson') || t.contains('jus')) return 'Boisson 🥤';
    if (t.contains('conserve')) return 'Conserve 🥫';
    if (t.contains('biscuit') || t.contains('gâteau')) return 'Biscuit 🍪';
    if (t.contains('légume') || t.contains('fruit')) return 'Légumes 🥦';
    if (t.isNotEmpty) return title;
    return 'Autre 🎁';
  }

  List<Map<String, dynamic>> _getChartData() {
    if (_period == 0) {
      final values = _stats['donsParSemaine'] as List<int>;
      return List.generate(
          4, (i) => {'label': 'S${i + 1}', 'value': values[i]});
    } else if (_period == 1) {
      const months = [
        'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
        'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
      ];
      final values = _stats['donsParMois'] as List<int>;
      return List.generate(
          12, (i) => {'label': months[i], 'value': values[i]});
    } else {
      final types = _stats['donsParType'] as Map<String, int>;
      final total = types.values.fold(0, (s, v) => s + v);
      return types.entries
          .map((e) => {
                'label': e.key,
                'value': e.value,
                'percentage': total > 0 ? e.value / total : 0.0,
              })
          .toList();
    }
  }

  Color _getTypeColor(String type) {
    if (type.contains('Pain')) return ZADColors.primary;
    if (type.contains('Fast')) return ZADColors.accentOrange;
    if (type.contains('Repas')) return ZADColors.success;
    if (type.contains('Boisson')) return Colors.blue;
    if (type.contains('Conserve')) return Colors.orange;
    if (type.contains('Biscuit')) return Colors.brown;
    if (type.contains('Légume')) return Colors.green;
    return ZADColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          // ─── Header ──────────────────────────────────────────────────────
          Container(
            color: ZADColors.headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                        const Expanded(
                          child: Text('Statistiques',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ),
                        GestureDetector(
                          onTap: _loadStats,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.refresh,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ✅ نوع الدوناتور الحقيقي
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store_outlined,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _donorType,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // إحصائيات الهيدر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatMini(
                            value: '${_stats['totalDons']}',
                            label: 'Dons publiés'),
                        _StatMini(
                            value: '${_stats['donsLivres']}',
                            label: 'Dons livrés'),
                        _StatMini(
                            value:
                                '${(_stats['nourritureSauveeKg'] as double).toStringAsFixed(1)} kg',
                            label: 'Sauvés'),
                        _StatMini(
                            value:
                                '${(_stats['noteMoyenne'] as double).toStringAsFixed(1)}⭐',
                            label: 'Note moy.'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Filtres période ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              children: List.generate(
                _periods.length,
                (i) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _period = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _period == i
                            ? ZADColors.primary
                            : ZADColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _periods[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _period == i
                              ? Colors.white
                              : ZADColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── المحتوى ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: ZADColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadStats,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ✅ مخطط حسب الفترة
                          _ChartCard(
                            title: _period == 0
                                ? 'Dons par semaine (ce mois)'
                                : _period == 1
                                    ? 'Dons par mois (cette année)'
                                    : 'Dons par type de produit',
                            data: _getChartData(),
                            compact: _period == 1,
                          ),
                          const SizedBox(height: 16),

                          // ✅ التفاصيل في وضع Total
                          if (_period == 2) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3))
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Répartition par type',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: ZADColors.textDark)),
                                  const SizedBox(height: 16),
                                  ...(_stats['donsParType']
                                          as Map<String, int>)
                                      .entries
                                      .map((e) {
                                    final total = (_stats['donsParType']
                                            as Map<String, int>)
                                        .values
                                        .fold(0, (s, v) => s + v);
                                    final pct =
                                        total > 0 ? e.value / total : 0.0;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _BarRow(
                                        label: e.key,
                                        percentage: pct,
                                        color: _getTypeColor(e.key),
                                        value: e.value,
                                      ),
                                    );
                                  }).toList(),
                                  if ((_stats['donsParType']
                                          as Map<String, int>)
                                      .isEmpty)
                                    const Center(
                                      child: Text(
                                          'Aucune donnée disponible',
                                          style: TextStyle(
                                              color: ZADColors.textLight)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ✅ بطاقة ملخص
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Résumé',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: ZADColors.textDark)),
                                const SizedBox(height: 14),
                                _SummaryRow(
                                  icon: Icons.volunteer_activism,
                                  color: ZADColors.primary,
                                  label: 'Total dons publiés',
                                  value: '${_stats['totalDons']}',
                                ),
                                _SummaryRow(
                                  icon: Icons.check_circle_outline,
                                  color: ZADColors.success,
                                  label: 'Dons livrés avec succès',
                                  value: '${_stats['donsLivres']}',
                                ),
                                _SummaryRow(
                                  icon: Icons.eco,
                                  color: Colors.green,
                                  label: 'Nourriture sauvée',
                                  value:
                                      '${(_stats['nourritureSauveeKg'] as double).toStringAsFixed(1)} kg',
                                ),
                                _SummaryRow(
                                  icon: Icons.star_outline,
                                  color: ZADColors.accentOrange,
                                  label: 'Note moyenne',
                                  value:
                                      '${(_stats['noteMoyenne'] as double).toStringAsFixed(1)} / 5',
                                ),
                                _SummaryRow(
                                  icon: Icons.store_outlined,
                                  color: ZADColors.accent,
                                  label: 'Type de donateur',
                                  // ✅ نوع الدوناتور الحقيقي
                                  value: _donorType,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: ZADColors.textMedium)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final bool compact;

  const _ChartCard(
      {required this.title, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final hasData =
        data.isNotEmpty && data.any((d) => (d['value'] as int) > 0);

    if (!hasData) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: ZADColors.textDark)),
            const SizedBox(height: 16),
            const Center(
              child: Text('Aucune donnée pour cette période',
                  style: TextStyle(color: ZADColors.textLight)),
            ),
          ],
        ),
      );
    }

    const double totalH = 140;
    const double labelH = 16;
    const double valueH = 14;
    const double gapH = 10;
    final double barAreaH =
        totalH - labelH - (compact ? 0 : valueH) - gapH;
    final maxVal =
        data.map((d) => d['value'] as int).reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ZADColors.textDark)),
          const SizedBox(height: 16),
          SizedBox(
            height: totalH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < data.length; i++) ...[
                  if (i != 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Bar(
                      value: data[i]['value'] as int,
                      label: data[i]['label'] as String,
                      maxVal: maxVal,
                      barAreaH: barAreaH,
                      labelH: labelH,
                      valueH: valueH,
                      compact: compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int value;
  final String label;
  final int maxVal;
  final double barAreaH;
  final double labelH;
  final double valueH;
  final bool compact;

  const _Bar({
    required this.value,
    required this.label,
    required this.maxVal,
    required this.barAreaH,
    required this.labelH,
    required this.valueH,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final double barH = maxVal > 0 ? barAreaH * (value / maxVal) : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!compact && value > 0)
          SizedBox(
            height: valueH,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ZADColors.primary)),
          ),
        Container(
          height: barH > 0 ? barH : 2,
          decoration: BoxDecoration(
            color: value > 0 ? ZADColors.primary : ZADColors.divider,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ),
        SizedBox(
          height: labelH,
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: compact ? 9 : 11,
                  color: ZADColors.textMedium,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _StatMini extends StatelessWidget {
  final String value;
  final String label;
  const _StatMini({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;
  final int value;

  const _BarRow({
    required this.label,
    required this.percentage,
    required this.color,
    this.value = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: ZADColors.textDark)),
            Text('$value (${(percentage * 100).toInt()}%)',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}
