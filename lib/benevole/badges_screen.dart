// ============================================================
// 📄 lib/screens/benevole/badges_screen.dart
// ✅ يجلب العروض من collection 'offres' - مع إصلاح مشكلة عدم الظهور
// ✅ يُظهر النقاط المطلوبة التي حددها المتبرع بوضوح
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'coupon_qrcode_screen.dart';
import 'dashboard_screen.dart';

class BenevoleBadgesScreen extends StatefulWidget {
  const BenevoleBadgesScreen({super.key});

  @override
  State<BenevoleBadgesScreen> createState() => _BenevoleBadgesScreenState();
}

class _BenevoleBadgesScreenState extends State<BenevoleBadgesScreen> {
  static const _green     = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenBg   = Color(0xFFF1F8E9);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _orange    = Color(0xFFFF8F00);
  static const _gold      = Color(0xFFF9A825);
  static const _goldBg    = Color(0xFFFFFDE7);
  static const _divider   = Color(0xFFEEEEEE);
  static const _subText   = Color(0xFF757575);
  static const _textDark  = Color(0xFF1B1B1B);

  String _activeFilter = 'Tout';

  int    _userPoints         = 0;
  int    _missionsCompleted  = 0;
  int    _kgSaved            = 0;
  double _rating             = 0.0;
  bool   _isLoading          = true;

  List<Map<String, dynamic>> _recompenses = [];

  final List<Map<String, dynamic>> _niveaux = [
    {'emoji': '🥉', 'name': 'Débutant',  'pts': '0–99',    'min': 0,    'max': 99},
    {'emoji': '🥈', 'name': 'Engagé',    'pts': '100–499', 'min': 100,  'max': 499},
    {'emoji': '🥇', 'name': 'Champion',  'pts': '500–999', 'min': 500,  'max': 999},
    {'emoji': '⭐', 'name': 'Légende',   'pts': '1000+',   'min': 1000, 'max': 9999},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. جلب بيانات البينيفول
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userPoints       = (data['points']            ?? 0).toInt();
        _missionsCompleted = (data['missionsCompleted'] ?? 0).toInt();
        _kgSaved           = (data['kgSaved']           ?? 0).toInt();
        _rating            = (data['rating']            ?? 0.0).toDouble();
      }

      // ✅ 2. جلب كل العروض بدون فلتر (نتجنب مشكلة الـ index المركّب)
      //       ثم نُصفّي محلياً
      final offresSnap = await FirebaseFirestore.instance
          .collection('offres')
          .get();

      final List<Map<String, dynamic>> loaded = [];

      for (final doc in offresSnap.docs) {
        final data = doc.data();

        // ✅ تصفية محلية: نتجاهل العروض المنتهية (restants == 0)
        final int restants = (data['restants'] ?? 0) is int
            ? (data['restants'] ?? 0)
            : int.tryParse(data['restants'].toString()) ?? 0;
        if (restants == 0) continue;

        // ✅ النقاط المطلوبة التي حددها المتبرع
        final int required = (data['requiredPoints'] ?? 0) is int
            ? (data['requiredPoints'] ?? 0)
            : int.tryParse(data['requiredPoints'].toString()) ?? 0;

        final bool unlocked = _userPoints >= required;

        // حساب التقدم
        double progress      = 0.0;
        String progressLabel = '';
        String condition     = '';

        if (!unlocked) {
          progress = required > 0
              ? (_userPoints / required).clamp(0.0, 1.0)
              : 0.0;
          final remaining = required - _userPoints;
          progressLabel = '$_userPoints / $required pts';
          condition     = 'Encore $remaining pts pour débloquer';
        } else {
          progress      = 1.0;
          progressLabel = required == 0
              ? 'Disponible gratuitement'
              : '$required pts atteints ✓';
          condition     = 'Débloqué !';
        }

        final rawType    = data['type']?.toString() ?? 'reduction';
        final String mappedType = rawType == 'gratuit' ? 'meal' : 'discount';
        final String partnerName = data['partenaire']?.toString() ?? '';
        final String discount    = data['valeur']?.toString() ?? '';

        loaded.add({
          'id':             doc.id,
          'icon':           data['icon']           ?? '🎁',
          'title':          data['title']          ?? '',
          'partner':        partnerName,
          'partnerName':    partnerName,
          'type':           mappedType,
          'code':           data['code']           ?? '',
          'expiry':         data['expiry']         ?? 'Indéfiniment',
          'requiredPoints': required,
          'unlocked':       unlocked,
          'progress':       progress,
          'progressLabel':  progressLabel,
          'condition':      condition,
          'discount':       discount,
          'description':    data['description']    ?? '',
          'restants':       restants,
        });
      }

      // ترتيب: المفتوحة أولاً ثم المقفلة
      loaded.sort((a, b) {
        if (a['unlocked'] == b['unlocked']) {
          return (a['requiredPoints'] as int)
              .compareTo(b['requiredPoints'] as int);
        }
        return a['unlocked'] ? -1 : 1;
      });

      if (mounted) {
        setState(() {
          _recompenses = loaded;
          _isLoading   = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement badges: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> get _currentNiveau {
    for (final n in _niveaux.reversed) {
      if (_userPoints >= (n['min'] as int)) return n;
    }
    return _niveaux[0];
  }

  Map<String, dynamic>? get _nextNiveau {
    final current = _currentNiveau;
    final idx = _niveaux.indexOf(current);
    if (idx < _niveaux.length - 1) return _niveaux[idx + 1];
    return null;
  }

  double get _levelProgress {
    final current = _currentNiveau;
    final next    = _nextNiveau;
    if (next == null) return 1.0;
    final min = current['min'] as int;
    final max = next['min']    as int;
    return ((_userPoints - min) / (max - min)).clamp(0.0, 1.0);
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_activeFilter) {
      case '🍽️ Repas':
        return _recompenses.where((r) => r['type'] == 'meal').toList();
      case '🏷️ Réductions':
        return _recompenses.where((r) => r['type'] == 'discount').toList();
      case '🔒 À débloquer':
        return _recompenses.where((r) => r['unlocked'] == false).toList();
      default:
        return _recompenses;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: _green,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildNiveaux(),
                          _buildFilterRow(),
                          _buildRecompensesList(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final current    = _currentNiveau;
    final next       = _nextNiveau;
    final ptsForNext = next != null ? next['min'] as int : null;
    final remaining  = ptsForNext != null ? ptsForNext - _userPoints : 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), _greenDark, _green],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x554CAF50), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        bottom: 20, left: 18, right: 18,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const BenevoleDashboardScreen()),
                ),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2), shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Badges & Récompenses',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 16,
                      fontWeight: FontWeight.w700, color: Colors.white,
                    )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${current['emoji']} ${current['name']}',
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 11,
                    color: Colors.white, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⭐ $_userPoints pts',
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 28,
                          fontWeight: FontWeight.w700, color: Colors.white,
                        )),
                    const Text('Vos points de bénévolat',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 11, color: Colors.white70,
                        )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_missionsCompleted missions',
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12,
                        color: Colors.white, fontWeight: FontWeight.w600,
                      )),
                  Text('$_kgSaved kg sauvés',
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, color: Colors.white70,
                      )),
                  Text('⭐ ${_rating.toStringAsFixed(1)} / 5',
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 11, color: Colors.white70,
                      )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _levelProgress,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_userPoints / ${ptsForNext ?? '∞'} pts',
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 9, color: Colors.white60,
                      )),
                  if (next != null)
                    Text('$remaining pts pour ${next['emoji']} ${next['name']}',
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 9, color: Colors.white60,
                        ))
                  else
                    const Text('Niveau maximum atteint ! 🏆',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 9, color: Colors.white60,
                        )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNiveaux() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Niveaux',
              style: TextStyle(
                fontFamily: 'Poppins', fontSize: 14,
                fontWeight: FontWeight.w700, color: _textDark,
              )),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:       _niveaux.length,
              itemBuilder: (_, i) {
                final n         = _niveaux[i];
                final isCurrent = n['name'] == _currentNiveau['name'];
                final isDone    = _userPoints > (n['max'] as int);
                final isLocked  = !isCurrent && !isDone;
                return AnimatedContainer(
                  duration:  const Duration(milliseconds: 200),
                  width:     80,
                  margin:    const EdgeInsets.only(right: 10),
                  padding:   const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrent ? _greenPale : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent ? _green : _divider,
                      width: isCurrent ? 2 : 1.5,
                    ),
                    boxShadow: isCurrent
                        ? [BoxShadow(color: _green.withOpacity(0.2), blurRadius: 8)]
                        : [],
                  ),
                  child: Opacity(
                    opacity: isLocked ? 0.45 : 1.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(n['emoji'], style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(n['name'],
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isCurrent ? _greenDark : _textDark,
                            )),
                        Text(n['pts'],
                            style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 8, color: _subText,
                            )),
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

  Widget _buildFilterRow() {
    final filters = ['Tout', '🍽️ Repas', '🏷️ Réductions', '🔒 À débloquer'];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:         const EdgeInsets.symmetric(horizontal: 16),
          itemCount:       filters.length,
          itemBuilder: (_, i) {
            final active = _activeFilter == filters[i];
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:   const EdgeInsets.only(right: 8),
                padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(colors: [_greenDark, _green])
                      : null,
                  color:        active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(
                    color: active ? _green : _divider, width: 1.5,
                  ),
                  boxShadow: active
                      ? [BoxShadow(
                          color: _green.withOpacity(0.3),
                          blurRadius: 8, offset: const Offset(0, 3),
                        )]
                      : [],
                ),
                child: Text(filters[i],
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 11,
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

  Widget _buildRecompensesList() {
    final list = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: _green, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Mes récompenses',
                  style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 15,
                    fontWeight: FontWeight.w700, color: _textDark,
                  )),
              const Spacer(),
              // ✅ عداد العروض المتاحة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _greenPale, borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${list.length} offres',
                    style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 10,
                      fontWeight: FontWeight.w600, color: _greenDark,
                    )),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Icon(Icons.card_giftcard, size: 64, color: _subText),
                const SizedBox(height: 12),
                Text(
                  _activeFilter == 'Tout'
                      ? 'Aucune récompense disponible'
                      : 'Aucune récompense dans cette catégorie',
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, color: _subText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...list.map((r) => _buildRecompenseCard(r)),
      ],
    );
  }

  Widget _buildRecompenseCard(Map<String, dynamic> r) {
    final unlocked      = r['unlocked'] as bool;
    final isMeal        = r['type'] == 'meal';
    final requiredPts   = r['requiredPoints'] as int;

    final Color borderColor = unlocked ? (isMeal ? _gold : _green) : _divider;

    String badgeText;
    Color  badgeBg;
    Color  badgeFg;
    if (unlocked) {
      if (isMeal) {
        badgeText = '🍽️ Gratuit';
        badgeBg   = _goldBg;
        badgeFg   = _gold;
      } else {
        final discount = r['discount']?.toString() ?? '';
        badgeText = '🏷️ ${discount.isNotEmpty ? discount : 'Réduction'}';
        badgeBg   = _greenPale;
        badgeFg   = _greenDark;
      }
    } else {
      badgeText = '🔒 Bientôt';
      badgeBg   = const Color(0xFFF5F5F5);
      badgeFg   = _subText;
    }

    return Opacity(
      opacity: unlocked ? 1.0 : 0.75,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color:      borderColor.withOpacity(0.15),
              blurRadius: 14, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // شريط علوي ملوّن
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: unlocked
                      ? (isMeal ? [_gold, const Color(0xFFFBC02D)] : [_greenDark, _green])
                      : [_divider, _divider],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: unlocked
                                ? (isMeal
                                    ? [_goldBg, const Color(0xFFFFF9C4)]
                                    : [_greenPale, _greenBg])
                                : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(r['icon'],
                              style: TextStyle(
                                fontSize: 26,
                                color: unlocked ? null : Colors.grey,
                              )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['title'],
                                style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 13,
                                  fontWeight: FontWeight.w700, color: _textDark,
                                )),
                            const SizedBox(height: 2),
                            Text(r['partner'],
                                style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 10, color: _subText,
                                )),
                            if ((r['description'] as String).isNotEmpty)
                              Text(r['description'],
                                  style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 9, color: _subText,
                                  )),
                            const SizedBox(height: 4),
                            // ✅ عرض النقاط المطلوبة بشكل واضح دائماً
                            Row(
                              children: [
                                Icon(
                                  unlocked ? Icons.star : Icons.star_border,
                                  size: 13,
                                  color: unlocked ? _gold : _subText,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  requiredPts == 0
                                      ? 'Disponible gratuitement'
                                      : '$requiredPts pts requis',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize:   10,
                                    fontWeight: FontWeight.w700,
                                    color: unlocked
                                        ? (isMeal ? _gold : _greenDark)
                                        : _subText,
                                  ),
                                ),
                                if (unlocked) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _greenPale,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('✓ Débloqué',
                                        style: TextStyle(
                                          fontFamily: 'Poppins', fontSize: 8,
                                          fontWeight: FontWeight.w600, color: _greenDark,
                                        )),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg, borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badgeText,
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 9,
                              fontWeight: FontWeight.w700, color: badgeFg,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // معلومات إضافية: العدد المتبقي + تاريخ الانتهاء
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 11, color: _subText),
                        const SizedBox(width: 3),
                        Text(
                          r['restants'] == -1
                              ? 'Illimité'
                              : '${r['restants']} restants',
                          style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 9,
                            color: r['restants'] == -1 ? _green : _orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.event, size: 11, color: _subText),
                        const SizedBox(width: 3),
                        Text(r['expiry'],
                            style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 9, color: _subText,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBF9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: unlocked
                        ? Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isMeal ? _goldBg : _greenPale,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isMeal ? _gold : _green, width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🎟️', style: TextStyle(fontSize: 12)),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(r['code'],
                                            style: TextStyle(
                                              fontFamily: 'Poppins', fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isMeal ? _gold : _greenDark,
                                              letterSpacing: 1,
                                            )),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showCouponDialog(r),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isMeal
                                          ? [_gold, const Color(0xFFFBC02D)]
                                          : [_greenDark, _green],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isMeal ? _gold : _green).withOpacity(0.35),
                                        blurRadius: 8, offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Text('Utiliser →',
                                      style: TextStyle(
                                        fontFamily: 'Poppins', fontSize: 11,
                                        fontWeight: FontWeight.w600, color: Colors.white,
                                      )),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock_outline, size: 12, color: _subText),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(r['condition'],
                                        style: const TextStyle(
                                          fontFamily: 'Poppins', fontSize: 10, color: _subText,
                                        )),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: r['progress'] as double,
                                  backgroundColor: _divider,
                                  valueColor: const AlwaysStoppedAnimation<Color>(_orange),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(r['progressLabel'],
                                  style: const TextStyle(
                                    fontFamily: 'Poppins', fontSize: 9, color: _subText,
                                  )),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCouponDialog(Map<String, dynamic> r) {
    final isMeal = r['type'] == 'meal';

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _divider, borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: isMeal ? _goldBg : _greenPale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(Icons.qr_code_scanner,
                    size: 40, color: isMeal ? _gold : _green),
              ),
            ),
            const SizedBox(height: 16),
            Text(r['title'],
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 18,
                  fontWeight: FontWeight.w700, color: _textDark,
                )),
            const SizedBox(height: 4),
            Text(r['partner'],
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12, color: _subText,
                )),
            const SizedBox(height: 8),
            // ✅ عرض النقاط المطلوبة في الـ dialog أيضاً
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _greenPale, borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⭐ ${r['requiredPoints']} pts requis pour débloquer',
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11,
                  fontWeight: FontWeight.w600, color: _greenDark,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isMeal ? _goldBg : _greenPale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(r['code'],
                  style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isMeal ? _gold : _greenDark,
                    letterSpacing: 2,
                  )),
            ),
            const SizedBox(height: 8),
            Text('Valable jusqu\'au ${r['expiry']}',
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 10, color: _subText,
                )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CouponQRCodeScreen(
                        title:             r['title'],
                        partner:           r['partner'],
                        code:              r['code'],
                        expiry:            r['expiry'],
                        type:              r['type'],
                        missionsCompleted: _missionsCompleted,
                        kgSaved:           _kgSaved,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMeal ? _gold : _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('📱 Afficher le QR code',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w600, color: Colors.white,
                    )),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer',
                  style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, color: _subText,
                  )),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
