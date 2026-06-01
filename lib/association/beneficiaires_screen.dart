// lib/association/beneficiaires_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ajouter_beneficiare_screen.dart'; // ✅ تأكد من صحة اسم الملف

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
}

class BeneficiairesScreen extends StatefulWidget {
  const BeneficiairesScreen({super.key});

  @override
  State<BeneficiairesScreen> createState() => _BeneficiairesScreenState();
}

class _BeneficiairesScreenState extends State<BeneficiairesScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '??';
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
      const Color(0xFFAD1457),
      const Color(0xFFE65100),
      const Color(0xFFF9A825),
      const Color(0xFF00838F),
      const Color(0xFF2E7D32),
    ];
    final index = name.length % colors.length;
    return colors[index];
  }

  Future<void> _openAddBeneficiaire() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AjouterBeneficiaireScreen()),
    );
    
    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Bénéficiaire ajouté avec succès'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _goBackToHome() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      backgroundColor: ZadColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddBeneficiaire,
        backgroundColor: const Color(0xFF1B5E20),
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                  onTap: _goBackToHome,
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bénéficiaires',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openAddBeneficiaire,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un bénéficiaire...',
                      hintStyle: TextStyle(
                        color: ZadColors.labelGrey,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: ZadColors.labelGrey,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: ZadColors.labelGrey,
                              ),
                              onPressed: () => setState(() {
                                _search = '';
                                _searchController.clear();
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor: ZadColors.cardBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('beneficiaires')
                        .where('associationId', isEqualTo: user?.uid ?? '')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1B5E20),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Erreur: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                ),
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun bénéficiaire enregistré',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ZadColors.labelGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Appuyez sur le bouton + pour en ajouter',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ZadColors.labelGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      List<Map<String, dynamic>> beneficiaires = docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['nom'] ?? 'Bénéficiaire';
                        final besoins = data['besoins'] ?? [];
                        final besoinText = besoins.isNotEmpty ? besoins.join(', ') : 'Nourriture';
                        
                        return {
                          'id': doc.id,
                          'nom': name,
                          'adresse': data['adresse'] ?? '',
                          'telephone': data['telephone'] ?? '',
                          'personnes': data['personnes'] ?? 0,
                          'besoin': besoinText,
                          'statut': data['statut'] ?? 'Actif',
                          'initiales': _getInitials(name),
                          'color': _getAvatarColor(name),
                          'createdAt': data['createdAt'],
                        };
                      }).toList();

                      beneficiaires.sort((a, b) {
                        final aTime = a['createdAt'] as Timestamp?;
                        final bTime = b['createdAt'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      if (_search.isNotEmpty) {
                        beneficiaires = beneficiaires.where((b) {
                          return b['nom'].toString().toLowerCase().contains(_search.toLowerCase());
                        }).toList();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${beneficiaires.length} bénéficiaire${beneficiaires.length > 1 ? 's' : ''} enregistré${beneficiaires.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: ZadColors.labelGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: beneficiaires.length,
                                itemBuilder: (context, index) {
                                  final b = beneficiaires[index];
                                  return _BeneficiaireCard(data: b);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

class _BeneficiaireCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BeneficiaireCard({required this.data});

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: data['color'],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        data['initiales'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['nom'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          data['statut'] == 'Urgent' ? '🔴 Besoin urgent' : '✅ Actif',
                          style: TextStyle(
                            fontSize: 13,
                            color: data['statut'] == 'Urgent' ? Colors.red : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              _DetailRow(icon: Icons.location_on, label: 'Adresse', value: data['adresse']),
              _DetailRow(icon: Icons.phone, label: 'Téléphone', value: data['telephone'] ?? 'Non renseigné'),
              _DetailRow(icon: Icons.people, label: 'Personnes', value: '${data['personnes']} personne(s)'),
              _DetailRow(icon: Icons.restaurant, label: 'Besoins', value: data['besoin']),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: data['color'],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  data['initiales'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['nom'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ZadColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data['personnes']} personne(s) · ${data['adresse']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ZadColors.labelGrey,
                    ),
                  ),
                  Text(
                    'Besoins : ${data['besoin']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ZadColors.labelGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (data['statut'] == 'Urgent')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Urgent',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: ZadColors.labelGrey),
              onPressed: () => _showDetails(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ZadColors.labelGrey),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ZadColors.labelGrey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}