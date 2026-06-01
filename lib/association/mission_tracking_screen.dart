import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'confirmer_reception_screen.dart'; // ✅ إضافة import

class MissionTrackingScreen extends StatefulWidget {
  final String donId;
  final bool isAssociation;
  const MissionTrackingScreen({super.key, required this.donId, this.isAssociation = false});

  @override
  State<MissionTrackingScreen> createState() => _MissionTrackingScreenState();
}

class _MissionTrackingScreenState extends State<MissionTrackingScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  StreamSubscription<DocumentSnapshot>? _donStream;

  LatLng? _volunteerLocation;
  LatLng? _donorLocation;
  LatLng? _associationLocation;
  LatLng? _currentUserLocation;

  String _volunteerName = '';
  String _volunteerInitials = 'BN';
  double _volunteerRating = 4.8;
  int _volunteerMissions = 0;
  String _donQuantity = '';
  String _donStatus = '';
  bool _isLoading = true;
  bool _benevoleArrived = false;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  static const double _arrivalThresholdMeters = 200.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenToDon();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentUserLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint("Erreur location: $e");
    }
  }

  void _listenToDon() {
    _donStream = FirebaseFirestore.instance
        .collection('dons')
        .doc(widget.donId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;

      final double? vLat = (d['volunteerLat'] as num?)?.toDouble();
      final double? vLng = (d['volunteerLng'] as num?)?.toDouble();

      double? donorLat = (d['donorLat'] as num?)?.toDouble();
      double? donorLng = (d['donorLng'] as num?)?.toDouble();

      if (donorLat == null || donorLng == null) {
        final String donorId = d['donorId'] as String? ?? '';
        if (donorId.isNotEmpty) {
          try {
            final donorDoc = await FirebaseFirestore.instance
                .collection('users').doc(donorId).get();
            if (donorDoc.exists) {
              donorLat = (donorDoc.data()?['lat'] as num?)?.toDouble()
                      ?? (donorDoc.data()?['latitude'] as num?)?.toDouble()
                      ?? (donorDoc.data()?['locationLat'] as num?)?.toDouble();
              donorLng = (donorDoc.data()?['lng'] as num?)?.toDouble()
                      ?? (donorDoc.data()?['longitude'] as num?)?.toDouble()
                      ?? (donorDoc.data()?['locationLng'] as num?)?.toDouble();
            }
          } catch (_) {}
        }
      }

      final double assocLat = (d['associationLat'] as num?)?.toDouble() ?? 34.8700;
      final double assocLng = (d['associationLng'] as num?)?.toDouble() ?? -1.3200;

      String volunteerName = d['volunteerName'] ?? '';
      final String volunteerId = d['volunteerId'] ?? '';
      double rating = 4.8;
      int missions = 0;

      if (volunteerId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users').doc(volunteerId).get();
          if (userDoc.exists) {
            final ud = userDoc.data()!;
            volunteerName = ud['name'] ?? volunteerName;
            rating = (ud['rating'] as num?)?.toDouble() ?? 4.8;
            missions = (ud['completedMissions'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}
      }

      String initials = 'BN';
      if (volunteerName.isNotEmpty) {
        final parts = volunteerName.trim().split(' ');
        initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : volunteerName.substring(0, volunteerName.length.clamp(0, 2)).toUpperCase();
      }

      bool arrived = false;
      if (vLat != null && vLng != null) {
        final distM = const Distance().as(
          LengthUnit.Meter,
          LatLng(vLat, vLng),
          LatLng(assocLat, assocLng),
        );
        arrived = distM < _arrivalThresholdMeters;
      }

      if (!mounted) return;
      setState(() {
        _volunteerName = volunteerName.isEmpty ? 'Bénévole' : volunteerName;
        _volunteerInitials = initials;
        _volunteerRating = rating;
        _volunteerMissions = missions;
        _donQuantity = d['quantity']?.toString() ?? '';
        _donStatus = d['status'] ?? '';
        _donorLocation = (donorLat != null && donorLng != null)
            ? LatLng(donorLat!, donorLng!)
            : null;
        _associationLocation = LatLng(assocLat, assocLng);
        _benevoleArrived = arrived;

        if (vLat != null && vLng != null) {
          _volunteerLocation = LatLng(vLat, vLng);
        }

        if (_isLoading) {
          _isLoading = false;
          final center = _currentUserLocation ?? _volunteerLocation ?? _donorLocation;
          if (center != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _mapController.move(center, 12.0);
            });
          }
        }
      });
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        _mapController.move(target, 15.0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📍 Adresse trouvée')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adresse non trouvée: $query')),
        );
      }
    }
    if (mounted) setState(() => _isSearching = false);
  }

  String _calcDistance(LatLng? a, LatLng? b) {
    if (a == null || b == null) return '—';
    final dist = const Distance().as(LengthUnit.Kilometer, a, b);
    if (dist < 1) return '${(dist * 1000).toInt()} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    _donStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _currentUserLocation ??
        _volunteerLocation ??
        _donorLocation ??
        const LatLng(34.8828, -1.3167);

    final targetPos = _associationLocation;

    final distVal = _benevoleArrived
        ? '< 200m'
        : _calcDistance(_volunteerLocation, targetPos);

    final timeVal = _benevoleArrived ? 'Arrivé' : '~5 min';

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : Stack(
              children: [
                // ========== MAP ==========
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 12.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.zad',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        if (_donorLocation != null)
                          Marker(
                            point: _donorLocation!,
                            width: 70,
                            height: 65,
                            alignment: Alignment.bottomCenter,
                            child: _buildDonorMarker(),
                          ),
                        if (_associationLocation != null)
                          Marker(
                            point: _associationLocation!,
                            width: 80,
                            height: 65,
                            alignment: Alignment.bottomCenter,
                            child: _buildAssocMarker(),
                          ),
                        if (_volunteerLocation != null)
                          Marker(
                            point: _volunteerLocation!,
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            child: _buildVolunteerMarker(),
                          ),
                      ],
                    ),
                  ],
                ),

                // ========== HEADER ==========
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8),
                                ],
                              ),
                              child: const Icon(Icons.arrow_back,
                                  color: Color(0xFF1B5E20)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onSubmitted: _searchLocation,
                                decoration: InputDecoration(
                                  hintText: 'Rechercher...',
                                  prefixIcon: const Icon(Icons.search,
                                      color: Color(0xFF1B5E20)),
                                  suffixIcon: _isSearching
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)))
                                      : IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () =>
                                              _searchController.clear()),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ========== Bottom Panel ==========
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 44,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(2))),
                            _buildVolunteerCard(),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(
                                    icon: Icons.access_time,
                                    label: 'Temps estimé',
                                    value: timeVal,
                                    color: const Color(0xFF1B5E20),
                                    bgColor: const Color(0xFFF1F8E9)),
                                const SizedBox(width: 10),
                                _StatCard(
                                    icon: Icons.route,
                                    label: 'Distance vers asso',
                                    value: distVal,
                                    color: const Color(0xFF2E7D7D),
                                    bgColor: const Color(0xFFE0F7FA)),
                                const SizedBox(width: 10),
                                _StatCard(
                                    icon: Icons.inventory,
                                    label: 'Quantité',
                                    value: _donQuantity.isNotEmpty
                                        ? _donQuantity
                                        : '—',
                                    color: const Color(0xFFE65100),
                                    bgColor: const Color(0xFFFFF3E0)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildMainButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVolunteerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF8FAF8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8ECF0))),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF1B5E20)]),
                shape: BoxShape.circle),
            child: Center(
                child: Text(_volunteerInitials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_volunteerName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.star, color: Color(0xFFFFB800), size: 14),
                  const SizedBox(width: 3),
                  Text(
                      '${_volunteerRating.toStringAsFixed(1)} · $_volunteerMissions missions',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7A8D)))
                ]),
                const SizedBox(height: 4),
                Text(
                    _benevoleArrived
                        ? "Est arrivé à l'association"
                        : "En route vers l'association",
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7A8D))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    final canConfirm =
        widget.isAssociation && _donStatus == 'recu_par_benevole';

    if (canConfirm) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          // ✅ التعديل: يفتح ConfirmerReceptionScreen بدل ما يحفظ مباشرة
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ConfirmerReceptionScreen(donId: widget.donId),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            'Confirmer la réception',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFDDE3EA))),
      child: Center(
        child: Text(
          _donStatus == 'en_livraison'
              ? '⏳ En attente de récupération chez donateur'
              : '⏳ En attente du bénévole... (< 200m)',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDonorMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(alignment: Alignment.center, children: [
            Container(
                width: 50 * _pulseAnimation.value,
                height: 50 * _pulseAnimation.value,
                decoration: BoxDecoration(
                    color: const Color(0xFFE53935)
                        .withValues(alpha: 0.15 * _pulseAnimation.value),
                    shape: BoxShape.circle)),
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE53935).withValues(alpha: 0.3),
                          blurRadius: 8)
                    ],
                    border: Border.all(
                        color: const Color(0xFFE53935), width: 2.5)),
                child: const Icon(Icons.person_pin,
                    color: Color(0xFFE53935), size: 20)),
          ]),
          const SizedBox(height: 2),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Donateur',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildAssocMarker() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(alignment: Alignment.center, children: [
            Container(
                width: 50 * _pulseAnimation.value,
                height: 50 * _pulseAnimation.value,
                decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20)
                        .withValues(alpha: 0.15 * _pulseAnimation.value),
                    shape: BoxShape.circle)),
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                          blurRadius: 8)
                    ],
                    border: Border.all(
                        color: const Color(0xFF1B5E20), width: 2.5)),
                child: const Icon(Icons.business,
                    color: Color(0xFF1B5E20), size: 20)),
          ]),
          const SizedBox(height: 2),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Association',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildVolunteerMarker() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: _benevoleArrived
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1565C0),
            width: 3),
        boxShadow: [
          BoxShadow(
              color: (_benevoleArrived
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF1565C0))
                  .withValues(alpha: 0.4),
              blurRadius: 10)
        ],
      ),
      child: Icon(
          _benevoleArrived ? Icons.check_circle : Icons.directions_bike,
          color: _benevoleArrived
              ? const Color(0xFF2E7D32)
              : const Color(0xFF1565C0),
          size: 24),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF9E9E9E))),
          ],
        ),
      ),
    );
  }
}