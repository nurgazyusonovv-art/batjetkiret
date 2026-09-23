import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../common/widgets/map_key_missing.dart';

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
  late final WebViewController _controller;
  late double _centerLat;
  late double _centerLon;
  bool _confirming = false;
  bool _mapLoading = true;

  // Batken city default
  static const _defaultLat = 40.0631;
  static const _defaultLon = 70.8222;

  @override
  void initState() {
    super.initState();
    _centerLat = widget.initialLat ?? _defaultLat;
    _centerLon = widget.initialLon ?? _defaultLon;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'MapCenter',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final lat = (data['lat'] as num).toDouble();
            final lon = (data['lon'] as num).toDouble();
            if (mounted) {
              setState(() {
                _centerLat = lat;
                _centerLon = lon;
              });
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _mapLoading = false);
          },
        ),
      )
      ..loadHtmlString(_mapHtml(), baseUrl: 'https://2gis.com');
  }

  String _mapHtml() {
    final key = AppConfig.twoGisApiKey;
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <script src="https://mapgl.2gis.com/api/js/v1"></script>
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; }
    #map { position: absolute; inset: 0; width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var map = new mapgl.Map('map', {
      center: [$_centerLon, $_centerLat],
      zoom: 16,
      key: '$key'
    });

    function report() {
      var c = map.getCenter();
      MapCenter.postMessage(JSON.stringify({ lat: c[1], lon: c[0] }));
    }

    map.on('moveend', report);
    map.on('zoomend', report);

    // MapGL measures the container when it is built; inside a WebView/iframe
    // that can still be 0x0, which leaves a blank canvas. Re-measure once the
    // real size lands.
    function fixSize() { try { map.invalidateSize(); } catch (e) {} }
    window.addEventListener('resize', fixSize);
    if (window.ResizeObserver) {
      new ResizeObserver(fixSize).observe(document.getElementById('map'));
    }
    setTimeout(fixSize, 100);
    setTimeout(fixSize, 600);
    setTimeout(fixSize, 1500);

    function zoomBy(delta) {
      map.setZoom(map.getZoom() + delta);
    }
  </script>
</body>
</html>
    ''';
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    String? address;
    if (widget.needAddress) {
      address = await _reverseGeocode(_centerLat, _centerLon);
    }
    if (mounted) {
      Navigator.pop(context, PickedLocation(
        lat: _centerLat,
        lon: _centerLon,
        address: address,
      ));
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    // Same 2GIS-first geocoder the rest of the app uses, so the address the
    // enterprise picks matches what customers see.
    try {
      final address = await RealGeocoder.getAddressFromCoordinates(
        latitude: lat,
        longitude: lon,
      );
      return address.isEmpty ? null : address;
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
        if (AppConfig.twoGisApiKey.isEmpty)
          const Positioned.fill(child: MapKeyMissingView())
        else
          WebViewWidget(controller: _controller),
        if (_mapLoading && AppConfig.twoGisApiKey.isNotEmpty)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
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
              _controller.runJavaScript('if(window.zoomBy) zoomBy(1);');
            }),
            const SizedBox(height: 6),
            _zoomBtn(Icons.remove, () {
              _controller.runJavaScript('if(window.zoomBy) zoomBy(-1);');
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
                  '${_centerLat.toStringAsFixed(5)},  '
                  '${_centerLon.toStringAsFixed(5)}',
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
