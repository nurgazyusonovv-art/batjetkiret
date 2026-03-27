// ignore_for_file: use_build_context_synchronously, deprecated_member_use, use_super_parameters

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import '../../../core/utils/distance_calculator.dart';

/// Interactive Yandex Map widget using WebView
/// User can tap on map to select delivery address
/// Shows selected location with address via reverse geocoding
class MapPickerWidget extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialAddress;
  final Function(LatLng, String) onLocationSelected;
  final String? title;

  const MapPickerWidget({
    Key? key,
    this.initialLocation,
    this.initialAddress,
    required this.onLocationSelected,
    this.title = 'Жайгашкан жерин тандаңыз',
  }) : super(key: key);

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  late WebViewController _webViewController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation =
        widget.initialLocation ?? const LatLng(latitude: 40.060518, longitude: 70.819638);
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
          _handleMapMessage(message.message);
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

  void _handleMapMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['type'] == 'click') {
        final lat = (data['lat'] as num?)?.toDouble();
        final lon = (data['lon'] as num?)?.toDouble();
        if (lat == null || lon == null) return;
        _handleMapTap(LatLng(latitude: lat, longitude: lon));
      }
    } catch (e) {
      debugPrint('Error parsing map message: $e');
    }
  }

  Future<void> _handleMapTap(LatLng location) async {
    if (_isReverseGeocoding) return;

    setState(() => _isReverseGeocoding = true);

    try {
      // Reverse geocode to get address
      final address = await RealGeocoder.getAddressFromCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      setState(() {
        _selectedLocation = location;
        _selectedAddress = address;
        _isReverseGeocoding = false;
      });

      // Update marker on map
      _updateMarker(location);

      // Notify parent widget
      widget.onLocationSelected(location, address);

      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Жайгашкан жер тандалды: $_selectedAddress'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isReverseGeocoding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Каталык: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _selectCity(String cityName, LatLng cityCoords) async {
    setState(() => _isReverseGeocoding = true);

    try {
      _moveToLocation(cityCoords);

      final address = await RealGeocoder.getAddressFromCoordinates(
        latitude: cityCoords.latitude,
        longitude: cityCoords.longitude,
      );

      setState(() {
        _selectedLocation = cityCoords;
        _selectedAddress = address;
        _isReverseGeocoding = false;
      });

      widget.onLocationSelected(cityCoords, address);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$cityName тандалды')),
        );
      }
    } catch (e) {
      setState(() => _isReverseGeocoding = false);
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
                zoom: 12,
                controls: ['zoomControl', 'geolocationControl']
            });
            
            // Add click handler
            myMap.events.add('click', function (e) {
                const coords = e.get('coords');
                FlutterMap.postMessage(JSON.stringify({
                    type: 'click',
                    lat: coords[0],
                    lon: coords[1]
                }));
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
                    hintContent: 'Тандалган жайгашкан жер'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Жайгашкан жерин тандаңыз'),
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          // Yandex Map WebView
          WebViewWidget(controller: _webViewController),

          // Loading indicator
          if (_isLoading || _isReverseGeocoding)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Quick city selection (bottom)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _cityButton(
                    'Баткен',
                    const LatLng(latitude: 40.060518, longitude: 70.819638),
                  ),
                  const SizedBox(width: 8),
                  _cityButton(
                    'Ош',
                    const LatLng(latitude: 40.5283, longitude: 72.7985),
                  ),
                  const SizedBox(width: 8),
                  _cityButton(
                    'Кадамжай',
                    const LatLng(latitude: 40.1358, longitude: 71.7325),
                  ),
                  const SizedBox(width: 8),
                  _cityButton(
                    'Сулюкта',
                    const LatLng(latitude: 39.9353, longitude: 69.5680),
                  ),
                  const SizedBox(width: 8),
                  _cityButton(
                    'Исфана',
                    const LatLng(latitude: 39.8455, longitude: 69.5285),
                  ),
                ],
              ),
            ),
          ),

          // Selected address display (top)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Тандалган жайгашкан жер:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedAddress ?? 'Жайгашкан жер тандалган жок',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Confirm button (middle-bottom)
          if (_selectedLocation != null && !_isLoading)
            Positioned(
              bottom: 140,
              left: 16,
              right: 16,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // Return selected location to parent widget
                  Navigator.of(context).pop({
                    'location': _selectedLocation,
                    'address': _selectedAddress,
                  });
                },
                child: const Text(
                  'Бул адресстерди танда',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Quick city selection button
  Widget _cityButton(String cityName, LatLng cityCoords) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedAddress?.contains(cityName) == true
            ? Colors.blue
            : Colors.white,
        side: const BorderSide(color: Colors.blue, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: () => _selectCity(cityName, cityCoords),
      child: Text(
        cityName,
        style: TextStyle(
          color: _selectedAddress?.contains(cityName) == true
              ? Colors.white
              : Colors.blue,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Dialog helper to show MapPicker
class MapPickerDialog {
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    LatLng? initialLocation,
    String? initialAddress,
    String? title,
  }) {
    return Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => MapPickerWidget(
          initialLocation: initialLocation,
          initialAddress: initialAddress,
          title: title,
          onLocationSelected: (location, address) {
            // Callback handled in pop
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

