import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.title = 'Choisir la position',
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _green = Color(0xFF2E7D32);
  static const _blue  = Color(0xFF1565C0);

  final MapController         _mapController    = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _selectedLocation = const LatLng(34.8828, -1.3167);
  bool   _isLoading        = true;
  bool   _locationPicked   = false;
  String _placeName        = ''; // ✅ اسم المكان من Nominatim أو من tap

  // ── Search state ─────────────────────────────────────────
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _isLoading        = false;
      _locationPicked   = true;
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.deniedForever &&
          perm != LocationPermission.denied) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _selectedLocation = LatLng(pos.latitude, pos.longitude);
            _isLoading        = false;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _mapController.move(_selectedLocation, 15.0);
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Nominatim Search (مجاني 100%) ────────────────────────
  Future<void> _searchPlace(String query) async {
    if (query.trim().length < 3) {
      setState(() { _searchResults = []; _showResults = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=5'
        '&accept-language=fr,ar',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'ZAD-App/1.0 (contact@zad.dz)',
      });
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((item) => {
            'name':      item['display_name'] as String,
            'shortName': _shortName(item['display_name'] as String),
            'lat':       double.parse(item['lat'] as String),
            'lng':       double.parse(item['lon'] as String),
          }).toList();
          _showResults = _searchResults.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('❌ Nominatim error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  String _shortName(String fullName) {
    final parts = fullName.split(',');
    return parts.take(2).join(',').trim();
  }

  // ✅ اختيار نتيجة من القائمة
  void _selectSearchResult(Map<String, dynamic> result) {
    final loc = LatLng(result['lat'] as double, result['lng'] as double);
    setState(() {
      _selectedLocation             = loc;
      _locationPicked               = true;
      _placeName                    = result['shortName'] as String;
      _showResults                  = false;
      _searchController.text        = _placeName;
    });
    _mapController.move(loc, 15.0);
    FocusScope.of(context).unfocus();
  }

  // ✅ عند الضغط على الخريطة يدوياً — نعمل Reverse Geocoding
  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _locationPicked   = true;
      _showResults      = false;
      _placeName        = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
    });
    FocusScope.of(context).unfocus();

    // Reverse Geocoding باش نجيبوا الاسم من الإحداثيات
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${point.latitude}&lon=${point.longitude}'
        '&format=json'
        '&accept-language=fr,ar',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'ZAD-App/1.0 (contact@zad.dz)',
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final name = data['display_name'] as String? ?? '';
        if (name.isNotEmpty && mounted) {
          setState(() {
            _placeName             = _shortName(name);
            _searchController.text = _placeName;
          });
        }
      }
    } catch (_) {}
  }

  // ✅ ترجع Map بدل LatLng فقط — باش نعطيوا الاسم معاه
  void _confirm() {
    Navigator.pop(context, {
      'lat':  _selectedLocation.latitude,
      'lng':  _selectedLocation.longitude,
      'name': _placeName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [

                // ── الخريطة ────────────────────────────────
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation,
                    initialZoom:   15.0,
                    onTap: (_, point) => _onMapTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.zad',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point:  _selectedLocation,
                          width:  50,
                          height: 60,
                          child: Column(
                            children: [
                              Container(
                                width:  46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color:  _locationPicked ? _green : _blue,
                                  shape:  BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_locationPicked ? _green : _blue)
                                          .withOpacity(0.4),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on,
                                    color: Colors.white, size: 24),
                              ),
                              Container(
                                width: 2,
                                height: 10,
                                color: _locationPicked ? _green : _blue,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ── Search Bar + نتائج ──────────────────────
                Positioned(
                  top:   12,
                  left:  16,
                  right: 16,
                  child: Column(
                    children: [

                      // حقل البحث
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10)
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged:  _searchPlace,
                          decoration: InputDecoration(
                            hintText: '🔍 Rechercher un lieu...',
                            hintStyle: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                            prefixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _green),
                                    ),
                                  )
                                : const Icon(Icons.search,
                                    color: _green, size: 22),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.grey, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _showResults   = false;
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            filled:          true,
                            fillColor:       Colors.white,
                            contentPadding:  const EdgeInsets.symmetric(
                                vertical: 13, horizontal: 4),
                          ),
                        ),
                      ),

                      // قائمة النتائج
                      if (_showResults && _searchResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10)
                            ],
                          ),
                          child: Column(
                            children: _searchResults.map((result) {
                              return InkWell(
                                onTap: () => _selectSearchResult(result),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          color: _green, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          result['shortName'] as String,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF1B1B1B)),
                                          maxLines:  2,
                                          overflow:  TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // رسالة توجيهية
                      if (!_showResults) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6)
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.touch_app,
                                  color: _green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _locationPicked
                                      ? '✅ Position sélectionnée — appuyez sur Confirmer'
                                      : '👆 Recherchez ou appuyez sur la carte',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1B1B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── زر موقعي الحالي ─────────────────────────
                Positioned(
                  bottom: 100,
                  right:  16,
                  child: GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      width:  46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:  Colors.white,
                        shape:  BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.my_location,
                          color: _blue, size: 22),
                    ),
                  ),
                ),

                // ── زر Confirmer ────────────────────────────
                Positioned(
                  bottom: 20,
                  left:   16,
                  right:  16,
                  child: ElevatedButton.icon(
                    onPressed: _locationPicked ? _confirm : null,
                    icon:  const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Confirmer cette position',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _locationPicked ? _green : Colors.grey,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}