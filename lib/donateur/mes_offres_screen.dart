// 📄 lib/donateur/mes_offres_screen.dart
// شاشة إدارة عروض المتبرع الشريك - مع Firebase + إظهار النقاط المطلوبة

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'home_screen.dart';
import 'ajouter_offre_screen.dart';
import 'offre_manager.dart';
import '../shared/zad_colors.dart';

class MesOffresScreen extends StatefulWidget {
  const MesOffresScreen({super.key});

  @override
  State<MesOffresScreen> createState() => _MesOffresScreenState();
}

class _MesOffresScreenState extends State<MesOffresScreen> {
  final OffreManager _offreManager = OffreManager.instance;

  Future<void> _deleteOffre(String offreId, String titre) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer l\'offre',
            style: TextStyle(fontWeight: FontWeight.w800, color: ZADColors.danger)),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "$titre" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: ZADColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: ZADColors.danger)),
          ),
        ],
      ),
    );
    
    if (shouldDelete == true && offreId.isNotEmpty) {
      try {
        await _offreManager.supprimerOffre(offreId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offre supprimée'),
              backgroundColor: ZADColors.danger,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: ZADColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          Container(
            color: ZADColors.headerBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const Expanded(
                      child: Text('Mes offres',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AjouterOffreScreen(),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _offreManager.getOffresStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ZADColors.primary,
                    ),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: ZADColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          'Erreur: ${snapshot.error}',
                          style: const TextStyle(color: ZADColors.textMedium),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                final List<Map<String, dynamic>> offres = snapshot.data ?? [];
                
                final int totalOffres = offres.length;
                final int actives = offres.where((o) => o['restants'] != 0).length;
                final int expirees = offres.where((o) => o['restants'] == 0).length;
                
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          _StatCard(
                            value: totalOffres.toString(),
                            label: 'Total offres',
                            icon: Icons.card_giftcard,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            value: actives.toString(),
                            label: 'Actives',
                            icon: Icons.check_circle,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            value: expirees.toString(),
                            label: 'Expirées',
                            icon: Icons.timer_off,
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: offres.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.card_giftcard, size: 64, color: ZADColors.textLight),
                                  SizedBox(height: 16),
                                  Text('Aucune offre créée',
                                      style: TextStyle(color: ZADColors.textLight, fontSize: 14)),
                                  SizedBox(height: 8),
                                  Text('Appuyez sur + pour ajouter',
                                      style: TextStyle(color: ZADColors.textLight, fontSize: 12)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: offres.length,
                              itemBuilder: (context, index) {
                                final offre = offres[index];
                                final isExpired = offre['restants'] == 0;
                                return _OffreCard(
                                  offre: offre,
                                  isExpired: isExpired,
                                  onDelete: () => _deleteOffre(offre['id'] ?? '', offre['title'] ?? ''),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 0),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: ZADColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: ZADColors.textDark,
                )),
            Text(label,
                style: const TextStyle(
                  color: ZADColors.textLight,
                  fontSize: 11,
                )),
          ],
        ),
      ),
    );
  }
}

class _OffreCard extends StatelessWidget {
  final Map<String, dynamic> offre;
  final bool isExpired;
  final VoidCallback onDelete;

  const _OffreCard({
    required this.offre,
    required this.isExpired,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = offre['type'];
    final typeColor = type == 'reduction' ? ZADColors.accentOrange : ZADColors.success;
    final isIllimite = offre['restants'] == -1;
    
    // ✅ الحصول على النقاط المطلوبة
    final requiredPoints = offre['requiredPoints'] ?? 0;
    final String pointsText = requiredPoints == 0 
        ? 'Gratuit' 
        : '$requiredPoints pts requis';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExpired ? ZADColors.background : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? ZADColors.divider : ZADColors.primary,
          width: isExpired ? 1 : 1.5,
        ),
        boxShadow: isExpired
            ? null
            : [
                BoxShadow(
                  color: ZADColors.primary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ZADColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(offre['icon'] ?? '🎁', style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offre['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isExpired ? ZADColors.textLight : ZADColors.textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        offre['valeur'] ?? '',
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  offre['description'] ?? '',
                  style: TextStyle(
                    color: isExpired ? ZADColors.textLight : ZADColors.textMedium,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_available, size: 12, color: ZADColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      offre['expiry'] ?? 'Indéfiniment',
                      style: const TextStyle(color: ZADColors.textLight, fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.people_outline,
                      size: 12,
                      color: isIllimite ? ZADColors.success : ZADColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isIllimite ? 'Illimité' : '${offre['restants']} restants',
                      style: TextStyle(
                        color: isIllimite ? ZADColors.success : ZADColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // ✅ إظهار النقاط المطلوبة
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: ZADColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      pointsText,
                      style: TextStyle(
                        color: ZADColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ZADColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline, color: ZADColors.danger, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}