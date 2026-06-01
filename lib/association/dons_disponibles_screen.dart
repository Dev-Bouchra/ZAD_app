import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'don_details_screen.dart';
import 'confirmer_reception_screen.dart';
import 'mission_tracking_screen.dart';
import '../../notification_service.dart';
import '../../auth/auth_service.dart';

class ZadColors {
  static const Color darkNavy = Color(0xFF1A2B4A);
  static const Color teal = Color(0xFF2E7D7D);
  static const Color leafGreen = Color(0xFF2E7D32);
  static const Color background = Color(0xFFFFFFFF);
  static const Color labelGrey = Color(0xFF6B7A8D);
  static const Color cardBg = Color(0xFFF5F7FA);
}

class DonsDisponiblesScreen extends StatefulWidget {
  const DonsDisponiblesScreen({super.key});

  @override
  State<DonsDisponiblesScreen> createState() => _DonsDisponiblesScreenState();
}

class _DonsDisponiblesScreenState extends State<DonsDisponiblesScreen> {
  String _filter = 'Tous';
  final List<String> _filters = ['Tous', 'Pain', 'Repas', 'Urgent'];
  List<Map<String, dynamic>> _dons = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadDons();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _currentUserId = user?.uid);
  }

  Future<void> _loadDons() async {
    try {
      setState(() => _isLoading = true);
      final snapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('status', whereIn: [
            'disponible',
            'accepte_par_association',
            'reserve',
            'en_route',
            'en_livraison',
            'recu_par_benevole', // ✅ البنيفول أخذ التبرع — ينتظر تأكيد الجمعية
          ])
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _dons = snapshot.docs.map((doc) {
          final d = doc.data();
          final status = d['status'] ?? 'disponible';
          final isUrgent = d['isUrgent'] == true;

          String displayStatut = 'En attente';
          if (status == 'disponible') {
            displayStatut = isUrgent ? 'Urgent' : 'En attente';
          } else if (status == 'accepte_par_association') {
            displayStatut = 'Accepté - Attente bénévole';
          } else if (status == 'reserve') {
            displayStatut = 'Réservé';
          } else if (status == 'en_route' || status == 'en_livraison') {
            displayStatut = 'En cours';
          } else if (status == 'recu_par_benevole') {
            displayStatut = 'Bénévole arrivé'; // ✅
          }

          return {
            'donId': doc.id,
            'titre': d['title'] ?? 'Don',
            'source': d['donorName'] ?? '',
            'donorId': d['donorId'] ?? '',
            'adresse': d['address'] ?? '',
            'latitude': (d['latitude'] as num?)?.toDouble() ?? 34.8828,
            'longitude': (d['longitude'] as num?)?.toDouble() ?? -1.3167,
            'expiration': d['expiryDate'] ?? '',
            'quantite': d['quantity'] ?? '',
            'statut': displayStatut,
            'statusCode': status,
            'type': _getType(d['title'] ?? ''),
            'icon': _getIcon(d['title'] ?? ''),
            'description': d['description'] ?? '',
            'isUrgent': isUrgent,
            'volunteerId': d['volunteerId'] ?? '',
            // ✅ الصورة التي رفعها المتبرع
            'imageUrl': d['imageUrl'] ?? '',
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erreur loadDons: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _accepterEtReserverDon(String donId, Map<String, dynamic> donData) async {
    try {
      final success = await AuthService.associationAcceptDon(
        donId: donId,
        associationId: _currentUserId!,
        associationName: donData['source'] ?? 'Association',
      );
      
      if (success) {
        _loadDons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Don accepté ! Les bénévoles peuvent maintenant le voir')),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur acceptation: $e");
    }
  }

  Future<void> _refuserDon(String donId) async {
    try {
      final success = await AuthService.associationRefuseDon(donId: donId);
      if (success) {
        _loadDons();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Don refusé')),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Erreur refus: $e");
    }
  }

  void _suivreLivraison(String donId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MissionTrackingScreen(donId: donId),
      ),
    ).then((_) => _loadDons());
  }

  void _confirmerReception(String donId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmerReceptionScreen(donId: donId),
      ),
    ).then((_) => _loadDons());
  }

  String _getType(String title) {
    if (title.toLowerCase().contains('pain') ||
        title.toLowerCase().contains('boulangerie')) return 'Pain';
    if (title.toLowerCase().contains('repas') ||
        title.toLowerCase().contains('plat') ||
        title.toLowerCase().contains('cuisiné')) return 'Repas';
    return 'Tous';
  }

  IconData _getIcon(String title) {
    if (title.toLowerCase().contains('pain') ||
        title.toLowerCase().contains('boulangerie')) return Icons.bakery_dining;
    if (title.toLowerCase().contains('repas') ||
        title.toLowerCase().contains('plat')) return Icons.restaurant;
    if (title.toLowerCase().contains('fruit') ||
        title.toLowerCase().contains('légume')) return Icons.eco;
    if (title.toLowerCase().contains('conserve')) return Icons.kitchen;
    return Icons.volunteer_activism;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'Tous') return _dons;
    if (_filter == 'Urgent') {
      return _dons.where((d) => d['isUrgent'] == true).toList();
    }
    return _dons.where((d) => d['type'] == _filter).toList();
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
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dons disponibles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadDons,
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                                      horizontal: 18, vertical: 8),
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

                      if (_filtered.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.volunteer_activism_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('Aucun don disponible',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 16)),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final don = _filtered[index];
                              return _DonCard(
                                data: don,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DonDetailsScreen(
                                      donId: don['donId'],
                                      donData: don,
                                    ),
                                  ),
                                ).then((_) => _loadDons()),
                                onAccepterEtReserver: () => _accepterEtReserverDon(don['donId'], don),
                                onRefuser: () => _refuserDon(don['donId']),
                                onSuivre: () => _suivreLivraison(don['donId']),
                                onConfirmer: () => _confirmerReception(don['donId']),
                                currentUserId: _currentUserId,
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

class _DonCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onAccepterEtReserver;
  final VoidCallback onRefuser;
  final VoidCallback onSuivre;
  final VoidCallback onConfirmer;
  final String? currentUserId;

  const _DonCard({
    required this.data,
    required this.onTap,
    required this.onAccepterEtReserver,
    required this.onRefuser,
    required this.onSuivre,
    required this.onConfirmer,
    required this.currentUserId,
  });

  Color get _statutColor {
    switch (data['statut']) {
      case 'Urgent':                      return const Color(0xFFE53935);
      case 'Accepté - Attente bénévole':  return const Color(0xFF2E7D32);
      case 'Réservé':                     return const Color(0xFF1565C0);
      case 'En cours':                    return const Color(0xFFFF9800);
      case 'Bénévole arrivé':             return const Color(0xFF6A1B9A); // ✅ بنفسجي
      default:                            return const Color(0xFF2E7D32);
    }
  }

  Color get _statutBg {
    switch (data['statut']) {
      case 'Urgent':                      return const Color(0xFFFFEBEE);
      case 'Accepté - Attente bénévole':  return const Color(0xFFE8F5E9);
      case 'Bénévole arrivé':             return const Color(0xFFF3E5F5); // ✅
      case 'Réservé':   return const Color(0xFFE3F2FD);
      case 'En cours':  return const Color(0xFFFFF3E0);
      default:          return const Color(0xFFE8F5E9);
    }
  }

  bool get _isUrgent     => data['isUrgent'] == true;
  bool get _isReserved   => data['statut'] == 'Réservé';
  bool get _isEnRoute    => data['statut'] == 'En cours';
  bool get _isDisponible => data['statusCode'] == 'disponible';

  @override
  Widget build(BuildContext context) {
    final statusCode = data['statusCode'] as String? ?? 'disponible';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isUrgent ? const Color(0xFFFFF8F8) : ZadColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: _isUrgent
            ? Border.all(color: const Color(0xFFFFCDD2), width: 1)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data['icon'] as IconData,
                    color: ZadColors.leafGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['titre'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ZadColors.darkNavy,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
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
                    const SizedBox(height: 2),
                    Text(data['source'],
                        style: const TextStyle(
                            fontSize: 12, color: ZadColors.labelGrey)),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: ZadColors.labelGrey),
                        Expanded(
                          child: Text(
                            ' ${data['adresse']}',
                            style: const TextStyle(
                                fontSize: 11, color: ZadColors.labelGrey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(data['quantite'].toString(),
                        style: const TextStyle(
                            fontSize: 11, color: ZadColors.labelGrey)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTap,
                child: const Icon(Icons.chevron_right,
                    color: ZadColors.labelGrey, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              if (statusCode == 'disponible') ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccepterEtReserver,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isUrgent ? Colors.red : ZadColors.leafGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      _isUrgent ? 'Accepter (Urgent)' : 'Accepter et réserver',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRefuser,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Refuser',
                        style: TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ZadColors.leafGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Détails', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],

              if (statusCode == 'accepte_par_association') ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('⏳ En attente bénévole',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  ),
                ),
              ],

              if (statusCode == 'reserve') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirmer,
                    icon: const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 16),
                    label: const Text('Confirmer',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZadColors.leafGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],

              if (statusCode == 'en_route' || statusCode == 'en_livraison') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSuivre,
                    icon: const Icon(Icons.directions_bike,
                        color: Colors.white, size: 16),
                    label: const Text('Suivre la livraison',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],

              // ✅ البنيفول وصل — زر تأكيد الاستلام
              if (statusCode == 'recu_par_benevole') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSuivre, // يفتح mission_tracking_screen
                    icon: const Icon(Icons.map_outlined,
                        color: Colors.white, size: 16),
                    label: const Text('Suivre',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onConfirmer, // يفتح confirmer_reception_screen
                    icon: const Icon(Icons.check_circle,
                        color: Colors.white, size: 16),
                    label: const Text('Confirmer la réception',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}