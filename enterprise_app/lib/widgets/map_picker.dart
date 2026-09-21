import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PickedLocation {
  final double lat;
  final double lon;
  final String? address;
  const PickedLocation({required this.lat, required this.lon, this.address});
}

class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final bool needAddress;

  const MapPickerPage({
    super.key,
    this.initialLat,
    this.initialLon,
    this.needAddress = false,
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late final MapController _mapController;
  late LatLng _center;
  bool _confirming = false;

  // Batken city default
  static const _defaultLat = 40.0631;
  static const _defaultLon = 70.8222;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _center = LatLng(
      widget.initialLat ?? _defaultLat,
      widget.initialLon ?? _defaultLon,
    );
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    String? address;
    if (widget.needAddress) {
      address = await _reverseGeocode(_center.latitude, _center.longitude);
    }
    if (mounted) {
      Navigator.pop(context, PickedLocation(
        lat: _center.latitude,
        lon: _center.longitude,
        address: address,
      ));
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final dio = Dio();
      final resp = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'format': 'json',
          'accept-language': 'ru',
        },
        options: Options(
          headers: {'User-Agent': 'BatJetKiret/1.0'},
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = resp.data as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr != null) {
        final road = addr['road'] ?? addr['neighbourhood'] ?? addr['suburb'] ?? '';
        final house = addr['house_number'] ?? '';
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? '';
        final parts = [
          if ((road as String).isNotEmpty) road,
          if ((house as String).isNotEmpty) house,
          if ((city as String).isNotEmpty) city,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
      final full = data['display_name'] as String?;
      if (full != null && full.length > 80) return full.substring(0, 80);
      return full;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        toolbarHeight: 48,
        title: const Text('Жайгашкан жер тандоо',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: Stack(children: [
        // ── Map ────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 14.5,
            onMapEvent: (event) {
              if (event is MapEventMoveEnd ||
                  event is MapEventScrollWheelZoom ||
                  event is MapEventDoubleTapZoom) {
                if (mounted) {
                  setState(() => _center = _mapController.camera.center);
                }
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kg.batjetkiret.enterprise',
              maxZoom: 19,
            ),
          ],
        ),

        // ── Center pin (tip aligns with map center) ────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: const _Pin(),
              ),
            ),
          ),
        ),

        // ── Zoom controls ─────────────────────────────────────────────────
        Positioned(
          right: 12,
          top: 12,
          child: Column(children: [
            _zoomBtn(Icons.add, () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            }),
            const SizedBox(height: 6),
            _zoomBtn(Icons.remove, () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            }),
          ]),
        ),

        // ── Bottom panel ──────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(children: [
                const Icon(Icons.my_location_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Text(
                  '${_center.latitude.toStringAsFixed(5)},  '
                  '${_center.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ]),
              if (widget.needAddress) ...[
                const SizedBox(height: 4),
                const Row(children: [
                  Icon(Icons.info_outline, size: 13, color: Color(0xFF9CA3AF)),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Тандагандан кийин дарек автоматтык аныкталат',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _confirming ? null : _confirm,
                  icon: _confirming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _confirming ? 'Аныкталууда...' : 'Ушул жерди тандоо',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF374151)),
        ),
      );
}

// ─── Pin widget ───────────────────────────────────────────────────────────────

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(alignment: Alignment.center, children: [
        // shadow circle under pin tip
        Positioned(
          bottom: 0,
          child: Container(
            width: 12,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const Positioned(
          top: 0,
          child: Icon(Icons.location_on, color: Color(0xFFDC2626), size: 48),
        ),
      ]),
    );
  }
}
