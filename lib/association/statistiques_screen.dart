// lib/screens/association/statistiques_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
}

class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  String _period = 'Ce mois';
  final List<String> _periods = ['7 jours', 'Ce mois', '3 mois', 'Année'];

  int _totalDons = 0;
  int _totalRepas = 0;
  int _totalBeneficiaires = 0;
  double _totalKg = 0;
  List<Map<String, dynamic>> _chartData = [];
  Map<String, double> _donTypes = {};
  List<Map<String, dynamic>> _topBenevoles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStats();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_period) {
      case '7 jours':
        return now.subtract(const Duration(days: 7));
      case 'Ce mois':
        return DateTime(now.year, now.month, 1);
      case '3 mois':
        return DateTime(now.year, now.month - 3, 1);
      case 'Année':
        return DateTime(now.year, 1, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final startDate = _getStartDate();

      final donsSnapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('status', whereIn: ['accepte_par_association', 'en_route', 'livre'])
          .get();

      final dons = donsSnapshot.docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(startDate);
      }).toList();

      _totalDons = dons.length;
      _totalKg = 0;
      _totalRepas = 0;
      _donTypes = {};

      for (var doc in dons) {
        final data = doc.data();
        final title = data['title']?.toLowerCase() ?? '';
        final quantity = data['quantity'] ?? '';
        
        if (quantity.contains('kg')) {
          final kg = double.tryParse(quantity.replaceAll('kg', '').trim());
          if (kg != null) _totalKg += kg;
        } else if (quantity.contains('portion')) {
          final portions = int.tryParse(quantity.replaceAll('portion', '').trim());
          if (portions != null) _totalRepas += portions;
        }
        
        if (title.contains('pain')) {
          _donTypes['Pain'] = (_donTypes['Pain'] ?? 0) + 1;
        } else if (title.contains('plat') || title.contains('repas')) {
          _donTypes['Repas'] = (_donTypes['Repas'] ?? 0) + 1;
        } else {
          _donTypes['Alimentaire'] = (_donTypes['Alimentaire'] ?? 0) + 1;
        }
      }

      final totalTypes = _donTypes.values.reduce((a, b) => a + b);
      if (totalTypes > 0) {
        _donTypes.forEach((key, value) {
          _donTypes[key] = (value / totalTypes) * 100;
        });
      }

      // بناء البيانات حسب الفترة
      _chartData = [];
      final now = DateTime.now();
      
      if (_period == '7 jours') {
        // 7 أيام
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
          final dayEnd = dayStart.add(const Duration(days: 1));
          final dayCount = dons.where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(dayStart) && createdAt.isBefore(dayEnd);
          }).length;
          final dayName = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'][day.weekday % 7];
          _chartData.add({
            'label': dayName,
            'value': dayCount,
          });
        }
      } else if (_period == 'Ce mois') {
        // 4 أسابيع
        for (int i = 3; i >= 0; i--) {
          final weekStart = now.subtract(Duration(days: i * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final weekCount = dons.where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(weekStart) && createdAt.isBefore(weekEnd);
          }).length;
          _chartData.add({
            'label': 'S${4 - i}',
            'value': weekCount,
          });
        }
      } else if (_period == '3 mois') {
        // 12 أسبوع
        for (int i = 11; i >= 0; i--) {
          final weekStart = now.subtract(Duration(days: i * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final weekCount = dons.where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(weekStart) && createdAt.isBefore(weekEnd);
          }).length;
          _chartData.add({
            'label': 'S${12 - i}',
            'value': weekCount,
          });
        }
      } else if (_period == 'Année') {
        // 12 شهر
        for (int i = 11; i >= 0; i--) {
          final monthStart = DateTime(now.year, now.month - i, 1);
          final monthEnd = DateTime(now.year, now.month - i + 1, 1);
          final monthCount = dons.where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            return createdAt != null && createdAt.isAfter(monthStart) && createdAt.isBefore(monthEnd);
          }).length;
          final monthName = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'][(now.month - i - 1) % 12];
          _chartData.add({
            'label': monthName,
            'value': monthCount,
          });
        }
      }

      final benevolesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'benevole')
          .get();

      final benevoles = benevolesSnapshot.docs;
      List<Map<String, dynamic>> benevoleMissions = [];

      for (var benevole in benevoles) {
        final missionsCount = await FirebaseFirestore.instance
            .collection('dons')
            .where('volunteerId', isEqualTo: benevole.id)
            .where('status', isEqualTo: 'livre')
            .get();
        
        final missionsInPeriod = missionsCount.docs.where((doc) {
          final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
          return createdAt != null && createdAt.isAfter(startDate);
        }).toList();
        
        benevoleMissions.add({
          'nom': benevole.data()['name'] ?? 'Bénévole',
          'missions': missionsInPeriod.length,
        });
      }

      benevoleMissions.sort((a, b) => b['missions'].compareTo(a['missions']));
      _topBenevoles = benevoleMissions.where((b) => b['missions'] > 0).take(3).toList();

      _totalBeneficiaires = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'beneficiaire')
          .get()
          .then((snap) => snap.docs.length);

    } catch (e) {
      print('❌ Erreur stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ZadColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final maxVal = _chartData.isEmpty ? 1 : _chartData.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: ZadColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Statistiques',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periods.map((p) {
                        final active = _period == p;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _period = p;
                              _loadStats();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: active ? ZadColors.leafGreen : ZadColors.cardBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                color: active ? Colors.white : ZadColors.labelGrey,
                                fontSize: 13,
                                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ZadColors.leafGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IMPACT TOTAL $_period',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_totalKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'de nourriture sauvée',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ImpactStat(value: '$_totalDons', label: 'Dons reçus'),
                            _ImpactStat(value: '$_totalRepas', label: 'Aides données'),
                            _ImpactStat(value: '$_totalBeneficiaires', label: 'Bénéficiaires'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZadColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _period == '7 jours' ? 'Dons reçus par jour' : 'Dons reçus par semaine',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ZadColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 120,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _chartData.map((d) {
                              final ratio = d['value'] / maxVal;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    width: _period == 'Année' ? 20 : 20,
                                    height: (100 * ratio).toDouble(),
                                    decoration: BoxDecoration(
                                      color: d['value'] == maxVal && maxVal > 0
                                          ? ZadColors.leafGreen
                                          : ZadColors.leafGreen.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    d['label'],
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: ZadColors.labelGrey,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZadColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Types de dons reçus',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ZadColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_donTypes.containsKey('Pain'))
                          _TypeBar(
                            label: 'Pain',
                            percent: (_donTypes['Pain'] ?? 0) / 100,
                            color: const Color(0xFF2E7D32),
                          ),
                        if (_donTypes.containsKey('Repas'))
                          const SizedBox(height: 10),
                        if (_donTypes.containsKey('Repas'))
                          _TypeBar(
                            label: 'Repas',
                            percent: (_donTypes['Repas'] ?? 0) / 100,
                            color: const Color(0xFF1565C0),
                          ),
                        if (_donTypes.containsKey('Alimentaire'))
                          const SizedBox(height: 10),
                        if (_donTypes.containsKey('Alimentaire'))
                          _TypeBar(
                            label: 'Alimentaire',
                            percent: (_donTypes['Alimentaire'] ?? 0) / 100,
                            color: const Color(0xFFE65100),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ZadColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top bénévoles $_period',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ZadColors.darkNavy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_topBenevoles.isNotEmpty)
                          for (int i = 0; i < _topBenevoles.length; i++)
                            _TopBenevole(
                              rang: i + 1,
                              nom: _topBenevoles[i]['nom'],
                              missions: _topBenevoles[i]['missions'],
                            ),
                        if (_topBenevoles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Aucune mission terminée',
                                style: TextStyle(color: ZadColors.labelGrey),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          _BottomNav(active: 0),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final String value;
  final String label;
  const _ImpactStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
        ),
      ],
    );
  }
}

class _TypeBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  const _TypeBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: ZadColors.darkNavy),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(percent * 100).toInt()}%',
          style: const TextStyle(fontSize: 12, color: ZadColors.labelGrey),
        ),
      ],
    );
  }
}

class _TopBenevole extends StatelessWidget {
  final int rang;
  final String nom;
  final int missions;
  const _TopBenevole({
    required this.rang,
    required this.nom,
    required this.missions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rang == 1 ? const Color(0xFFFFB800) : ZadColors.cardBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: rang == 1 ? Colors.white : ZadColors.labelGrey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nom,
              style: const TextStyle(
                fontSize: 13,
                color: ZadColors.darkNavy,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$missions missions',
            style: const TextStyle(fontSize: 12, color: ZadColors.labelGrey),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int active;
  const _BottomNav({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            active: active == 0,
            onTap: () => Navigator.pushNamed(context, '/home'),
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Bénéficiaires',
            active: active == 1,
            onTap: () => Navigator.pushNamed(context, '/beneficiaires'),
          ),
          _NavItem(
            icon: Icons.volunteer_activism,
            label: 'Dons',
            active: active == 2,
            onTap: () => Navigator.pushNamed(context, '/dons'),
          ),
          _NavItem(
            icon: Icons.chat_outlined,
            label: 'Chat',
            active: active == 3,
            onTap: () => Navigator.pushNamed(context, '/chat'),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profil',
            active: active == 4,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? ZadColors.leafGreen : ZadColors.labelGrey,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? ZadColors.leafGreen : ZadColors.labelGrey,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}