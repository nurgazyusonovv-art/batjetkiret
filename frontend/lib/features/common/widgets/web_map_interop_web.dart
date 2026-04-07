// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Builds an interactive Leaflet.js map inside an iframe (Flutter Web only).
/// Communication: iframe → Flutter via window.postMessage({type:'mapClick',lat,lon}).
Widget buildWebMapView({
  required double initialLat,
  required double initialLon,
  required void Function(double lat, double lon) onTap,
}) {
  final viewType = 'leaflet-map-${DateTime.now().millisecondsSinceEpoch}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..srcdoc = _leafletHtml(initialLat, initialLon)
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..allow = 'geolocation';

    html.window.onMessage.listen((html.MessageEvent event) {
      try {
        final data = event.data;
        if (data is Map && data['type'] == 'mapClick') {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          onTap(lat, lon);
        }
      } catch (_) {}
    });

    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}

void disposeWebMapListener() {}

String _leafletHtml(double lat, double lon) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    html,body,#map{margin:0;padding:0;width:100%;height:100%;}
    .hint{
      position:absolute;bottom:16px;left:50%;transform:translateX(-50%);
      background:rgba(0,0,0,.65);color:#fff;padding:8px 18px;
      border-radius:20px;font-size:13px;pointer-events:none;z-index:1000;
      font-family:sans-serif;white-space:nowrap;
    }
  </style>
</head>
<body>
<div id="map"></div>
<div class="hint" id="hint">Картага басып жайгашкан жерди тандаңыз</div>
<script>
  const map = L.map('map').setView([$lat,$lon],13);
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{
    maxZoom:19, attribution:'© OpenStreetMap'
  }).addTo(map);

  let marker = L.marker([$lat,$lon]).addTo(map);

  map.on('click', function(e){
    const {lat,lng} = e.latlng;
    marker.setLatLng([lat,lng]);
    document.getElementById('hint').style.display='none';
    window.parent.postMessage({type:'mapClick',lat:lat,lon:lng},'*');
  });
</script>
</body>
</html>
''';
