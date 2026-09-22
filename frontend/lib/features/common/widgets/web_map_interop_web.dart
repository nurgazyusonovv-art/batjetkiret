// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/config.dart';

/// Builds an interactive 2GIS MapGL map inside an iframe (Flutter Web only).
/// Implemented as a StatefulWidget so the iframe and message listener are
/// created ONCE and survive parent rebuilds (geocoding state changes etc.).
Widget buildWebMapView({
  required double initialLat,
  required double initialLon,
  required void Function(double lat, double lon) onTap,
}) {
  return _WebMapGlMap(
    initialLat: initialLat,
    initialLon: initialLon,
    onTap: onTap,
  );
}

void disposeWebMapListener() {}

// ─────────────────────────────────────────────────────────────────────────────

class _WebMapGlMap extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final void Function(double, double) onTap;

  const _WebMapGlMap({
    required this.initialLat,
    required this.initialLon,
    required this.onTap,
  });

  @override
  State<_WebMapGlMap> createState() => _WebMapGlMapState();
}

class _WebMapGlMapState extends State<_WebMapGlMap> {
  late final String _viewType;
  html.EventListener? _msgListener;

  @override
  void initState() {
    super.initState();
    // Unique view type — registered exactly once for this widget instance.
    _viewType = 'dgis-map-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..srcdoc = _mapGlHtml(widget.initialLat, widget.initialLon, _viewType)
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allow = 'geolocation';
    });

    // Single persistent listener — removed in dispose().
    _msgListener = (html.Event event) {
      if (event is! html.MessageEvent) return;
      try {
        _handleMessage(event.data);
      } catch (_) {}
    };
    html.window.addEventListener('message', _msgListener);
  }

  void _handleMessage(dynamic rawData) {
    Map<String, dynamic> data;

    if (rawData is String) {
      // Preferred: iframe sends JSON.stringify(...)
      data = jsonDecode(rawData) as Map<String, dynamic>;
    } else {
      // Fallback: try direct property access for JS object
      try {
        final type = rawData['type'];
        if (type == 'mapClick') {
          // Only handle if this message is from our own iframe.
          final msgViewType = rawData['viewType'];
          if (msgViewType != null && msgViewType != _viewType) return;
          final lat = (rawData['lat'] as num).toDouble();
          final lon = (rawData['lon'] as num).toDouble();
          widget.onTap(lat, lon);
        }
      } catch (_) {}
      return;
    }

    if (data['type'] == 'mapClick') {
      // Only handle if this message is from our own iframe.
      final msgViewType = data['viewType'];
      if (msgViewType != null && msgViewType != _viewType) return;
      final lat = (data['lat'] as num).toDouble();
      final lon = (data['lon'] as num).toDouble();
      widget.onTap(lat, lon);
    }
  }

  @override
  void dispose() {
    if (_msgListener != null) {
      html.window.removeEventListener('message', _msgListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

// ─────────────────────────────────────────────────────────────────────────────

String _mapGlHtml(double lat, double lon, String viewType) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <script src="https://mapgl.2gis.com/api/js/v1"></script>
  <style>
    html,body { margin:0; padding:0; width:100%; height:100%; }
    #map { position:absolute; inset:0; width:100%; height:100%; }
    .hint {
      position: absolute; bottom: 16px; left: 50%;
      transform: translateX(-50%);
      background: rgba(0,0,0,.65); color: #fff;
      padding: 8px 18px; border-radius: 20px;
      font-size: 13px; pointer-events: none;
      z-index: 1000; font-family: sans-serif; white-space: nowrap;
    }
  </style>
</head>
<body>
<div id="map"></div>
<div class="hint" id="hint">Картага басып жайгашкан жерди тандаңыз</div>
<script>
  var map = new mapgl.Map('map', {
    center: [$lon, $lat],
    zoom: 15,
    key: '${AppConfig.twoGisApiKey}',
    zoomControl: 'bottomRight'
  });

  var marker = new mapgl.Marker(map, { coordinates: [$lon, $lat] });

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

  map.on('click', function(e) {
    var lon = e.lngLat[0];
    var lat = e.lngLat[1];
    marker.setCoordinates([lon, lat]);
    document.getElementById('hint').style.display = 'none';
    // Send as JSON string — reliably parsed by Dart on all Flutter web builds
    window.parent.postMessage(JSON.stringify({ type: 'mapClick', lat: lat, lon: lon, viewType: '$viewType' }), '*');
  });
</script>
</body>
</html>
''';
