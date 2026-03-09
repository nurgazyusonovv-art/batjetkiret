import 'dart:math';
import 'package:http/http.dart' as http;
import '../config.dart';

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng({required this.latitude, required this.longitude});

  @override
  String toString() => 'LatLng(lat: $latitude, lng: $longitude)';
}

/// Haversine formula для расчета расстояния между двумя точками на земле
class DistanceCalculator {
  static const double _earthRadiusKm = 6371.0; // Radius of Earth in KM

  /// Calculate distance between two coordinates in kilometers
  /// Returns: distance in km
  static double calculateDistance({required LatLng from, required LatLng to}) {
    final dLat = _toRad(to.latitude - from.latitude);
    final dLon = _toRad(to.longitude - from.longitude);

    final a =
        pow(sin(dLat / 2), 2) +
        cos(_toRad(from.latitude)) *
            cos(_toRad(to.latitude)) *
            pow(sin(dLon / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = _earthRadiusKm * c;

    return distance;
  }

  /// Example coordinates for testing
  /// Bishkek center: 42.8746, 74.5698
  /// Osh: 42.4872, 72.7981
  /// Distance ~600km
  static double getExampleDistance() {
    return calculateDistance(
      from: LatLng(latitude: 42.8746, longitude: 74.5698),
      to: LatLng(latitude: 42.4872, longitude: 72.7981),
    );
  }

  static double _toRad(double value) => value * pi / 180;
}

/// Mock geocoder для MVP (real geocoding будет добавлено позже)
class MockGeocoder {
  static const Map<String, LatLng> _mockAddresses = {
    'бишкек правобережный': LatLng(latitude: 42.8746, longitude: 74.5698),
    'бишкек центр': LatLng(latitude: 42.8700, longitude: 74.6000),
    'чуй авеню': LatLng(latitude: 42.8750, longitude: 74.5750),
    'панфилова': LatLng(latitude: 42.8700, longitude: 74.6100),
    'ош': LatLng(latitude: 42.4872, longitude: 72.7981),
    'нарын': LatLng(latitude: 41.4289, longitude: 76.1665),
    'жалал абад': LatLng(latitude: 41.9328, longitude: 74.4968),
  };

  /// Mock geocoding - находит координаты по названию адреса
  /// Для production'а нужно использовать Yandex Geocoding API
  static Future<LatLng?> getCoordinates(String address) async {
    final normalized = address.toLowerCase().trim();
    for (final entry in _mockAddresses.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Reverse geocoding - находит адрес по координатам
  /// Для production'а нужно использовать Yandex Reverse API
  static Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // Mock implementation
    return 'lat: $latitude, lng: $longitude';
  }
}

/// Real Geocoder with Yandex Maps Geocoding API
/// Requires YANDEX_API_KEY for production deployment
class RealGeocoder {
  static const String _yandexGeocodingUrl =
      'https://geocode-maps.yandex.ru/1.x/';

  static const int _timeoutSeconds = 10;

  /// Forward geocoding - get coordinates from address using Yandex API
  /// Falls back to MockGeocoder if Yandex API fails or key not set
  static Future<LatLng?> getCoordinates(String address) async {
    final apiKey = AppConfig.yandexApiKey;

    // If no API key, fall back to mock
    if (apiKey.isEmpty) {
      return MockGeocoder.getCoordinates(address);
    }

    try {
      final params = {
        'apikey': apiKey,
        'geocode': address,
        'format': 'json',
        'results': '1',
        'll': '74.6, 42.8', // Kyrgyzstan center for bias
      };

      final uri = Uri.parse(
        _yandexGeocodingUrl,
      ).replace(queryParameters: params);

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return _parseCoordinatesFromJson(response.body);
      }
    } catch (e) {
      // Log or handle error, fall back to mock
      // TODO: Replace with proper logging (print removed for production)
    }

    // Fallback to mock geocoder
    return MockGeocoder.getCoordinates(address);
  }

  /// Reverse geocoding - get address from coordinates using Yandex API
  /// Falls back to mock address format if Yandex API fails or key not set
  static Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final apiKey = AppConfig.yandexApiKey;

    // If no API key, return mock address
    if (apiKey.isEmpty) {
      return _getMockAddressFromCoordinates(latitude, longitude);
    }

    try {
      final params = {
        'apikey': apiKey,
        'geocode': '$longitude,$latitude',
        'format': 'json',
        'results': '1',
      };

      final uri = Uri.parse(
        _yandexGeocodingUrl,
      ).replace(queryParameters: params);

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final address = _parseAddressFromJson(response.body);
        if (address != null) return address;
      }
    } catch (e) {
      // Log or handle error
      // TODO: Replace with proper logging
    }

    // Fallback to mock address
    return _getMockAddressFromCoordinates(latitude, longitude);
  }

  /// Get mock address from coordinates based on proximity to known cities
  static String _getMockAddressFromCoordinates(double latitude, double longitude) {
    // Check proximity to known cities
    const cities = {
      'Бишкек': LatLng(latitude: 42.8746, longitude: 74.5698),
      'Ош': LatLng(latitude: 42.4872, longitude: 72.7981),
      'Нарын': LatLng(latitude: 41.4289, longitude: 76.1665),
      'Жалал-Абад': LatLng(latitude: 41.9328, longitude: 74.4968),
    };

    String closestCity = 'Тандалган жайгашкан жер';
    double minDistance = double.infinity;

    for (final entry in cities.entries) {
      final distance = DistanceCalculator.calculateDistance(
        from: entry.value,
        to: LatLng(latitude: latitude, longitude: longitude),
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestCity = entry.key;
      }
    }

    // If within 50km of a city, return city name with coordinates
    if (minDistance < 50) {
      return '$closestCity ш., ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }

    // Otherwise return generic with coordinates
    return 'Кыргызстан, ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  /// Parse Yandex Geocoding API JSON response
  /// Expected format from Yandex API:
  /// {
  ///   "response": {
  ///     "GeoObjectCollection": {
  ///       "featureMember": [
  ///         {
  ///           "GeoObject": {
  ///             "Point": {
  ///               "pos": "74.5698 42.8746"
  ///             }
  ///           }
  ///         }
  ///       ]
  ///     }
  ///   }
  /// }
  static LatLng? _parseCoordinatesFromJson(String json) {
    try {
      // Simple parsing without external JSON package
      if (!json.contains('GeoObjectCollection') ||
          !json.contains('featureMember')) {
        return null;
      }

      // Find Point coordinates
      final pointIndex = json.indexOf('"pos"');
      if (pointIndex == -1) return null;

      // Extract coordinates string between quotes
      final startQuote = json.indexOf('"', pointIndex);
      final endQuote = json.indexOf('"', startQuote + 1);

      if (startQuote == -1 || endQuote == -1) return null;

      final posString = json.substring(startQuote + 1, endQuote);
      final coords = posString.split(' ');

      if (coords.length != 2) return null;

      final lng = double.tryParse(coords[0]);
      final lat = double.tryParse(coords[1]);

      if (lng == null || lat == null) return null;

      return LatLng(latitude: lat, longitude: lng);
    } catch (e) {
      // TODO: Replace with proper logging
      return null;
    }
  }

  /// Parse address from Yandex Geocoding API response
  static String? _parseAddressFromJson(String json) {
    try {
      // Find metaDataProperty address
      final addressIndex = json.indexOf('"address"');
      if (addressIndex == -1) return null;

      // Find formatted_address within address object
      final formattedIndex = json.indexOf('"formatted"', addressIndex);
      if (formattedIndex == -1) return null;

      // Extract address string
      final startQuote = json.indexOf('"', formattedIndex);
      final endQuote = json.indexOf('"', startQuote + 1);

      if (startQuote == -1 || endQuote == -1) return null;

      return json.substring(startQuote + 1, endQuote);
    } catch (e) {
      // TODO: Replace with proper logging
      return null;
    }
  }
}

/// Yandex Router API для расчета расстояния по дорогам
/// Requires YANDEX_API_KEY for production deployment
class YandexRouter {
  static const String _yandexRouterUrl =
      'https://router.api.cloud.yandex.net/v2/route';
  
  static const int _timeoutSeconds = 15;

  /// Calculate driving distance between two points using Yandex Router API
  /// Returns distance in kilometers (null if API call fails)
  /// Falls back to straight-line distance if API key not set or request fails
  static Future<double?> calculateDrivingDistance({
    required LatLng from,
    required LatLng to,
  }) async {
    final apiKey = AppConfig.yandexApiKey;

    // If no API key, fall back to straight line distance
    if (apiKey.isEmpty) {
      print('⚠️ Yandex API key not set, using straight-line distance');
      return DistanceCalculator.calculateDistance(from: from, to: to);
    }

    try {
      // Yandex expects coordinates in "longitude,latitude" format
      final startPoint = '${from.longitude},${from.latitude}';
      final endPoint = '${to.longitude},${to.latitude}';

      final params = {
        'apikey': apiKey,
        'start': startPoint,
        'end': endPoint,
        'type': 'driving', // Автомобильный маршрут
      };

      final uri = Uri.parse(_yandexRouterUrl).replace(queryParameters: params);

      print('🚗 Requesting driving route from Yandex Router API...');
      print('  From: $startPoint');
      print('  To: $endPoint');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final distanceKm = _parseDistanceFromJson(response.body);
        if (distanceKm != null) {
          print('  ✅ Driving distance: ${distanceKm.toStringAsFixed(2)} km');
          return distanceKm;
        }
      } else {
        print('  ❌ Yandex Router API error: ${response.statusCode}');
        print('  Response: ${response.body}');
      }
    } catch (e) {
      print('  ❌ Yandex Router API exception: $e');
    }

    // Fallback to straight-line distance
    print('  ⚠️ Falling back to straight-line distance');
    return DistanceCalculator.calculateDistance(from: from, to: to);
  }

  /// Parse distance from Yandex Router API JSON response
  /// Expected format:
  /// {
  ///   "route": {
  ///     "distance": {
  ///       "value": 12345,  // meters
  ///       "text": "12.3 км"
  ///     }
  ///   }
  /// }
  static double? _parseDistanceFromJson(String json) {
    try {
      // Find distance value in meters
      final distanceIndex = json.indexOf('"distance"');
      if (distanceIndex == -1) return null;

      // Look for "value" field after "distance"
      final valueIndex = json.indexOf('"value"', distanceIndex);
      if (valueIndex == -1) return null;

      // Find the number after "value":
      final colonIndex = json.indexOf(':', valueIndex);
      if (colonIndex == -1) return null;

      // Extract number (could be followed by comma or closing brace)
      var endIndex = json.indexOf(',', colonIndex);
      if (endIndex == -1) {
        endIndex = json.indexOf('}', colonIndex);
      }
      if (endIndex == -1) return null;

      final valueStr = json.substring(colonIndex + 1, endIndex).trim();
      final meters = double.tryParse(valueStr);

      if (meters == null) return null;

      // Convert meters to kilometers
      return meters / 1000.0;
    } catch (e) {
      print('  ❌ Error parsing distance from JSON: $e');
      return null;
    }
  }
}
