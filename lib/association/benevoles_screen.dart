import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'evaluer_benevole_screen.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF1A2B4A);
}

class BenevolesScreen extends StatefulWidget {
  final String initialFilter;
  final bool selectionMode;
  const BenevolesScreen({
    super.key,
    this.initialFilter = 'Tous',
    this.selectionMode = false,
  });

  @override
  State<BenevolesScreen> createState() => _BenevolesScreenState();
}

class _BenevolesScreenState extends State<BenevolesScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  final List<String> _filters = ['Tous', 'Disponibles', 'En mission'];

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '??';
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF1B5E20),
      const Color(0xFFE65100),
      const Color(0xFF6A1B9A),
      const Color(0xFF00838F),
      const Color(0xFFF9A825),
      const Color(0xFFC62828),
      const Color(0xFF1565C0),
    ];
    final index = name.length % colors.length;
    return colors[index];
  }

  Future<List<Map<String, dynamic>>> _loadBenevolesWithRatings() async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'benevole')
        .get();
    
    List<Map<String, dynamic>> benevoles = [];
    
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'Bénévole';
      final userId = doc.id;
      
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('toUserId', isEqualTo: userId)
          .get();
      
      double avgRating = 0.0;
      if (ratingsSnapshot.docs.isNotEmpty) {
        double sum = 0;
        for (var ratingDoc in ratingsSnapshot.docs) {
          sum += (ratingDoc.data()['moyenne'] ?? 0).toDouble();
        }
        avgRating = sum / ratingsSnapshot.docs.length;
      }
      
      benevoles.add({
        'id': userId,
        'nom': name,
        'note': avgRating,
        'missions': data['missions'] ?? 0,
        'transport': data['transport'] ?? 'Voiture',
        'statut': data['statut'] ?? 'Disponible',
        'initiales': _getInitials(name),
        'color': _getAvatarColor(name),
      });
    }
    
    return benevoles;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  widget.selectionMode ? 'Choisir un bénévole' : 'Bénévoles',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.selectionMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Pour évaluation',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un bénévole...',
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final active = _filter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? ZadColors.darkNavy
                                  : ZadColors.cardBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : ZadColors.labelGrey,
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _loadBenevolesWithRatings(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Erreur: ${snapshot.error}'),
                        );
                      }

                      var benevoles = snapshot.data ?? [];

                      if (_filter == 'Disponibles') {
                        benevoles = benevoles.where((b) => b['statut'] == 'Disponible').toList();
                      } else if (_filter == 'En mission') {
                        benevoles = benevoles.where((b) => b['statut'] == 'En mission').toList();
                      }

                      if (_search.isNotEmpty) {
                        benevoles = benevoles.where((b) {
                          return b['nom'].toString().toLowerCase().contains(_search.toLowerCase());
                        }).toList();
                      }

                      if (benevoles.isEmpty) {
                        return const Center(
                          child: Text('Aucun bénévole trouvé'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: benevoles.length,
                        itemBuilder: (context, index) {
                          return _BenevoleCard(
                            data: benevoles[index],
                            selectionMode: widget.selectionMode,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          _BottomNav(active: 1),
        ],
      ),
    );
  }
}

class _BenevoleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selectionMode;
  const _BenevoleCard({required this.data, this.selectionMode = false});

  Color get _statutColor {
    switch (data['statut']) {
      case 'Disponible':
        return const Color(0xFF2E7D32);
      case 'En mission':
        return const Color(0xFF1565C0);
      case 'Inactif':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Color get _statutBg {
    switch (data['statut']) {
      case 'Disponible':
        return const Color(0xFFE8F5E9);
      case 'En mission':
        return const Color(0xFFE3F2FD);
      case 'Inactif':
        return const Color(0xFFF5F5F5);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZadColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
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
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFB800), size: 13),
                        Text(
                          ' ${data['note'].toStringAsFixed(1)} · ${data['missions']} missions · ${data['transport']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ZadColors.labelGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statutBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['statut'],
                    style: TextStyle(
                      fontSize: 11,
                      color: _statutColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (selectionMode) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EvaluerBenevoleScreen(
                        benevoleId: data['id'] as String?,
                        benevoleName: data['nom'] as String?,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.star_rate_rounded, size: 16),
                label: const Text(
                  'Évaluer ce bénévole',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
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
            onTap: () {},
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