// lib/donateur/besoins_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'publish_don_screen.dart';
import '../shared/zad_colors.dart';

class BesoinsScreen extends StatefulWidget {
  const BesoinsScreen({super.key});

  @override
  State<BesoinsScreen> createState() => _BesoinsScreenState();
}

class _BesoinsScreenState extends State<BesoinsScreen> {
  // IDs des besoins en cours d'animation de sortie
  final Set<String> _dismissingIds = {};

  Color _urgenceColor(String niveau) {
    switch (niveau) {
      case 'Haute':
        return ZADColors.danger;
      case 'Moyen':
        return ZADColors.accentOrange;
      default:
        return ZADColors.primary;
    }
  }

  IconData _urgenceIcon(String niveau) {
    switch (niveau) {
      case 'Haute':
        return Icons.warning_amber_rounded;
      case 'Moyen':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  // ── Accepter : ouvre PublishDonScreen pré-rempli ─────────────────────────
  void _onAccept(BuildContext context, String docId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublishDonScreen(
          prefillFromBesoin: BesoinPrefill(
            besoinId: docId,
            typeBesoin: data['typeBesoin'] as String? ?? '',
            associationId: data['associationId'] as String? ?? '',
            associationNom: data['associationNom'] as String? ?? '',
            quantiteEstimee: data['quantiteEstimee'] as String? ?? '',
            notes: data['notes'] as String? ?? '',
            dateLimite: data['dateLimite'] as Timestamp?,
            niveauUrgence: data['niveauUrgence'] as String? ?? 'Moyen',
          ),
        ),
      ),
    );
  }

  // ── Refuser : animation de sortie puis mettre statut = refusé ────────────
  Future<void> _onRefuse(BuildContext context, String docId) async {
    setState(() => _dismissingIds.add(docId));

    // Laisser l'animation jouer (600 ms)
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      await FirebaseFirestore.instance
          .collection('besoins')
          .doc(docId)
          .update({'statut': 'refuse'});
    } catch (e) {
      debugPrint('❌ Erreur refus besoin: $e');
    }

    if (mounted) setState(() => _dismissingIds.remove(docId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: ZADColors.headerBg,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Besoins des associations',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Liste ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('besoins')
                  .where('statut', isEqualTo: 'actif')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: ZADColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erreur: ${snapshot.error}',
                          style: const TextStyle(
                              color: ZADColors.textMedium)));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volunteer_activism_outlined,
                            size: 64,
                            color: ZADColors.textLight.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('Aucun besoin disponible',
                            style: TextStyle(
                                fontSize: 16,
                                color: ZADColors.textMedium)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final docId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    final urgence =
                        data['niveauUrgence'] as String? ?? 'Moyen';
                    final isDismissing = _dismissingIds.contains(docId);

                    return _AnimatedBesoinCard(
                      key: ValueKey(docId),
                      isDismissing: isDismissing,
                      child: _BesoinCard(
                        data: data,
                        urgence: urgence,
                        color: _urgenceColor(urgence),
                        urgenceIcon: _urgenceIcon(urgence),
                        timeAgo: _timeAgo(data['createdAt'] as Timestamp?),
                        onAccept: () => _onAccept(context, docId, data),
                        onRefuse: () => _onRefuse(context, docId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 1),
    );
  }
}

// ── Wrapper animé ────────────────────────────────────────────────────────────
class _AnimatedBesoinCard extends StatefulWidget {
  final Widget child;
  final bool isDismissing;

  const _AnimatedBesoinCard({
    super.key,
    required this.child,
    required this.isDismissing,
  });

  @override
  State<_AnimatedBesoinCard> createState() => _AnimatedBesoinCardState();
}

class _AnimatedBesoinCardState extends State<_AnimatedBesoinCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _slide;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _opacity = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _slide = Tween<double>(begin: 0, end: -80).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInBack));
    _scale = Tween<double>(begin: 1, end: 0.88).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void didUpdateWidget(_AnimatedBesoinCard old) {
    super.didUpdateWidget(old);
    if (widget.isDismissing && !old.isDismissing) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(_slide.value, 0),
        child: Transform.scale(
          scale: _scale.value,
          child: Opacity(opacity: _opacity.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

// ── Card besoin ──────────────────────────────────────────────────────────────
class _BesoinCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String urgence;
  final Color color;
  final IconData urgenceIcon;
  final String timeAgo;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _BesoinCard({
    required this.data,
    required this.urgence,
    required this.color,
    required this.urgenceIcon,
    required this.timeAgo,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(urgenceIcon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data['typeBesoin'] ?? '',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ZADColors.textDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color, width: 1.2),
                      ),
                      child: Text(urgence,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 13, color: ZADColors.textLight),
                    const SizedBox(width: 4),
                    Text(data['associationNom'] ?? 'Association',
                        style: const TextStyle(
                            color: ZADColors.textLight, fontSize: 12)),
                    const SizedBox(width: 14),
                    const Icon(Icons.access_time,
                        size: 13, color: ZADColors.textLight),
                    const SizedBox(width: 4),
                    Text(timeAgo,
                        style: const TextStyle(
                            color: ZADColors.textLight, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 13, color: ZADColors.textMedium),
                    const SizedBox(width: 4),
                    Text('Quantité: ${data['quantiteEstimee'] ?? ''}',
                        style: const TextStyle(
                            color: ZADColors.textMedium, fontSize: 12)),
                    if (data['dateLimite'] != null) ...[
                      const SizedBox(width: 14),
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: ZADColors.textMedium),
                      const SizedBox(width: 4),
                      Builder(builder: (_) {
                        final dl =
                            (data['dateLimite'] as Timestamp).toDate();
                        return Text(
                          'Limite: ${dl.day}/${dl.month}/${dl.year}',
                          style: const TextStyle(
                              color: ZADColors.textMedium, fontSize: 12),
                        );
                      }),
                    ],
                  ],
                ),
                if ((data['notes'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(data['notes'],
                      style: const TextStyle(
                          color: ZADColors.textMedium, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onRefuse,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: ZADColors.danger.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: ZADColors.danger.withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded,
                              color: ZADColors.danger, size: 18),
                          SizedBox(width: 6),
                          Text('Refuser',
                              style: TextStyle(
                                  color: ZADColors.danger,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: ZADColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Accepter',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}