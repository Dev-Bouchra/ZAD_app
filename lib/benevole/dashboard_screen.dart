// ============================================================
// 📄 lib/screens/benevole/dashboard_screen.dart
// ✅ النقاط والمهمات والتقييم حقيقية من Firestore
// ✅ إضافة زر "Voir détails" في _buildDonCard فقط
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';
import 'missions_screen.dart';
import 'badges_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'mission_details_screen.dart'; // ✅ إضافة جديدة
import 'dart:async';
import 'dart:math';
import '../../notification_service.dart';

class BenevoleDashboardScreen extends StatefulWidget {
  const BenevoleDashboardScreen({super.key});

  @override
  State<BenevoleDashboardScreen> createState() =>
      _BenevoleDashboardScreenState();
}

class _BenevoleDashboardScreenState extends State<BenevoleDashboardScreen> {
  static const _green = Color(0xFF4CAF50);
  static const _greenDark = Color(0xFF388E3C);
  static const _greenLight = Color(0xFF81C784);
  static const _greenBg = Color(0xFFF1F8E9);
  static const _greenPale = Color(0xFFE8F5E9);
  static const _orange = Color(0xFFFF8F00);
  static const _orangeBg = Color(0xFFFFF3E0);
  static const _blue = Color(0xFF1565C0);
  static const _red = Color(0xFFD32F2F);
  static const _redBg = Color(0xFFFFEBEE);
  static const _divider = Color(0xFFEEEEEE);
  static const _subText = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  int _currentIndex = 0;
  String _activeFilter = 'Tous';

  String _userName = '';
  String _userInitials = '';
  String _userTransport = 'Voiture';
  String _userQuartier = '';

  int _userPoints = 0;
  int _missionsCompleted = 0;
  int _kgSaved = 0;
  double _userRating = 0.0;

  bool _isLoading = true;
  bool _isAccepting = false;
  bool _isLoadingLocation = true;

  StreamSubscription<Position>? _locationSubscription;
  int _unreadNotifCount = 0;
  StreamSubscription<int>? _notifSubscription;

  LatLng _userLocation = const LatLng(34.8828, -1.3167);
  List<Map<String, dynamic>> _dons = [];

  String? _selectedDonId;
  LatLng? _selectedDonorLocation;
  String? _selectedDonorAddress;
  LatLng? _selectedAssociationLocation;
  String? _selectedAssociationAddress;

  Key _mapKey = UniqueKey();
  final MapController _mapController = MapController();

  final LatLng _defaultLocation = const LatLng(34.8828, -1.3167);
  final LatLng _defaultAssociationLocation = const LatLng(34.8948, -1.3531);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getCurrentLocation();
    _notifSubscription = NotificationService.unreadCountStream().listen((count) {
      if (mounted) setState(() => _unreadNotifCount = count);
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _notifSubscription?.cancel();
    super.dispose();
  }

  String get _userBadge {
    if (_userPoints >= 1000) return '⭐ Légende';
    if (_userPoints >= 500) return '🥇 Champion';
    if (_userPoints >= 100) return '🥈 Engagé';
    return '🥉 Débutant';
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          await _loadDonsFromFirestore();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        await _loadDonsFromFirestore();
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }

      await _loadDonsFromFirestore();
    } catch (e) {
      print("❌ Erreur location: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
      await _loadDonsFromFirestore();
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double dLat = (point2.latitude - point1.latitude) * pi / 180;
    final double dLon = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _userName = data['name'] ?? 'Bénévole';
          _userInitials = _getInitials(_userName);
          _userTransport = data['transport'] ?? 'Voiture';
          _userQuartier = data['quartier'] ?? 'Tlemcen Centre';
          _userPoints = (data['points'] ?? 0).toInt();
          _missionsCompleted = (data['missionsCompleted'] ?? 0).toInt();
          _kgSaved = (data['kgSaved'] ?? 0).toInt();
          _userRating = (data['rating'] ?? 0.0).toDouble();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("❌ Erreur loadUserData: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDonsFromFirestore() async {
    try {
      print("🔄 Chargement des dons acceptés par association...");

      QuerySnapshot snapshot;

      try {
        snapshot = await FirebaseFirestore.instance
            .collection('dons')
            .where('status', isEqualTo: 'accepte_par_association')
            .orderBy('createdAt', descending: true)
            .get();
      } catch (indexError) {
        print("⚠️ Index manquant, chargement sans orderBy: $indexError");
        snapshot = await FirebaseFirestore.instance
            .collection('dons')
            .where('status', isEqualTo: 'accepte_par_association')
            .get();
      }

      print("📦 Dons trouvés: ${snapshot.docs.length}");

      if (mounted) {
        setState(() {
          _dons = snapshot.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;

            final double donLat = (d['donorLat'] as num?)?.toDouble()
                ?? (d['latitude'] as num?)?.toDouble()
                ?? _defaultLocation.latitude;
            final double donLng = (d['donorLng'] as num?)?.toDouble()
                ?? (d['longitude'] as num?)?.toDouble()
                ?? _defaultLocation.longitude;

            final LatLng donLocation = LatLng(donLat, donLng);
            final double distance = _calculateDistance(_userLocation, donLocation);
            final String distLabel = distance < 1
                ? '${(distance * 1000).toInt()} m'
                : '${distance.toStringAsFixed(1)} km';

            return {
              'donId': doc.id,
              'icon': _getIconFromTitle(d['title']),
              'title': d['title'] ?? 'Don',
              'place': d['address'] ?? '',
              'qty': d['quantity'] ?? '',
              'dist': distance,
              'distLabel': distLabel,
              'time': '30 min',
              'urgent': d['isUrgent'] ?? false,
              'lat':    donLat,
              'lng':    donLng,
              'donorLat': donLat,
              'donorLng': donLng,
              'associationName': d['associationName'] ?? '',
              'associationId':   d['associationId']   ?? '',
              'donorName':       d['donorName']        ?? '',
              'donorId':         d['donorId']          ?? '',
              'donorAddress':    d['address']          ?? '',
              'associationLat':  (d['associationLat'] as num?)?.toDouble(),
              'associationLng':  (d['associationLng'] as num?)?.toDouble(),
            };
          }).toList();
        });
      }
    } catch (e) {
      print("❌ Erreur chargement dons: $e");
      if (mounted) setState(() => _dons = []);
    }
  }

  String _getIconFromTitle(String? title) {
    if (title == null) return '🍽️';
    final t = title.toLowerCase();
    if (t.contains('plat') || t.contains('repas') || t.contains('cuisiné')) return '🍲';
    if (t.contains('produit sec') || t.contains('farine') || t.contains('sucre')) return '🍚';
    if (t.contains('conserve')) return '🥫';
    if (t.contains('boulangerie') || t.contains('pain')) return '🥖';
    if (t.contains('fruit') || t.contains('légume')) return '🍎';
    if (t.contains('laitier') || t.contains('lait')) return '🥛';
    return '🍽️';
  }

  Future<void> _acceptMission(Map<String, dynamic> don) async {
    if (_isAccepting) return;
    if (mounted) setState(() => _isAccepting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError("Vous devez être connecté");
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final benevoleName = userDoc.data()?['name'] ?? 'Bénévole';

      double benevoleLat = _userLocation.latitude;
      double benevoleLng = _userLocation.longitude;
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        benevoleLat = pos.latitude;
        benevoleLng = pos.longitude;
        if (mounted) setState(() => _userLocation = LatLng(benevoleLat, benevoleLng));
      } catch (_) {}

      final associationId = don['associationId'] as String? ?? '';
      final donorId = don['donorId'] as String? ?? '';
      final donTitle = don['title'] as String? ?? 'Don';
      final associationName = don['associationName'] as String? ?? 'Association';

      double donorLat = (don['donorLat'] as double?)
          ?? (don['lat'] as double?)
          ?? _defaultLocation.latitude;
      double donorLng = (don['donorLng'] as double?)
          ?? (don['lng'] as double?)
          ?? _defaultLocation.longitude;
      final donorAddress = don['place'] as String? ?? 'Adresse du donateur';

      if (don['donorLat'] == null && donorId.isNotEmpty) {
        try {
          final donorDoc = await FirebaseFirestore.instance
              .collection('users').doc(donorId).get();
          if (donorDoc.exists) {
            donorLat = (donorDoc.data()!['latitude'] as num?)?.toDouble() ?? donorLat;
            donorLng = (donorDoc.data()!['longitude'] as num?)?.toDouble() ?? donorLng;
          }
        } catch (_) {}
      }

      double? associationLat = (don['associationLat'] as num?)?.toDouble();
      double? associationLng = (don['associationLng'] as num?)?.toDouble();
      String? associationAddress;

      if (associationId.isNotEmpty) {
        try {
          final assocDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(associationId)
              .get();
          if (assocDoc.exists) {
            final data = assocDoc.data()!;
            associationLat = (data['associationLat'] as num?)?.toDouble()
                ?? (data['latitude'] as num?)?.toDouble();
            associationLng = (data['associationLng'] as num?)?.toDouble()
                ?? (data['longitude'] as num?)?.toDouble();
            associationAddress = data['quartier'] ?? data['address'] ?? '';

            if (associationLat == null || associationLng == null) {
              associationLat = _defaultAssociationLocation.latitude;
              associationLng = _defaultAssociationLocation.longitude;
            }
          } else {
            associationLat = _defaultAssociationLocation.latitude;
            associationLng = _defaultAssociationLocation.longitude;
            associationAddress = 'Mansourah';
          }
        } catch (e) {
          associationLat = _defaultAssociationLocation.latitude;
          associationLng = _defaultAssociationLocation.longitude;
          associationAddress = 'Mansourah';
        }
      } else {
        associationLat = _defaultAssociationLocation.latitude;
        associationLng = _defaultAssociationLocation.longitude;
        associationAddress = 'Mansourah';
      }

      final finalAssociationLat = associationLat ?? _defaultAssociationLocation.latitude;
      final finalAssociationLng = associationLng ?? _defaultAssociationLocation.longitude;

      final pickupCode = (1000 + Random().nextInt(9000)).toString();

      await FirebaseFirestore.instance.collection('dons').doc(don['donId']).update({
        'status': 'en_livraison',
        'volunteerId': user.uid,
        'volunteerName': benevoleName,
        'volunteerLat': benevoleLat,
        'volunteerLng': benevoleLng,
        'donorLat': donorLat,
        'donorLng': donorLng,
        'donorAddress': donorAddress,
        'associationLat': finalAssociationLat,
        'associationLng': finalAssociationLng,
        'associationAddress': associationAddress,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'pickupCode': pickupCode,
        'pickupCodeUsed': false,
      });

      _startLocationTracking(don['donId']);

      if (mounted) {
        setState(() {
          _selectedDonId = don['donId'];
          _selectedDonorLocation = LatLng(donorLat, donorLng);
          _selectedDonorAddress = donorAddress;
          _selectedAssociationLocation = LatLng(finalAssociationLat, finalAssociationLng);
          _selectedAssociationAddress = associationAddress;
          _dons.removeWhere((d) => d['donId'] == don['donId']);
          _mapKey = UniqueKey();
        });

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _selectedAssociationLocation != null) {
            _mapController.move(_selectedAssociationLocation!, 13.0);
          }
        });
      }

      if (associationId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: associationId,
          title: '✅ Mission acceptée !',
          body: '$benevoleName a accepté la mission "$donTitle"',
          type: 'mission_accepted',
          extraData: {'donId': don['donId']},
        );
      }
      if (donorId.isNotEmpty) {
        await NotificationService.sendNotificationToUser(
          userId: donorId,
          title: '🔐 Code de remise: $pickupCode',
          body: 'Un bénévole arrive pour récupérer votre don. Donnez-lui ce code: $pickupCode',
          type: 'don',
          extraData: {'donId': don['donId']},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mission acceptée ! Toutes les positions sont affichées'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("❌ Erreur acceptMission: $e");
      _showError("Une erreur s'est produite");
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _refuseMission(Map<String, dynamic> don, String reason) async {
    try {
      await FirebaseFirestore.instance.collection('dons').doc(don['donId']).update({
        'status': 'accepte_par_association',
        'refusedBy': FirebaseAuth.instance.currentUser?.uid,
        'refuseReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _dons.remove(don));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Don refusé : ${don['title']}'), backgroundColor: _red),
        );
      }
    } catch (e) {
      print("❌ Erreur refuseMission: $e");
      _showError("Erreur lors du refus");
    }
  }

  void _startLocationTracking(String donId) {
    _locationSubscription?.cancel();
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _locationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      try {
        await FirebaseFirestore.instance.collection('dons').doc(donId).update({
          'volunteerLat': position.latitude,
          'volunteerLng': position.longitude,
          'volunteerUpdatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("❌ Erreur location update: $e");
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _showAcceptDialog(Map<String, dynamic> don) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Accepter la mission', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voulez-vous accepter ce don ?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Text(don['icon'], style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(don['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(don['qty'], style: const TextStyle(fontSize: 12)),
                        Text(don['place'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _acceptMission(don); },
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Accepter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRefuserDialog(Map<String, dynamic> don) {
    String? _selectedReason;
    final _autreController = TextEditingController();
    final reasons = [
      {'icon': '🕐', 'label': 'Pas disponible'},
      {'icon': '📍', 'label': 'Trop loin'},
      {'icon': '🚗', 'label': 'Pas de moyen de transport'},
      {'icon': '✏️', 'label': 'Autre'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: _redBg, borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('❌', style: TextStyle(fontSize: 20)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Refuser ce don', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text(don['title'], style: const TextStyle(fontSize: 11, color: _subText))])),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Pourquoi refusez-vous ?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...reasons.map((r) {
                final selected = _selectedReason == r['label'];
                return GestureDetector(
                  onTap: () => setModalState(() => _selectedReason = r['label'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? _redBg : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? _red : Colors.transparent, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Text(r['icon']!, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(r['label']!, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? _red : _textDark))),
                        if (selected) const Icon(Icons.check_circle, color: _red, size: 18),
                      ],
                    ),
                  ),
                );
              }),
              if (_selectedReason == 'Autre') ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _autreController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Précisez la raison...',
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(height: 48, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('Annuler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _subText)))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectedReason == null ? null : () {
                        Navigator.pop(context);
                        final reason = _selectedReason == 'Autre'
                            ? (_autreController.text.isNotEmpty ? _autreController.text : 'Autre')
                            : _selectedReason!;
                        _refuseMission(don, reason);
                      },
                      child: Container(height: 48, decoration: BoxDecoration(color: _selectedReason != null ? _red : Colors.grey.shade300, borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('Confirmer le refus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'B';
  }

  String _getTransportIcon(String transport) {
    switch (transport) {
      case 'Voiture': return '🚗';
      case 'Moto': return '🏍️';
      case 'Vélo': return '🚲';
      case 'À pied': return '🚶';
      default: return '🚗';
    }
  }

  List<Map<String, dynamic>> get _filteredDons {
    switch (_activeFilter) {
      case '< 1km': return _dons.where((d) => (d['dist'] as double) < 1.0).toList();
      case '< 3km': return _dons.where((d) => (d['dist'] as double) < 3.0).toList();
      case '⚡ Urgent': return _dons.where((d) => d['urgent'] == true).toList();
      default: return _dons;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildMap(),
                  _buildFilterRow(),
                  _buildDonsList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_greenDark, _green, _greenLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 20, left: 18, right: 18),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Text('🌿 ZAD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleNotificationsScreen())),
                      child: Stack(
                        children: [
                          Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20)),
                          if (_unreadNotifCount > 0)
                            Positioned(top: 4, right: 4, child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(color: _orange, shape: BoxShape.circle, border: Border.all(color: _green, width: 1.5)),
                              child: Center(child: Text(
                                _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                                style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white),
                              )),
                            )),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleProfileScreen())),
                      child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: Colors.white, size: 20)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () { _loadDonsFromFirestore(); }),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleProfileScreen())),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.5), width: 2)),
                        child: Center(child: Text(_userInitials.isEmpty ? 'B' : _userInitials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bonjour 👋', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          Text(_userName.isEmpty ? 'Bénévole' : _userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleBadgesScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3), width: 1)),
                        child: Column(
                          children: [
                            Text('⭐ $_userPoints pts', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            Text(_userBadge, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_getTransportIcon(_userTransport)} $_userTransport', style: const TextStyle(fontSize: 12, color: Colors.white)),
                      const SizedBox(width: 12),
                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Text('📍 $_userQuartier', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMap() {
    if (_isLoadingLocation) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        height: 175,
        decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(height: 8), Text('Chargement de votre position...', style: TextStyle(fontSize: 12, color: _subText))])),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 175,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _green.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            FlutterMap(
              key: _mapKey,
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 14.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.zad'),
                MarkerLayer(
                  markers: [
                    Marker(point: _userLocation, width: 24, height: 24, child: Container(decoration: BoxDecoration(color: _blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 10, spreadRadius: 3)]))),
                    if (_selectedDonorLocation != null)
                      Marker(
                        point: _selectedDonorLocation!,
                        width: 36, height: 44,
                        child: Column(children: [
                          Container(width: 34, height: 34, decoration: BoxDecoration(color: _red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 8)]), child: const Center(child: Icon(Icons.person_pin, color: Colors.white, size: 18))),
                          Container(width: 2, height: 8, color: _red),
                        ]),
                      ),
                    if (_selectedAssociationLocation != null)
                      Marker(
                        point: _selectedAssociationLocation!,
                        width: 36, height: 44,
                        child: Column(children: [
                          Container(width: 34, height: 34, decoration: BoxDecoration(color: _green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: _green.withOpacity(0.4), blurRadius: 8)]), child: const Center(child: Icon(Icons.business, color: Colors.white, size: 18))),
                          Container(width: 2, height: 8, color: _green),
                        ]),
                      ),
                    ..._dons.map((don) => Marker(
                      point: LatLng(don['lat'] as double, don['lng'] as double),
                      width: 36, height: 44,
                      child: Column(children: [
                        Container(width: 34, height: 34, decoration: BoxDecoration(color: don['urgent'] == true ? _red : _green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: (don['urgent'] == true ? _red : _green).withOpacity(0.4), blurRadius: 8)]), child: Center(child: Text(don['icon'], style: const TextStyle(fontSize: 16)))),
                        Container(width: 2, height: 8, color: don['urgent'] == true ? _red : _green),
                      ]),
                    )),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 10, right: 12,
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleMapScreen())),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)]), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.map_outlined, color: _green, size: 14), SizedBox(width: 4), Text('Voir tout', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _green))])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = ['Tous', '< 1km', '< 3km', '⚡ Urgent'];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filters.length,
          itemBuilder: (_, i) {
            final active = _activeFilter == filters[i];
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: active ? const LinearGradient(colors: [_greenDark, _green]) : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? _green : _divider, width: 1.5),
                  boxShadow: active ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: Text(filters[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : _subText)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDonsList() {
    if (_dons.isEmpty && _selectedDonId == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(20), border: Border.all(color: _green.withOpacity(0.2))),
        child: const Column(children: [
          Text('🔍', style: TextStyle(fontSize: 36)),
          SizedBox(height: 10),
          Text('Aucune mission disponible', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _greenDark)),
          SizedBox(height: 4),
          Text('Les associations n\'ont pas encore accepté de dons', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _subText)),
        ]),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Container(width: 4, height: 18, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Missions disponibles', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textDark)),
              const Spacer(),
              Text('${_filteredDons.length} résultat(s)', style: const TextStyle(fontSize: 10, color: _subText)),
            ],
          ),
        ),
        ..._filteredDons.map((don) => _buildDonCard(don)),
        if (_selectedDonId != null && _selectedDonorLocation != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _greenPale, borderRadius: BorderRadius.circular(16), border: Border.all(color: _green, width: 1.5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: _green, size: 24),
                    SizedBox(width: 8),
                    Text('Mission acceptée !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Vous: ${_userLocation.latitude.toStringAsFixed(4)}, ${_userLocation.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: _subText))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Donateur: ${_selectedDonorLocation!.latitude.toStringAsFixed(4)}, ${_selectedDonorLocation!.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: _subText)),
                          if (_selectedDonorAddress != null && _selectedDonorAddress!.isNotEmpty)
                            Text('📍 ${_selectedDonorAddress!}', style: const TextStyle(fontSize: 10, color: _red)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_selectedAssociationLocation != null)
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Association: ${_selectedAssociationLocation!.latitude.toStringAsFixed(4)}, ${_selectedAssociationLocation!.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: _subText)),
                            if (_selectedAssociationAddress != null && _selectedAssociationAddress!.isNotEmpty)
                              Text('📍 ${_selectedAssociationAddress!}', style: const TextStyle(fontSize: 10, color: _green)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ✅ التعديل الوحيد: إضافة زر "Voir détails" في الكارت
  Widget _buildDonCard(Map<String, dynamic> don) {
    final isUrgent = don['urgent'] as bool;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: isUrgent ? _red.withOpacity(0.1) : _green.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isUrgent ? [_red, Colors.redAccent] : [_greenDark, _green]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                // أيقونة التبرع
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: isUrgent ? [_redBg, const Color(0xFFFFCDD2)] : [_greenPale, _greenBg]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(don['icon'], style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 12),
                // العنوان والتفاصيل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(don['title'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                          ),
                          if (isUrgent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFE53935)]),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Text('⚡ URGENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(don['place'], style: const TextStyle(fontSize: 10, color: _subText)),
                      const SizedBox(height: 1),
                      Text(don['qty'], style: TextStyle(fontSize: 10, color: isUrgent ? _red : _green, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                // ✅ زر "Voir détails" الجديد
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MissionDetailsScreen(don: don),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: isUrgent ? _redBg : _greenPale,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUrgent ? _red.withOpacity(0.4) : _green.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: isUrgent ? _red : _greenDark),
                        const SizedBox(height: 2),
                        Text('Détails',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isUrgent ? _red : _greenDark,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF9FBF9), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(
                  children: [
                    _chip('📍 ${don['distLabel']}', _greenPale, _greenDark),
                    const SizedBox(width: 6),
                    _chip('⏰ ${don['time']}', isUrgent ? _redBg : _orangeBg, isUrgent ? _red : _orange),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showRefuserDialog(don),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(color: _redBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.3), width: 1)),
                          child: const Center(child: Text('❌ Refuser', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _red))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAcceptDialog(don),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: isUrgent ? [_red, Colors.redAccent] : [_greenDark, _green]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: (isUrgent ? _red : _green).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Center(child: Text(isUrgent ? '🚀 Urgent' : '✅ Accepter', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Accueil'},
      {'icon': Icons.map_rounded, 'label': 'Carte'},
      {'icon': Icons.assignment_rounded, 'label': 'Missions'},
      {'icon': Icons.emoji_events_rounded, 'label': 'Badges'},
      {'icon': Icons.chat_bubble_rounded, 'label': 'Messages'},
    ];

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, -4))]),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8, top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = _currentIndex == i;
          return GestureDetector(
            onTap: () async {
              if (i == 0) {
                setState(() => _currentIndex = i);
              } else if (i == 1) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleMapScreen()));
                if (mounted) setState(() => _currentIndex = 0);
              } else if (i == 2) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleMissionsScreen()));
                if (mounted) setState(() => _currentIndex = 0);
              } else if (i == 3) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleBadgesScreen()));
                if (mounted) setState(() => _currentIndex = 0);
              } else if (i == 4) {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BenevoleMessagesScreen()));
                if (mounted) setState(() => _currentIndex = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: active ? _green.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i]['icon'] as IconData, color: active ? _green : const Color(0xFFBDBDBD), size: 24),
                  const SizedBox(height: 3),
                  Text(items[i]['label'] as String, style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? _green : const Color(0xFFBDBDBD))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}