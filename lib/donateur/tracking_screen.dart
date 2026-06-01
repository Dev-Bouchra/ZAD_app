// lib/screens/donateur/tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'signaler_probleme_screen.dart'; // ✅ استيراد صفحة الإبلاغ عن مشكلة
import '../shared/zad_colors.dart';
class TrackingScreen extends StatefulWidget {
  final String donId;

  const TrackingScreen({super.key, required this.donId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<DocumentSnapshot>? _donStream;

  // بيانات من Firestore
  LatLng? _volunteerLocation;
  LatLng? _donorLocation;      // موقع المتبرع (الـ pickup)
  LatLng? _destinationLocation; // موقع الجمعية (الـ destination)

  String _volunteerName = '';
  String _volunteerInitials = '';
  String _volunteerPhone = '';
  String _volunteerId = '';
  String _donTitle = '';
  String _donQuantity = '';
  String _donAddress = '';
  String _donDescription = ''; // ✅ إضافة وصف التبرع
  String _donStatus = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToDon();
  }

  void _listenToDon() {
    _donStream = FirebaseFirestore.instance
        .collection('dons')
        .doc(widget.donId)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;

      // موقع البينيفول (يتحدث كل لحظة)
      final double? vLat = (d['volunteerLat'] as num?)?.toDouble();
      final double? vLng = (d['volunteerLng'] as num?)?.toDouble();

      // موقع نقطة الاستلام (المتبرع)
      final double pickupLat =
          (d['donorLat'] as num?)?.toDouble() ?? 
          (d['latitude'] as num?)?.toDouble() ?? 34.8828;
      final double pickupLng =
          (d['donorLng'] as num?)?.toDouble() ?? 
          (d['longitude'] as num?)?.toDouble() ?? -1.3167;

      // موقع الجمعية (الوجهة)
      final double assocLat =
          (d['associationLat'] as num?)?.toDouble() ?? 34.8900;
      final double assocLng =
          (d['associationLng'] as num?)?.toDouble() ?? -1.3200;

      final String volunteerId = d['volunteerId'] ?? '';
      String volunteerName = d['volunteerName'] ?? '';
      String volunteerPhone = '';
      String volunteerInitials = '';

      // جلب بيانات البينيفول من users إذا لزم
      if (volunteerId.isNotEmpty && volunteerName.isEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(volunteerId)
              .get();
          if (userDoc.exists) {
            volunteerName = userDoc.data()?['name'] ?? 'Bénévole';
            volunteerPhone = userDoc.data()?['phone'] ?? '';
          }
        } catch (_) {}
      }

      // جلب رقم الهاتف إذا لم يكن في don
      if (volunteerId.isNotEmpty && volunteerPhone.isEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(volunteerId)
              .get();
          volunteerPhone = userDoc.data()?['phone'] ?? '';
        } catch (_) {}
      }

      // الأحرف الأولى من الاسم
      if (volunteerName.isNotEmpty) {
        final parts = volunteerName.trim().split(' ');
        volunteerInitials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : volunteerName.substring(0, volunteerName.length.clamp(0, 2)).toUpperCase();
      }

      // ✅ التعديل هنا: قراءة الحالة من statut أو status
      final currentStatus = d['statut'] ?? d['status'] ?? '';

      if (!mounted) return;
      setState(() {
        _volunteerName = volunteerName;
        _volunteerInitials = volunteerInitials.isNotEmpty ? volunteerInitials : 'BN';
        _volunteerPhone = volunteerPhone;
        _volunteerId = volunteerId;
        _donTitle = d['title'] ?? d['produit'] ?? 'Don';
        _donQuantity = d['quantity']?.toString() ?? d['quantite']?.toString() ?? '';
        _donAddress = d['address'] ?? d['donorAddress'] ?? '';
        _donDescription = d['description'] ?? d['descriptionDon'] ?? '—'; // ✅ قراءة الوصف
        _donStatus = currentStatus;
        _donorLocation = LatLng(pickupLat, pickupLng);
        _destinationLocation = LatLng(assocLat, assocLng);
        if (vLat != null && vLng != null) {
          _volunteerLocation = LatLng(vLat, vLng);
          // نحرك الكاميرا على موقع البينيفول
          try {
            _mapController.move(_volunteerLocation!, 15);
          } catch (_) {}
        }
        _isLoading = false;
      });
    }, onError: (e) {
      debugPrint('❌ Stream error: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _donStream?.cancel();
    super.dispose();
  }

  // حساب المسافة التقريبية بين نقطتين (كيلومتر)
  String _calcDistance(LatLng? a, LatLng? b) {
    if (a == null || b == null) return '...';
    final dist = const Distance().as(LengthUnit.Kilometer, a, b);
    if (dist < 1) return '${(dist * 1000).toInt()} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  // تقدير الوقت (3 دقائق لكل كيلومتر)
  String _calcTime(LatLng? a, LatLng? b) {
    if (a == null || b == null) return '...';
    final dist = const Distance().as(LengthUnit.Kilometer, a, b);
    final minutes = (dist * 3).ceil().clamp(1, 999);
    return '~$minutes min';
  }

  String _statusLabel() {
    switch (_donStatus) {
      case 'en_cours':
      case 'en_route':
        return 'En route vers vous';
      case 'en_livraison':
        return 'En route vers l\'association';
      case 'livre':
        return 'Livré ✓';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    // نقطة البينيفول أو fallback
    final volunteerPos = _volunteerLocation ?? _donorLocation;
    // مركز الخريطة
    final mapCenter = volunteerPos ?? const LatLng(34.8828, -1.3167);

    return Scaffold(
      backgroundColor: ZADColors.background,
      body: Column(
        children: [
          // ── Header ──
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
                        MaterialPageRoute(
                            builder: (_) => const HomeScreen()),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                    const Expanded(
                      child: Text('Suivi du bénévole',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 26),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVolunteerCard(),
                        const SizedBox(height: 16),
                        _buildMapCard(mapCenter, volunteerPos),
                        const SizedBox(height: 16),
                        _buildDonationDetails(),
                        const SizedBox(height: 16),
                        _buildActionButtons(context),
                        const SizedBox(height: 16),
                        _buildSignalerProblemeButton(context), // ✅ زر الإبلاغ عن مشكلة
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const ZADBottomNav(currentIndex: 0),
    );
  }

  // ── بطاقة البينيفول ──
  Widget _buildVolunteerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ZADColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(_volunteerInitials,
                  style: const TextStyle(
                      color: ZADColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _volunteerName.isEmpty ? 'Bénévole' : _volunteerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: ZADColors.textDark),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: ZADColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_statusLabel(),
                        style: const TextStyle(
                            color: ZADColors.textMedium, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── بطاقة الخريطة ──
  Widget _buildMapCard(LatLng mapCenter, LatLng? volunteerPos) {
    // نقاط الـ polyline
    final List<LatLng> routePoints = [];
    if (volunteerPos != null && _donorLocation != null) {
      routePoints.addAll([volunteerPos, _donorLocation!]);
    }

    final distToYou = _calcDistance(_volunteerLocation, _donorLocation);
    final timeToYou = _calcTime(_volunteerLocation, _donorLocation);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_outlined,
                  color: ZADColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Position du bénévole',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ZADColors.textDark)),
              const Spacer(),
              // وقت الوصول الحقيقي
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ZADColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer,
                        color: ZADColors.primary, size: 14),
                    const SizedBox(width: 4),
                    Text(timeToYou,
                        style: const TextStyle(
                            color: ZADColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // إذا الموقع موجود → نعرضه، وإلا رسالة انتظار
          if (_volunteerLocation == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_searching,
                      color: Color(0xFFFF8F00), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En attente de la position du bénévole...',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF8F00)),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Position actuelle: ${distToYou} de votre adresse',
              style: const TextStyle(
                  color: ZADColors.textMedium, fontSize: 12),
            ),
          const SizedBox(height: 12),

          // الخريطة الحقيقية
          SizedBox(
            height: 280,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.zad.donateur',
                  ),
                  // خط المسار
                  if (routePoints.length == 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: ZADColors.primary,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // ماركر موقع المتبرع (أنت)
                      if (_donorLocation != null)
                        Marker(
                          point: _donorLocation!,
                          width: 50,
                          height: 50,
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person,
                                    color: Colors.white, size: 20),
                              ),
                              const Text('Vous',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      // ماركر البينيفول (يتحرك)
                      if (_volunteerLocation != null)
                        Marker(
                          point: _volunteerLocation!,
                          width: 56,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8)
                              ],
                              border: Border.all(
                                  color: ZADColors.primary, width: 2.5),
                            ),
                            child: const Icon(Icons.directions_bike_rounded,
                                color: ZADColors.primary, size: 26),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // أزرار الـ toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_volunteerLocation != null) {
                      _mapController.move(_volunteerLocation!, 16);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: ZADColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_bike,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Bénévole',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_donorLocation != null) {
                      _mapController.move(_donorLocation!, 16);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: ZADColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on,
                            color: ZADColors.primary, size: 18),
                        SizedBox(width: 8),
                        Text('Ma position',
                            style: TextStyle(
                                color: ZADColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // معلومات الموقع
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZADColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: ZADColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📍 Position de ${_volunteerName.isEmpty ? "Bénévole" : _volunteerName.split(" ").first}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: ZADColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _volunteerLocation == null
                            ? 'Position non disponible'
                            : 'À $distToYou de votre adresse',
                        style: const TextStyle(
                            color: ZADColors.textLight, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _volunteerLocation == null
                            ? 'En attente...'
                            : '⏱️ Temps estimé: $timeToYou',
                        style: const TextStyle(
                            color: ZADColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── تفاصيل الدون (مع إضافة الوصف) ──
  Widget _buildDonationDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Détails de la collecte',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: ZADColors.textDark)),
          const SizedBox(height: 12),
          _buildInfoRow(
              Icons.restaurant_outlined, 'Produit', _donTitle),
          _buildInfoRow(Icons.inventory_2_outlined, 'Quantité',
              _donQuantity.isNotEmpty ? _donQuantity : '—'),
          _buildInfoRow(Icons.description_outlined, 'Description', _donDescription), // ✅ إضافة صف الوصف
          _buildInfoRow(Icons.location_on_outlined, 'Adresse',
              _donAddress.isNotEmpty ? _donAddress : '—'),
          _buildInfoRow(Icons.access_time, 'Heure estimée',
              _volunteerLocation == null
                  ? 'En attente...'
                  : 'Arrive dans ${_calcTime(_volunteerLocation, _donorLocation)}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZADColors.primary, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: ZADColors.textMedium, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ZADColors.textDark,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── أزرار الاتصال ──
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ZADButton(
            label: 'Contacter',
            icon: Icons.phone,
            onTap: () => _showCallDialog(
                context,
                _volunteerName.isEmpty ? 'Bénévole' : _volunteerName,
                _volunteerPhone.isEmpty ? '—' : _volunteerPhone),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ZADButton(
            label: 'Message',
            icon: Icons.chat_bubble_outline,
            onTap: () {
              if (_volunteerId.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    contactName: _volunteerName.isEmpty
                        ? 'Bénévole'
                        : _volunteerName,
                    contactInitials: _volunteerInitials,
                    contactBgColor: ZADColors.primaryLight,
                    contactPhone: _volunteerPhone,
                    contactId: _volunteerId,
                  ),
                ),
              );
            },
            outlined: true,
          ),
        ),
      ],
    );
  }

  // ✅ زر الإبلاغ عن مشكلة (باللون الأحمر)
  Widget _buildSignalerProblemeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ZADButton(
        label: 'Signaler un problème',
        icon: Icons.warning_amber_rounded,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignalerProblemeScreen()),
          );
        },
        color: ZADColors.danger, // اللون الأحمر الجميل
      ),
    );
  }

  void _showCallDialog(
      BuildContext context, String name, String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Contacter $name',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: ZADColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 48, color: ZADColors.primary),
            const SizedBox(height: 12),
            Text(phone,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Appeler ce numéro ?',
                style: TextStyle(color: ZADColors.textMedium)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: ZADColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Appeler',
                style: TextStyle(color: ZADColors.primary)),
          ),
        ],
      ),
    );
  }
}