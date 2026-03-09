# Yandex Maps Integration Guide

## Current Status (MVP)
- ✅ Distance calculation using Haversine formula
- ✅ Mock geocoding for testing (supports Bishkek, Osh, Naryn, Jalal-Abad addresses)
- ❌ Real map widget (not implemented yet)
- ❌ Yandex API integration (not implemented yet)

## What's Already Done

### 1. Distance Calculator
Located: [lib/core/utils/distance_calculator.dart](../lib/core/utils/distance_calculator.dart)

**Features:**
- `LatLng` class for coordinates
- `DistanceCalculator.calculateDistance()` - Haversine formula (accurate within 0.5%)
- `MockGeocoder` - Mock address-to-coordinates mapping for testing

**How it works:**
```dart
final distance = DistanceCalculator.calculateDistance(
  from: LatLng(latitude: 42.8746, longitude: 74.5698), // Bishkek
  to: LatLng(latitude: 42.4872, longitude: 72.7981),    // Osh
);
// Returns: ~598.5 km
```

### 2. Order Creation Flow
Updated: [lib/features/home/presentation/cubit/order_create_cubit.dart](../lib/features/home/presentation/cubit/order_create_cubit.dart)

**Changes:**
- Removed incorrect distance calculation (based on text length)
- Added `_calculateDistanceAsync()` using MockGeocoder
- Falls back to estimation if address not found

## Next Steps for Production

### Step 1: Add Yandex API Key
1. Go to [yandex.cloud.ru](https://yandex.cloud.ru)
2. Create project for Maps Kit
3. Get **API Key**

### Step 2: Pubspec Dependencies
```yaml
dependencies:
  yandex_mapkit: ^4.2.0
  flutter_map: ^4.0.0  # Alternative: lightweight maps
```

### Step 3: Platform Configuration

#### Android (`android/app/build.gradle`)
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

#### iOS (`ios/Podfile`)
```ruby
platform :ios, '11.0'

target 'Runner' do
  flutter_root = File.expand_path(File.join(packages_dir, 'flutter'))
  load File.join(flutter_root, 'packages', 'flutter_tools', 'gradle', 'flutter.gradle')
  
  pod 'YandexMapsMobile', '4.2.0'
end
```

### Step 4: Create Map Picker Widget

```dart
// lib/features/common/widgets/map_picker.dart
import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

class MapPicker extends StatefulWidget {
  final void Function(LatLng, String) onLocationSelected;
  
  const MapPicker({
    required this.onLocationSelected,
    Key? key,
  }) : super(key: key);

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  late YandexMapController _mapController;
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Адресс тандоо'),
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () {
                // Reverse geocode to get address
                _getAddressAndReturn();
              },
              child: const Text('Бекитүү'),
            ),
        ],
      ),
      body: YandexMap(
        onMapCreated: (controller) => _mapController = controller,
        onMapTap: (point) {
          setState(() => _selectedLocation = point);
          _mapController.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: point),
            ),
          );
        },
      ),
    );
  }

  Future<void> _getAddressAndReturn() async {
    if (_selectedLocation == null) return;
    
    // Call Yandex Geocoding API
    final address = await _reverseGeocode(_selectedLocation!);
    Navigator.pop(context, {
      'location': _selectedLocation,
      'address': address,
    });
  }

  Future<String> _reverseGeocode(LatLng location) async {
    // TODO: Call Yandex API
    return 'Address from coordinates';
  }
}
```

### Step 5: Integrate Real Geocoding

Update [lib/core/utils/distance_calculator.dart](../lib/core/utils/distance_calculator.dart):

```dart
class RealGeocoder {
  static const String _yandexApiKey = 'YOUR_API_KEY_HERE';

  /// Get coordinates from address using Yandex Geocoding API
  static Future<LatLng?> getCoordinates(String address) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://geocode-maps.yandex.ru/1.x/'
          '?apikey=$_yandexApiKey&geocode=$address&format=json',
        ),
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final features = json['response']['GeoObjectCollection']['featureMember'];
      
      if (features.isEmpty) return null;

      final coords = features[0]['GeoObject']['Point']['pos'].toString().split(' ');
      return LatLng(
        latitude: double.parse(coords[1]),
        longitude: double.parse(coords[0]),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get address from coordinates using Yandex Reverse Geocoding
  static Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://geocode-maps.yandex.ru/1.x/'
          '?apikey=$_yandexApiKey&geocode=$longitude,$latitude&format=json&results=1',
        ),
      );

      if (response.statusCode != 200) return '';

      final json = jsonDecode(response.body);
      final features = json['response']['GeoObjectCollection']['featureMember'];
      
      if (features.isEmpty) return '';

      return features[0]['GeoObject']['metaDataProperty']
          ['GeocoderMetaData']['text'];
    } catch (e) {
      return '';
    }
  }
}
```

### Step 6: Update Order Creation Form

In [lib/features/home/presentation/home_page.dart](../lib/features/home/presentation/home_page.dart):

```dart
// Add to MapPicker widget integration
GestureDetector(
  onTap: () async {
    final result = await Navigator.push<Map>(
      context,
      MaterialPageRoute(builder: (_) => const MapPicker()),
    );
    
    if (result != null) {
      setState(() {
        _fromAddressController.text = result['address'] as String;
      });
    }
  },
  child: const Row(
    children: [
      Icon(Icons.location_on),
      SizedBox(width: 8),
      Text('Картадан сунуштоо'),
    ],
  ),
)
```

## Testing Addresses (Mock Data)

Works with MVP distance calculator without real Yandex API:

| Address | Coordinates | Usage |
|---------|------------|-------|
| Bishkek Pravoberechny | 42.8746, 74.5698 | Main depot |
| Bishkek Center | 42.8700, 74.6000 | City center deliveries |
| Chui Avenue | 42.8750, 74.5750 | Testing |
| Osh | 42.4872, 72.7981 | Inter-city (~600km) |
| Naryn | 41.4289, 76.1665 | Mountain region |
| Jalal-Abad | 41.9328, 74.4968 | South region |

## Deployment Checklist

- [ ] Add Yandex API key to environment/config
- [ ] Update `distance_calculator.dart` with real geocoding
- [ ] Replace `MapPicker` with real Yandex widget implementation
- [ ] Test with Android and iOS
- [ ] Add location permissions to AndroidManifest.xml and Info.plist
- [ ] Test with various addresses in Kyrgyzstan
- [ ] Set up rate limiting for Yandex API calls

## Cost Estimation

**Yandex Maps API:**
- Free tier: 100,000 map initializations/day
- Geocoding: Pay-per-use (~$0.001 per request)
- Estimated monthly cost for 10k orders: $100-300

## Alternatives if Yandex Integration Issues

1. **Google Maps + Geocoding** - More stable, wider coverage (higher cost)
2. **OpenStreetMap + Leaflet** - Free, open-source (less precise in KG)
3. **Offline map data** - OpenAndroMaps tiles (no API key needed)

Choose based on budget, precision requirements, and user experience expectations.
