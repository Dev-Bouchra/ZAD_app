// lib/association/mes_besoins_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'publier_bessoin_screen.dart';

class MesBesoinsScreen extends StatelessWidget {
  const MesBesoinsScreen({super.key});

  Color _statutColor(String statut) {
    switch (statut) {
      case 'accepte': return const Color(0xFF2E7D32);
      case 'refuse':  return const Color(0xFFE53935);
      case 'actif':   return const Color(0xFF1565C0);
      case 'expire':  return const Color(0xFF757575);
      default:        return const Color(0xFF757575);
    }
  }

  IconData _statutIcon(String statut) {
    switch (statut) {
      case 'accepte': return Icons.check_circle_rounded;
      case 'refuse':  return Icons.cancel_rounded;
      case 'actif':   return Icons.radio_button_checked;
      case 'expire':  return Icons.timer_off_outlined;
      default:        return Icons.help_outline;
    }
  }

  String _statutLabel(String statut) {
    switch (statut) {
      case 'accepte': return 'Accepté';
      case 'refuse':  return 'Refusé';
      case 'actif':   return 'Actif';
      case 'expire':  return 'Expiré';
      default:        return statut;
    }
  }

  Color _urgenceColor(String niveau) {
    switch (niveau) {
      case 'Haute': return const Color(0xFFE53935);
      case 'Moyen': return const Color(0xFFFF9800);
      default:      return const Color(0xFF2E7D32);
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'il y a ${diff.inHours}h';
    if (diff.inDays < 30)    return 'il y a ${diff.inDays}j';
    return 'il y a ${(diff.inDays / 30).floor()} mois';
  }

  /// ✅ Supprime le document besoin de Firestore.
  /// Effet immédiat sur TOUS les StreamBuilders qui écoutent la collection 'besoins' :
  ///   - MesBesoinsScreen (association) → la carte disparaît
  ///   - BesoinsScreen (donateur)       → la carte disparaît
  ///   - Home donateur (section "Besoins des associations") → la carte disparaît
  Future<void> _deleteBesoin(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Supprimer le besoin',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF1A2B4A),
          ),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce besoin ?\n\n'
          'Il sera retiré de la liste des besoins visible par les donateurs.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7A8D)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF6B7A8D))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('besoins')
            .doc(docId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Besoin supprimé avec succès'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Mes besoins publiés',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ── Stats ───────────────────────────────────────────────────────
          if (uid.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('besoins')
                  .where('associationId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                final docs    = snap.data?.docs ?? [];
                final actif   = docs.where((d) => (d.data() as Map)['statut'] == 'actif').length;
                final accepte = docs.where((d) => (d.data() as Map)['statut'] == 'accepte').length;
                final refuse  = docs.where((d) => (d.data() as Map)['statut'] == 'refuse').length;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      _StatChip(count: docs.length, label: 'Total',    color: const Color(0xFF1A2B4A)),
                      _StatDivider(),
                      _StatChip(count: actif,        label: 'Actifs',   color: const Color(0xFF1565C0)),
                      _StatDivider(),
                      _StatChip(count: accepte,      label: 'Acceptés', color: const Color(0xFF2E7D32)),
                      _StatDivider(),
                      _StatChip(count: refuse,       label: 'Refusés',  color: const Color(0xFFE53935)),
                    ],
                  ),
                );
              },
            ),

          // ── Liste ──────────────────────────────────────────────────────
          Expanded(
            child: uid.isEmpty
                ? const Center(child: Text('Non connecté'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('besoins')
                        .where('associationId', isEqualTo: uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2E7D32),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Erreur: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red)),
                          ),
                        );
                      }

                      // Tri côté client (newest first)
                      final docs = (snapshot.data?.docs ?? []).toList()
                        ..sort((a, b) {
                          final ta = (a.data() as Map)['createdAt'] as Timestamp?;
                          final tb = (b.data() as Map)['createdAt'] as Timestamp?;
                          if (ta == null && tb == null) return 0;
                          if (ta == null) return 1;
                          if (tb == null) return -1;
                          return tb.compareTo(ta);
                        });

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.volunteer_activism_outlined,
                                  size: 52,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Aucun besoin publié',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2B4A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Publiez votre premier besoin\npour recevoir des dons',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7A8D),
                                ),
                              ),
                              const SizedBox(height: 28),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PublierBesoinScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Publier un besoin'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                          final doc    = docs[i];
                          final data   = doc.data() as Map<String, dynamic>;
                          final statut  = data['statut']       as String? ?? 'actif';
                          final urgence = data['niveauUrgence'] as String? ?? 'Moyen';

                          return _BesoinHistoriqueCard(
                            docId:        doc.id,
                            data:         data,
                            statut:       statut,
                            statutColor:  _statutColor(statut),
                            statutIcon:   _statutIcon(statut),
                            statutLabel:  _statutLabel(statut),
                            urgenceColor: _urgenceColor(urgence),
                            timeAgo:      _timeAgo(data['createdAt'] as Timestamp?),
                            onDelete: () => _deleteBesoin(context, doc.id),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────
class _BesoinHistoriqueCard extends StatelessWidget {
  final String               docId;
  final Map<String, dynamic> data;
  final String               statut;
  final Color                statutColor;
  final IconData             statutIcon;
  final String               statutLabel;
  final Color                urgenceColor;
  final String               timeAgo;
  final VoidCallback         onDelete;

  const _BesoinHistoriqueCard({
    required this.docId,
    required this.data,
    required this.statut,
    required this.statutColor,
    required this.statutIcon,
    required this.statutLabel,
    required this.urgenceColor,
    required this.timeAgo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeBesoin = data['typeBesoin']      as String? ?? '';
    final quantite   = data['quantiteEstimee'] as String? ?? '';
    final notes      = data['notes']           as String? ?? '';
    final urgence    = data['niveauUrgence']   as String? ?? 'Moyen';
    final dl         = data['dateLimite']      as Timestamp?;
    final donorNom   = data['donorNom']        as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Bande couleur top
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statutColor,
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type + badge statut
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        typeBesoin,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A2B4A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statutColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statutColor, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statutIcon, color: statutColor, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            statutLabel,
                            style: TextStyle(
                              color: statutColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quantité + urgence
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 14, color: Color(0xFF6B7A8D)),
                    const SizedBox(width: 5),
                    Text(
                      'Quantité: $quantite',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7A8D)),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgenceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        urgence,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: urgenceColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Date + temps
                Row(
                  children: [
                    if (dl != null) ...[
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: Color(0xFF6B7A8D)),
                      const SizedBox(width: 4),
                      Text(
                        'Limite: ${dl.toDate().day}/${dl.toDate().month}/${dl.toDate().year}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7A8D)),
                      ),
                      const SizedBox(width: 14),
                    ],
                    const Icon(Icons.access_time,
                        size: 13, color: Color(0xFF6B7A8D)),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7A8D)),
                    ),
                  ],
                ),

                // Notes
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7A8D)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Donateur lié (si accepté)
                if (statut == 'accepte' && donorNom != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 15, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 6),
                        Text(
                          'Donateur: $donorNom',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ✅ Bouton Supprimer — visible pour TOUS les statuts
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFE53935).withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: Color(0xFFE53935), size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Supprimer',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

// ── Helpers ───────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatChip({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7A8D)),
        ),
      ],
    ),
  );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));
}
