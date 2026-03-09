// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../../../core/utils/distance_calculator.dart';
import 'map_picker.dart';

/// Compact map preview widget - small embedded map that opens full MapPickerWidget on tap
/// Shows selected location with address and coordinates
class CompactMapPreview extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final Function(LatLng, String) onLocationChanged;
  final String? label;

  const CompactMapPreview({
    super.key,
    this.initialLocation,
    this.initialAddress,
    required this.onLocationChanged,
    this.label = 'Жайгашкан жерин тандаңыз',
  });

  @override
  State<CompactMapPreview> createState() => _CompactMapPreviewState();
}

class _CompactMapPreviewState extends State<CompactMapPreview> {
  late WebViewController _webViewController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? const LatLng(latitude: 40.060518, longitude: 70.819638);
    _selectedAddress = widget.initialAddress ?? 'Тандаңыз';
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterMap',
        onMessageReceived: (JavaScriptMessage message) {
          // We don't handle clicks in preview mode
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            if (_selectedLocation != null) {
              _moveToLocation(_selectedLocation!);
            }
          },
        ),
      )
      ..loadRequest(Uri.dataFromString(_getHtmlContent(), mimeType: 'text/html', encoding: Encoding.getByName('utf-8')));
  }

  void _moveToLocation(LatLng location) {
    try {
      _webViewController.runJavaScript(
        'if (typeof moveToLocation !== "undefined") { moveToLocation(${location.latitude}, ${location.longitude}); }',
      );
      _updateMarker(location);
    } catch (e) {
      // Ignore JavaScript errors during initialization
    }
  }

  void _updateMarker(LatLng location) {
    try {
      _webViewController.runJavaScript(
        'if (typeof updateMarker !== "undefined") { updateMarker(${location.latitude}, ${location.longitude}); }',
      );
    } catch (e) {
      // Ignore JavaScript errors during initialization
    }
  }

  String _getHtmlContent() {
    final lat = _selectedLocation?.latitude ?? 40.060518;
    final lon = _selectedLocation?.longitude ?? 70.819638;
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://api-maps.yandex.ru/2.1/?apikey=&lang=ru_RU" type="text/javascript"></script>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; }
        #map { width: 100%; height: 100%; }
    </style>
</head>
<body>
    <div id="map"></div>
    <script type="text/javascript">
        let myMap;
        let placemark;
        
        ymaps.ready(init);
        
        function init() {
            myMap = new ymaps.Map("map", {
                center: [$lat, $lon],
                zoom: 13,
                controls: []
            });
            
            // Initial marker
            updateMarker($lat, $lon);
        }
        
        function moveToLocation(lat, lon) {
            if (myMap) {
                myMap.setCenter([lat, lon], 13, {
                    duration: 300
                });
            }
        }
        
        function updateMarker(lat, lon) {
            if (myMap) {
                if (placemark) {
                    myMap.geoObjects.remove(placemark);
                }
                placemark = new ymaps.Placemark([lat, lon], {
                    hintContent: 'Жайгашкан жер'
                }, {
                    preset: 'islands#redDotIcon'
                });
                myMap.geoObjects.add(placemark);
            }
        }
    </script>
</body>
</html>
    ''';
  }

  Future<void> _openFullMap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MapPickerWidget(
          initialLocation: _selectedLocation,
          initialAddress: _selectedAddress,
          title: widget.label,
          onLocationSelected: (location, address) {
            // Callback handled in pop
          },
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      final location = result['location'] as LatLng;
      final address = result['address'] as String;

      setState(() {
        _selectedLocation = location;
        _selectedAddress = address;
      });

      _moveToLocation(location);
      widget.onLocationChanged(location, address);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Map preview container
        GestureDetector(
          onTap: _openFullMap,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Map WebView
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: WebViewWidget(controller: _webViewController),
                ),

                // Loading indicator
                if (_isLoading)
                  Container(
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

                // Click to edit overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Өзгөрт',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Address info below map
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Тандалган адрес:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedAddress ?? 'Адрес тандалган жок',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (_selectedLocation != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
