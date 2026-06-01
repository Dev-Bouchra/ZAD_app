// ============================================================
// 📄 lib/screens/benevole/map_screen.dart
// ✅ يعرض المواقع الثلاثة الحقيقية: البينيفول + المتبرع + الجمعية
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dashboard_screen.dart';

class BenevoleMapScreen extends StatefulWidget {
  // بيانات المهمة المقبولة من Dashboard (اختيارية)
  final bool hasActiveMission;
  final LatLng? donorLocation;
  final String? donorAddress;
  final LatLng? associationLocation;
  final String? associationAddress;

  const BenevoleMapScreen({
    super.key,
    this.hasActiveMission = false,
    this.donorLocation,
    this.donorAddress,
    this.associationLocation,
    this.associationAddress,
  });

  @override
  State<BenevoleMapScreen> createState() => _BenevoleMapScreenState();
}

class _BenevoleMapScreenState extends State<BenevoleMapScreen> {
  static const _green    = Color(0xFF2E7D32);
  static const _greenBg  = Color(0xFFF1F8E9);
  static const _orange   = Color(0xFFFF8F00);
  static const _red      = Color(0xFFD32F2F);
  static const _blue     = Color(0xFF1565C0);
  static const _subText  = Color(0xFF757575);
  static const _textDark = Color(0xFF1B1B1B);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _myLocation = const LatLng(34.8828, -1.3167);
  Map<String, dynamic>? _selectedDon;
  String _activeFilter = 'Tous';
  String _searchQuery = '';
  bool _searchFocused = false;
  bool _isLoading = true;
  bool _isAccepting = false;
  String _userName = '';

  List<Map<String, dynamic>> _allDons = [];

  // المهمة النشطة
  String? _activeMissionId;
  LatLng? _activeDonorLocation;
  String? _activeDonorAddress;
  LatLng? _activeAssociationLocation;
  String? _activeAssociationAddress;

  Key _mapKey = UniqueKey();

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  final LatLng _defaultLocation = const LatLng(34.8828, -1.3167);

  @override
  void initState() {
    super.initState();

    // ✅ إذا كانت هناك مهمة مقبولة من Dashboard، استخدمها
    if (widget.hasActiveMission) {
      _activeMissionId = 'from_dashboard';
      _activeDonorLocation = widget.donorLocation;
      _activeDonorAddress = widget.donorAddress;
      _activeAssociationLocation = widget.associationLocation;
      _activeAssociationAddress = widget.associationAddress;
    }

    _init();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _getLocation();
    await _loadUserName();
    // ✅ جلب المهمة النشطة من Firestore إذا لم تأتِ من Dashboard
    if (!widget.hasActiveMission) {
      await _loadActiveMissionFromFirestore();
    }
    await _loadDons();

    // تحريك الخريطة للموقع المناسب
    if (_activeAssociationLocation != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _mapController.move(_activeAssociationLocation!, 13.0);
      });
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      }
    } catch (e) {
      debugPrint("❌ Location error: $e");
    }
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _userName = doc.data()?['name'] ?? 'Bénévole');
      }
    } catch (_) {}
  }

  // ✅ دالة جديدة: جلب المهمة النشطة (en_route) من Firestore للبينيفول الحالي
  Future<void> _loadActiveMissionFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // البحث عن مهمة نشطة للبينيفول الحالي
      final snapshot = await FirebaseFirestore.instance
          .collection('dons')
          .where('volunteerId', isEqualTo: user.uid)
          .where('status', whereIn: ['en_route', 'en_livraison', 'recu_par_benevole'])
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint("ℹ️ Aucune mission active trouvée pour ce bénévole");
        return;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      final donId = doc.id;

      debugPrint("✅ Mission active trouvée: $donId");

      // ✅ إحداثيات المتبرع
      final donorLat = (data['donorLat'] as num?)?.toDouble();
      final donorLng = (data['donorLng'] as num?)?.toDouble();
      final donorAddress = data['donorAddress'] ?? data['address'] ?? '';

      // ✅ إحداثيات الجمعية - أولاً من وثيقة الدون، ثم من ملف الجمعية
      double? assocLat = (data['associationLat'] as num?)?.toDouble();
      double? assocLng = (data['associationLng'] as num?)?.toDouble();
      String? assocAddress = data['associationAddress'] ?? data['associationName'] ?? '';

      // إذا لم تكن الإحداثيات موجودة في الدون، جلبها من ملف الجمعية
      final associationId = data['associationId'] as String? ?? '';
      if ((assocLat == null || assocLng == null) && associationId.isNotEmpty) {
        try {
          final assocDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(associationId)
              .get();
          if (assocDoc.exists) {
            final assocData = assocDoc.data()!;
            assocLat = (assocData['associationLat'] as num?)?.toDouble()
                ?? (assocData['latitude'] as num?)?.toDouble();
            assocLng = (assocData['associationLng'] as num?)?.toDouble()
                ?? (assocData['longitude'] as num?)?.toDouble();
            assocAddress = assocData['quartier'] ?? assocData['address'] ?? assocAddress;
            debugPrint("✅ Position association récupérée du profil: $assocLat, $assocLng");
          }
        } catch (e) {
          debugPrint("⚠️ Impossible de récupérer la position de l'association: $e");
        }
      }

      // ✅ إحداثيات المتبرع - إذا لم تكن في الدون، جلبها من ملف المتبرع
      if (donorLat == null || donorLng == null) {
        final donorId = data['donorId'] as String? ?? '';
        if (donorId.isNotEmpty) {
          try {
            final donorDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(donorId)
                .get();
            if (donorDoc.exists) {
              final donorData = donorDoc.data()!;
              final fetchedLat = (donorData['latitude'] as num?)?.toDouble();
              final fetchedLng = (donorData['longitude'] as num?)?.toDouble();
              if (fetchedLat != null && fetchedLng != null && mounted) {
                setState(() {
                  _activeMissionId = donId;
                  _activeDonorLocation = LatLng(fetchedLat, fetchedLng);
                  _activeDonorAddress = donorAddress;
                  if (assocLat != null && assocLng != null) {
                    _activeAssociationLocation = LatLng(assocLat!, assocLng!);
                    _activeAssociationAddress = assocAddress;
                  }
                });
                _startLocationTracking(donId);
                return;
              }
            }
          } catch (e) {
            debugPrint("⚠️ Impossible de récupérer la position du donateur: $e");
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeMissionId = donId;
          if (donorLat != null && donorLng != null) {
            _activeDonorLocation = LatLng(donorLat, donorLng);
            _activeDonorAddress = donorAddress;
          }
          if (assocLat != null && assocLng != null) {
            _activeAssociationLocation = LatLng(assocLat!, assocLng!);
            _activeAssociationAddress = assocAddress;
          }
        });
        _startLocationTracking(donId);
      }

      debugPrint("📍 Donateur: $_activeDonorLocation");
      debugPrint("🏢 Association: $_activeAssociationLocation");
    } catch (e) {
      debugPrint("❌ Erreur loadActiveMission: $e");
    }
  }

  Future<void> _loadDons() async {
    try {
      setState(() => _isLoading = true);

      QuerySnapshot snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('dons')
            .where('status', isEqualTo: 'accepte_par_association')
            .orderBy('createdAt', descending: true)
            .get();
      } catch (_) {
        snapshot = await FirebaseFirestore.instance
            .collection('dons')
            .where('status', isEqualTo: 'accepte_par_association')
            .get();
      }

      if (mounted) {
        setState(() {
          _allDons = snapshot.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;

            // ✅ نستعمل donorLat/donorLng أولاً (المحفوظ من الخريطة)
            final donLat = (d['donorLat'] as num?)?.toDouble()
                ?? (d['latitude'] as num?)?.toDouble()
                ?? _myLocation.latitude;
            final donLng = (d['donorLng'] as num?)?.toDouble()
                ?? (d['longitude'] as num?)?.toDouble()
                ?? _myLocation.longitude;

            final dist = _calcDist(_myLocation, LatLng(donLat, donLng));
            final distLabel = dist < 1
                ? '${(dist * 1000).toInt()} m'
                : '${dist.toStringAsFixed(1)} km';

            return {
              'donId': doc.id,
              'icon': _getIcon(d['title']),
              'title': d['title'] ?? 'Don',
              'place': d['address'] ?? '',
              'qty': d['quantity'] ?? '',
              'dist': distLabel,
              'distKm': dist,
              'time': '30 min',
              'urgent': d['isUrgent'] == true,
              'lat': donLat,
              'lng': donLng,
              'associationName': d['associationName'] ?? '',
              'associationId': d['associationId'] ?? '',
              'donorName': d['donorName'] ?? '',
              'donorId': d['donorId'] ?? '',
              'donorAddress': d['address'] ?? '',
              // ✅ نحفظ الإحداثيات الصحيحة (من الخريطة أولاً)
              'donorLat': (d['donorLat'] as num?)?.toDouble()
                  ?? (d['latitude'] as num?)?.toDouble(),
              'donorLng': (d['donorLng'] as num?)?.toDouble()
                  ?? (d['longitude'] as num?)?.toDouble(),
              'associationLat': (d['associationLat'] as num?)?.toDouble(),
              'associationLng': (d['associationLng'] as num?)?.toDouble(),
              'associationAddress': d['associationAddress'] ?? '',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur loadDons map: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calcDist(LatLng a, LatLng b) {
    const R = 6371.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  String _getIcon(String? title) {
    if (title == null) return '🍽️';
    final t = title.toLowerCase();
    if (t.contains('pain') || t.contains('boulangerie')) return '🍞';
    if (t.contains('repas') || t.contains('plat')) return '🍲';
    if (t.contains('légume') || t.contains('fruit')) return '🥦';
    if (t.contains('pâtisserie')) return '🍰';
    if (t.contains('conserve')) return '🥫';
    return '🍽️';
  }

  List<Map<String, dynamic>> get _filteredDons {
    return _allDons.where((don) {
      final passFilter = switch (_activeFilter) {
        '< 1km'     => (don['distKm'] as double) < 1.0,
        '< 3km'     => (don['distKm'] as double) < 3.0,
        '⚡ Urgent' => don['urgent'] == true,
        _           => true,
      };
      final query = _searchQuery.toLowerCase().trim();
      final passSearch = query.isEmpty ||
          (don['title'] as String).toLowerCase().contains(query) ||
          (don['place'] as String).toLowerCase().contains(query);
      return passFilter && passSearch;
    }).toList();
  }

  Future<void> _acceptMission(Map<String, dynamic> don) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ✅ إحداثيات المتبرع
      // ✅ نستعمل donorLat/donorLng المحفوظة من الخريطة أولاً
      double donorLat = (don['donorLat'] as double?)
          ?? (don['lat'] as double?)
          ?? _myLocation.latitude;
      double donorLng = (don['donorLng'] as double?)
          ?? (don['lng'] as double?)
          ?? _myLocation.longitude;
      final donorAddress = don['place'] as String? ?? 'Adresse du donateur';

      // إذا فاتت null — نجيبها من ملف المتبرع
      final donorId = don['donorId'] as String? ?? '';
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

      // ✅ إحداثيات الجمعية
      double? associationLat = don['associationLat'] as double?;
      double? associationLng = don['associationLng'] as double?;
      String? associationAddress = don['associationAddress'] as String?;
      final associationId = don['associationId'] as String? ?? '';

      // إذا لم تكن في الدون، جلبها من ملف الجمعية
      if ((associationLat == null || associationLng == null) && associationId.isNotEmpty) {
        try {
          final assocDoc = await FirebaseFirestore.instance
              .collection('users').doc(associationId).get();
          if (assocDoc.exists) {
            final data = assocDoc.data()!;
            associationLat = (data['associationLat'] as num?)?.toDouble()
                ?? (data['latitude'] as num?)?.toDouble();
            associationLng = (data['associationLng'] as num?)?.toDouble()
                ?? (data['longitude'] as num?)?.toDouble();
            associationAddress ??= data['quartier'] ?? data['address'] ?? '';
          }
        } catch (e) {
          debugPrint("❌ Erreur fetch association: $e");
        }
      }

      // قيم افتراضية إذا لم تُوجد
      associationLat ??= _defaultLocation.latitude;
      associationLng ??= _defaultLocation.longitude;

      // ✅ توليد كود تأكيد 4 أرقام
      final pickupCode = (1000 + Random().nextInt(9000)).toString();

      await FirebaseFirestore.instance
          .collection('dons')
          .doc(don['donId'])
          .update({
        'status':           'en_route',
        'volunteerId':      user.uid,
        'volunteerName':    _userName,
        'volunteerLat':     _myLocation.latitude,
        'volunteerLng':     _myLocation.longitude,
        'donorLat':         donorLat,
        'donorLng':         donorLng,
        'donorAddress':     donorAddress,
        'associationLat':   associationLat,
        'associationLng':   associationLng,
        'associationAddress': associationAddress,
        'pickupCode':       pickupCode,   // ✅
        'pickupCodeUsed':   false,        // ✅
        'acceptedAt':       FieldValue.serverTimestamp(),
        'updatedAt':        FieldValue.serverTimestamp(),
      });

      // ✅ إشعار للمتبرع بالكود
      final donorId2 = don['donorId'] as String? ?? '';
      final donTitle2 = don['title'] as String? ?? 'Don';
      if (donorId2.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId':    donorId2,
            'title':    '🔐 Code de remise : $pickupCode',
            'body':     '$_userName arrive pour récupérer "$donTitle2". Donnez-lui ce code.',
            'type':     'pickup_code',
            'read':     false,
            'extraData': {'donId': don['donId'], 'code': pickupCode},
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      setState(() {
        _activeMissionId = don['donId'];
        _activeDonorLocation = LatLng(donorLat, donorLng);
        _activeDonorAddress = donorAddress;
        _activeAssociationLocation = LatLng(associationLat!, associationLng!);
        _activeAssociationAddress = associationAddress;
        _allDons.removeWhere((d) => d['donId'] == don['donId']);
        _mapKey = UniqueKey();
      });

      _startLocationTracking(don['donId']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mission acceptée ! Les 3 positions sont affichées'),
            backgroundColor: _green,
          ),
        );
        setState(() => _selectedDon = null);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _activeAssociationLocation != null) {
            _mapController.move(_activeAssociationLocation!, 13.0);
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Erreur acceptMission: $e");
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _startLocationTracking(String donId) {
    _locationTimer?.cancel();
    _sendLocationToFirestore(donId);
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sendLocationToFirestore(donId);
    });
  }

  Future<void> _sendLocationToFirestore(String donId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      await FirebaseFirestore.instance.collection('dons').doc(donId).update({
        'volunteerLat': pos.latitude,
        'volunteerLng': pos.longitude,
      });
    } catch (e) {
      debugPrint("❌ Erreur envoi position: $e");
    }
  }

  Widget _buildDonorMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _red, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: _red.withOpacity(0.5), blurRadius: 10)],
          ),
          child: const Center(
            child: Icon(Icons.person_pin_circle, color: Colors.white, size: 20),
          ),
        ),
        Container(width: 2, height: 8, color: _red),
      ],
    );
  }

  Widget _buildAssociationMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _green, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: _green.withOpacity(0.5), blurRadius: 10)],
          ),
          child: const Center(
            child: Icon(Icons.business, color: Colors.white, size: 20),
          ),
        ),
        Container(width: 2, height: 8, color: _green),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dons = _filteredDons;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          FlutterMap(
            key: _mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation,
              initialZoom: 14.5,
              onTap: (_, __) => setState(() {
                _selectedDon = null;
                _searchFocused = false;
                FocusScope.of(context).unfocus();
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.zad',
              ),
              MarkerLayer(
                markers: [
                  // 🔵 موقع البينيفول (أنا)
                  Marker(
                    point: _myLocation,
                    width: 24, height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _blue, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: _blue.withOpacity(0.4), blurRadius: 10)],
                      ),
                    ),
                  ),

                  // 🔴 موقع المتبرع (الحقيقي)
                  if (_activeDonorLocation != null)
                    Marker(
                      point: _activeDonorLocation!,
                      width: 46, height: 54,
                      child: _buildDonorMarker(),
                    ),

                  // 🟢 موقع الجمعية (الحقيقي)
                  if (_activeAssociationLocation != null)
                    Marker(
                      point: _activeAssociationLocation!,
                      width: 46, height: 54,
                      child: _buildAssociationMarker(),
                    ),

                  // دبابيس الدونات المتاحة
                  ...dons.map((don) => Marker(
                    point: LatLng(don['lat'], don['lng']),
                    width: 44, height: 50,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedDon = don;
                        _searchFocused = false;
                        FocusScope.of(context).unfocus();
                      }),
                      child: Column(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: don['urgent'] ? _red : _green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedDon == don
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [BoxShadow(
                                  color: (don['urgent'] ? _red : _green)
                                      .withOpacity(0.4),
                                  blurRadius: 8)],
                            ),
                            child: Center(
                              child: Text(don['icon'],
                                  style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                          Container(
                              width: 2,
                              height: 8,
                              color: don['urgent'] ? _red : _green),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ],
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // شريط المهمة النشطة
          if (_activeMissionId != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 60, right: 60,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _green.withOpacity(0.4), blurRadius: 8)
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 6),
                    Text('📍 Mission en cours',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // AppBar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 14,
                  right: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.97),
                    Colors.white.withOpacity(0.0)
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8)
                          ]),
                      child:
                          const Icon(Icons.arrow_back, color: _green, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8)
                          ]),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                        onTap: () =>
                            setState(() => _searchFocused = true),
                        style:
                            const TextStyle(fontSize: 12, color: _textDark),
                        decoration: InputDecoration(
                          hintText: _searchFocused
                              ? 'Rechercher...'
                              : 'Dons autour de moi',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: _subText),
                          prefixIcon: const Icon(Icons.search,
                              color: _green, size: 16),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loadDons,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8)
                          ]),
                      child:
                          const Icon(Icons.refresh, color: _green, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // أزرار الفلتر
          Positioned(
            top: MediaQuery.of(context).padding.top + 58,
            left: 0, right: 0,
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: ['Tous', '< 1km', '< 3km', '⚡ Urgent'].map((f) {
                  final active = _activeFilter == f;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _activeFilter = f;
                      _selectedDon = null;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? _green : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6)
                        ],
                      ),
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : _subText)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // بطاقة الدون المختار
          if (_selectedDon != null)
            Positioned(
              bottom: 20, left: 14, right: 14,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                      left: BorderSide(
                          color: _selectedDon!['urgent'] ? _red : _green,
                          width: 3)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12), blurRadius: 16)
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                              color: _selectedDon!['urgent']
                                  ? const Color(0xFFFFEBEE)
                                  : _greenBg,
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Text(_selectedDon!['icon'],
                                  style: const TextStyle(fontSize: 26))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedDon!['title'],
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text(_selectedDon!['place'],
                                  style: const TextStyle(
                                      fontSize: 10, color: _subText)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _selectedDon = null),
                          child: const Icon(Icons.close,
                              color: _subText, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _chip('📍 ${_selectedDon!['dist']}', _greenBg, _green),
                        const SizedBox(width: 6),
                        _chip('📦 ${_selectedDon!['qty']}',
                            const Color(0xFFE3F2FD), _blue),
                        const Spacer(),
                        GestureDetector(
                          onTap: _isAccepting
                              ? null
                              : () => _acceptMission(_selectedDon!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isAccepting
                                  ? Colors.grey
                                  : (_selectedDon!['urgent'] ? _red : _green),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _isAccepting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(
                                    _selectedDon!['urgent']
                                        ? '🚀 Urgent'
                                        : '✅ Accepter',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // زر تمركز على موقعي
          Positioned(
            bottom: _selectedDon != null ? 160 : 20,
            right: 14,
            child: GestureDetector(
              onTap: () => _mapController.move(_myLocation, 14.5),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12), blurRadius: 8)
                    ]),
                child: const Icon(Icons.my_location, color: _blue, size: 22),
              ),
            ),
          ),

          // مفتاح الألوان (Legend)
          if (_activeDonorLocation != null ||
              _activeAssociationLocation != null)
            Positioned(
              bottom: _selectedDon != null ? 160 : 20,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 8)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: _blue, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Vous', style: TextStyle(fontSize: 10)),
                    ]),
                    if (_activeDonorLocation != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                                color: _red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('Donateur',
                            style: TextStyle(fontSize: 10)),
                      ]),
                      if (_activeDonorAddress != null &&
                          _activeDonorAddress!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(_activeDonorAddress!,
                              style: const TextStyle(
                                  fontSize: 9, color: _red)),
                        ),
                    ],
                    if (_activeAssociationLocation != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                                color: _green, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('Association',
                            style: TextStyle(fontSize: 10)),
                      ]),
                      if (_activeAssociationAddress != null &&
                          _activeAssociationAddress!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 18),
                          child: Text(_activeAssociationAddress!,
                              style: const TextStyle(
                                  fontSize: 9, color: _green)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}