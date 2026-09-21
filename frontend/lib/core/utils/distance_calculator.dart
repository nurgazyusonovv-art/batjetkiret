import 'dart:convert';
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
    'баткен': LatLng(latitude: 40.060518, longitude: 70.819638),
    'баткен шаары': LatLng(latitude: 40.060518, longitude: 70.819638),
    'кызыл кыя': LatLng(latitude: 40.2567, longitude: 72.1272),
    'кадамжай': LatLng(latitude: 39.8455, longitude: 69.5285),
    'сулюкта': LatLng(latitude: 39.9353, longitude: 69.5680),
    'исфана': LatLng(latitude: 40.1358, longitude: 71.7325),
    'ош': LatLng(latitude: 40.5283, longitude: 72.7985),
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
    // 2GIS knows Batken's house numbers; Yandex and OSM are fallbacks.
    final viaTwoGis = await _TwoGisGeocoder.coordinates(address);
    if (viaTwoGis != null) return viaTwoGis;

    final apiKey = AppConfig.yandexApiKey;

    try {
      if (apiKey.isEmpty) throw Exception('no yandex key');
      final params = {
        'apikey': apiKey,
        'geocode': address,
        'format': 'json',
        'results': '1',
        'll': '70.819638, 40.060518', // Batken city center for bias
      };

      final uri = Uri.parse(
        _yandexGeocodingUrl,
      ).replace(queryParameters: params);

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final coords = _parseCoordinatesFromJson(response.body);
        if (coords != null) return coords;
      }
    } catch (e) {
      // Log or handle error, fall back to OSM then mock
      // TODO: Replace with proper logging (print removed for production)
    }

    // Yandex unavailable (no key / invalid key / network) → free OSM geocoder.
    final osm = await _OsmGeocoder.search(address, limit: 1);
    if (osm.isNotEmpty) return osm.first.location;

    // Fallback to mock geocoder
    return MockGeocoder.getCoordinates(address);
  }

  /// Reverse geocoding - get address from coordinates using Yandex API
  /// Falls back to mock address format if Yandex API fails or key not set
  static Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final viaTwoGis = await _TwoGisGeocoder.reverse(
      latitude: latitude,
      longitude: longitude,
    );
    if (viaTwoGis != null && viaTwoGis.isNotEmpty) return viaTwoGis;

    final apiKey = AppConfig.yandexApiKey;

    try {
      if (apiKey.isEmpty) throw Exception('no yandex key');
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

    // Yandex unavailable → free OSM geocoder, so the user still sees a street
    // name instead of raw coordinates.
    final osm = await _OsmGeocoder.reverse(
      latitude: latitude,
      longitude: longitude,
    );
    if (osm != null && osm.isNotEmpty) return osm;

    // Last resort: nearest known city + coordinates.
    return _getMockAddressFromCoordinates(latitude, longitude);
  }

  /// Get mock address from coordinates based on proximity to known cities
  static String _getMockAddressFromCoordinates(
    double latitude,
    double longitude,
  ) {
    // Check proximity to known cities
    const cities = {
      'Баткен': LatLng(latitude: 40.060518, longitude: 70.819638),
      'Кызыл-Кыя': LatLng(latitude: 40.2567, longitude: 72.1272),
      'Кадамжай': LatLng(latitude: 39.8455, longitude: 69.5285),
      'Сулюкта': LatLng(latitude: 39.9353, longitude: 69.5680),
      'Исфана': LatLng(latitude: 40.1358, longitude: 71.7325),
      'Ош': LatLng(latitude: 40.5283, longitude: 72.7985),
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
  /// Address search for the "type to find a street" fields.
  ///
  /// Results are biased to the Batken area but not limited to it, so a user in
  /// another city still finds their street.
  static Future<List<AddressSuggestion>> searchAddresses(
    String query, {
    LatLng? near,
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final bias =
        near ?? const LatLng(latitude: 40.060518, longitude: 70.819638);

    final viaTwoGis = await _TwoGisGeocoder.search(
      trimmed,
      near: bias,
      limit: limit,
    );
    if (viaTwoGis.isNotEmpty) return viaTwoGis;

    final apiKey = AppConfig.yandexApiKey;

    try {
      if (apiKey.isEmpty) throw Exception('no yandex key');
      final uri = Uri.parse(_yandexGeocodingUrl).replace(
        queryParameters: {
          'apikey': apiKey,
          'geocode': trimmed,
          'format': 'json',
          'lang': 'ru_RU',
          'results': '$limit',
          'll': '${bias.longitude},${bias.latitude}',
          'spn': '1.5,1.5',
        },
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));
      if (response.statusCode == 200) {
        final suggestions = <AddressSuggestion>[];
        for (final geoObject in _featureMembers(response.body)) {
          final point = _pointOf(geoObject);
          if (point == null) continue;
          final title = (geoObject['name'] as String?)?.trim();
          if (title == null || title.isEmpty) continue;
          suggestions.add(
            AddressSuggestion(
              title: title,
              subtitle: (geoObject['description'] as String?)?.trim() ?? '',
              location: point,
            ),
          );
        }
        if (suggestions.isNotEmpty) return suggestions;
      }
    } catch (_) {
      // fall through to OSM
    }

    return _OsmGeocoder.search(trimmed, near: bias, limit: limit);
  }

  // ── Yandex response helpers ───────────────────────────────────────────────

  /// GeoObjects of a Yandex 1.x geocoder response, in ranking order.
  static List<Map<String, dynamic>> _featureMembers(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return const [];
      final collection =
          decoded['response']?['GeoObjectCollection']?['featureMember'];
      if (collection is! List) return const [];
      return [
        for (final member in collection)
          if (member is Map && member['GeoObject'] is Map)
            Map<String, dynamic>.from(member['GeoObject'] as Map),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Yandex reports "longitude latitude" in Point.pos.
  static LatLng? _pointOf(Map<String, dynamic> geoObject) {
    final pos = geoObject['Point']?['pos'];
    if (pos is! String) return null;
    final parts = pos.split(' ');
    if (parts.length != 2) return null;
    final lon = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lon == null || lat == null) return null;
    return LatLng(latitude: lat, longitude: lon);
  }

  static LatLng? _parseCoordinatesFromJson(String json) {
    final members = _featureMembers(json);
    if (members.isEmpty) return null;
    return _pointOf(members.first);
  }

  /// Human-readable street + house number, e.g. "улица Ленина, 5, Баткен".
  ///
  /// [GeoObject.name] already carries the street and house; the first part of
  /// [description] adds the town, which couriers need.
  static String? _parseAddressFromJson(String json) {
    final members = _featureMembers(json);
    if (members.isEmpty) return null;
    final geoObject = members.first;

    final name = (geoObject['name'] as String?)?.trim() ?? '';
    final description = (geoObject['description'] as String?)?.trim() ?? '';

    if (name.isEmpty) {
      // No street-level match — fall back to the full formatted text.
      final text = geoObject['metaDataProperty']?['GeocoderMetaData']?['text'];
      final formatted = text is String ? text.trim() : '';
      return formatted.isEmpty ? null : formatted;
    }

    final locality = description.split(',').first.trim();
    if (locality.isEmpty || name.contains(locality)) return name;
    return '$name, $locality';
  }
}

/// One address hit from [RealGeocoder.searchAddresses].
class AddressSuggestion {
  /// Street and house number, e.g. "улица Ленина, 5".
  final String title;

  /// Town / region line, e.g. "Баткен, Кыргызстан".
  final String subtitle;

  final LatLng location;

  const AddressSuggestion({
    required this.title,
    required this.subtitle,
    required this.location,
  });

  /// What goes into the address field once the user picks this hit.
  String get fullAddress {
    if (subtitle.isEmpty) return title;
    final locality = subtitle.split(',').first.trim();
    if (locality.isEmpty || title.contains(locality)) return title;
    return '$title, $locality';
  }
}

/// Yandex Router API для расчета расстояния по дорогам
/// Requires YANDEX_API_KEY for production deployment
/// Driving distance between two points.
///
/// Falls through three sources, best first:
///   1. OpenRouteService — real road distance, needs a free ORS_API_KEY.
///   2. OSRM — real road distance, no key (point OSRM_BASE_URL at your own
///      server; the public demo is a stop-gap and not for production load).
///   3. Straight line × [_roadFactor] — never the bare straight line, which
///      undercharges by roughly half in Batken's street grid.
class RouteDistance {
  static const int _timeoutSeconds = 15;

  /// Measured on Batken routes: road distance ≈ 1.6× the straight line.
  static const double _roadFactor = 1.6;

  static Future<double?> calculateDrivingDistance({
    required LatLng from,
    required LatLng to,
  }) async {
    final viaOrs = await _openRouteService(from, to);
    if (viaOrs != null) return viaOrs;

    final viaOsrm = await _osrm(from, to);
    if (viaOsrm != null) return viaOsrm;

    final straight = DistanceCalculator.calculateDistance(from: from, to: to);
    return straight * _roadFactor;
  }

  static Future<double?> _openRouteService(LatLng from, LatLng to) async {
    final apiKey = AppConfig.orsApiKey;
    if (apiKey.isEmpty) return null;
    try {
      final uri =
          Uri.parse(
            'https://api.openrouteservice.org/v2/directions/driving-car',
          ).replace(
            queryParameters: {
              'api_key': apiKey,
              'start': '${from.longitude},${from.latitude}',
              'end': '${to.longitude},${to.latitude}',
            },
          );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final features = decoded['features'];
      if (features is! List || features.isEmpty) return null;
      final meters = features.first['properties']?['summary']?['distance'];
      if (meters is! num || meters <= 0) return null;
      return meters / 1000.0;
    } catch (_) {
      return null;
    }
  }

  static Future<double?> _osrm(LatLng from, LatLng to) async {
    final base = AppConfig.osrmBaseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final uri = Uri.parse(
        '$base/route/v1/driving/$coords',
      ).replace(queryParameters: {'overview': 'false'});
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['code'] != 'Ok') return null;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final meters = routes.first['distance'];
      if (meters is! num || meters <= 0) return null;
      return meters / 1000.0;
    } catch (_) {
      return null;
    }
  }
}

/// Free OpenStreetMap (Nominatim) geocoder, used only when Yandex is not
/// available — no API key, so the app still shows street names instead of raw
/// coordinates while a valid Yandex Geocoder key is missing.
///
/// Nominatim's usage policy allows at most one request per second and requires
/// an identifying User-Agent; both are enforced here.
class _OsmGeocoder {
  static const String _base = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'BatkenExpress/1.0 (batken.express.app)';
  static const Duration _minInterval = Duration(milliseconds: 1100);
  static const int _timeoutSeconds = 8;

  static DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> _throttle() async {
    final since = DateTime.now().difference(_lastCall);
    if (since < _minInterval) {
      await Future.delayed(_minInterval - since);
    }
    _lastCall = DateTime.now();
  }

  static Future<http.Response?> _get(Uri uri) async {
    try {
      await _throttle();
      final response = await http
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: _timeoutSeconds));
      return response.statusCode == 200 ? response : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> reverse({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
        'zoom': '18',
        'accept-language': 'ru',
      },
    );
    final response = await _get(uri);
    if (response == null) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return _format(
        decoded['address'],
        decoded['display_name'] as String?,
      ).fullAddressOrNull;
    } catch (_) {
      return null;
    }
  }

  static Future<List<AddressSuggestion>> search(
    String query, {
    LatLng? near,
    int limit = 6,
  }) async {
    final bias =
        near ?? const LatLng(latitude: 40.060518, longitude: 70.819638);
    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'format': 'jsonv2',
        'q': query,
        'addressdetails': '1',
        'accept-language': 'ru',
        'countrycodes': 'kg',
        'limit': '$limit',
        // Prefer hits around the user, without excluding the rest of the country.
        'viewbox':
            '${bias.longitude - 0.6},${bias.latitude + 0.6},'
            '${bias.longitude + 0.6},${bias.latitude - 0.6}',
      },
    );
    final response = await _get(uri);
    if (response == null) return const [];
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      final results = <AddressSuggestion>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null) continue;
        final parts = _format(item['address'], item['display_name'] as String?);
        if (parts.title.isEmpty) continue;
        results.add(
          AddressSuggestion(
            title: parts.title,
            subtitle: parts.locality,
            location: LatLng(latitude: lat, longitude: lon),
          ),
        );
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  /// Turn Nominatim's address object into "street, house" + locality.
  static _OsmAddress _format(dynamic address, String? displayName) {
    final map = address is Map ? address : const {};
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    final road = pick(['road', 'pedestrian', 'residential', 'neighbourhood']);
    final house = pick(['house_number']);
    final locality = pick(['city', 'town', 'village', 'suburb', 'county']);

    var title = road.isEmpty
        ? (displayName ?? '').split(',').first.trim()
        : (house.isEmpty ? road : '$road, $house');
    if (title.isEmpty) title = locality;

    return _OsmAddress(title: title, locality: locality);
  }
}

class _OsmAddress {
  final String title;
  final String locality;

  const _OsmAddress({required this.title, required this.locality});

  String? get fullAddressOrNull {
    if (title.isEmpty) return null;
    if (locality.isEmpty || title.contains(locality)) return title;
    return '$title, $locality';
  }
}

/// 2GIS Geocoder — the primary address source.
///
/// Measured over 15 points across Batken: 2GIS returned a house number for 13
/// of them, OpenStreetMap for 2. Yandex would be second best but its Geocoder
/// API rejects the project's key, so the order is 2GIS → Yandex → OSM.
class _TwoGisGeocoder {
  static const String _geocodeUrl =
      'https://catalog.api.2gis.com/3.0/items/geocode';
  static const String _searchUrl = 'https://catalog.api.2gis.com/3.0/items';
  static const int _timeoutSeconds = 8;

  /// Keeps hits around Batken; without it a half-typed street matches
  /// businesses in Bishkek.
  static const String _searchRadiusMeters = '30000';

  static Future<Map<String, dynamic>?> _request(
    String url,
    Map<String, String> params,
  ) async {
    final apiKey = AppConfig.twoGisApiKey;
    if (apiKey.isEmpty) return null;
    try {
      final uri = Uri.parse(
        url,
      ).replace(queryParameters: {...params, 'key': apiKey});
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _items(Map<String, dynamic>? payload) {
    final result = payload?['result'];
    if (result is! Map) return const [];
    final items = result['items'];
    return items is List ? items : const [];
  }

  /// "улица Исхака Раззакова, 12" — street and house number when 2GIS has one.
  static String? _addressOf(dynamic item) {
    if (item is! Map) return null;
    final name = (item['address_name'] ?? item['full_name'])?.toString().trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  static LatLng? _pointOf(dynamic item) {
    if (item is! Map) return null;
    final point = item['point'];
    if (point is! Map) return null;
    final lat = (point['lat'] as num?)?.toDouble();
    final lon = (point['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return LatLng(latitude: lat, longitude: lon);
  }

  static Future<String?> reverse({
    required double latitude,
    required double longitude,
  }) async {
    // type=building keeps the answer on a house; without it 2GIS replies with
    // the district or the city, which is useless for a courier.
    final payload = await _request(_geocodeUrl, {
      'lat': '$latitude',
      'lon': '$longitude',
      'radius': '300',
      'type': 'building',
      'fields': 'items.point,items.address,items.full_name',
    });
    for (final item in _items(payload)) {
      final address = _addressOf(item);
      if (address != null) return address;
    }
    return null;
  }

  static Future<List<AddressSuggestion>> search(
    String query, {
    LatLng? near,
    int limit = 6,
  }) async {
    final bias =
        near ?? const LatLng(latitude: 40.060518, longitude: 70.819638);
    // The search endpoint (not geocode) answers half-typed streets, which is
    // what the address field needs while the user is still typing.
    final payload = await _request(_searchUrl, {
      'q': query,
      'point': '${bias.longitude},${bias.latitude}',
      'radius': _searchRadiusMeters,
      'type': 'street,building',
      'page_size': '$limit',
      'fields': 'items.point,items.address,items.full_name',
    });

    final results = <AddressSuggestion>[];
    for (final item in _items(payload)) {
      final point = _pointOf(item);
      if (point == null) continue;

      // full_name starts with the locality: "Баткен, улица ..., 12". Streets
      // carry no address_name, so the locality is split off instead of being
      // repeated in both lines of the suggestion.
      final fullName = item is Map
          ? (item['full_name']?.toString().trim() ?? '')
          : '';
      final addressName = item is Map
          ? (item['address_name']?.toString().trim() ?? '')
          : '';

      var title = addressName;
      var locality = '';
      if (fullName.contains(',')) {
        locality = fullName.split(',').first.trim();
        if (title.isEmpty) {
          title = fullName.substring(fullName.indexOf(',') + 1).trim();
        }
      }
      if (title.isEmpty) title = fullName;
      if (title.isEmpty) continue;

      results.add(
        AddressSuggestion(
          title: title,
          subtitle: locality == title ? '' : locality,
          location: point,
        ),
      );
    }
    return results;
  }

  static Future<LatLng?> coordinates(String address) async {
    final found = await search(address, limit: 1);
    return found.isEmpty ? null : found.first.location;
  }
}
