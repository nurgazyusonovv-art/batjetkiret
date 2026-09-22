import 'dart:async';
import 'dart:convert';

import 'package:frontend/core/config.dart';
import 'package:frontend/features/taxi/data/taxi_ride.dart';
import 'package:http/http.dart' as http;

/// API calls the taxi flow needs, and nothing else.
///
/// Kept separate from OrderApi on purpose: the ride screens own their contract
/// with the backend, so changing the delivery flow cannot break a ride.
class TaxiApi {
  TaxiApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  /// Places the ride. Returns the new order id.
  Future<int> createRide({
    required String token,
    required String fromAddress,
    required String toAddress,
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required double distanceKm,
    String? comment,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/'),
          headers: _headers(token),
          body: jsonEncode({
            'category': 'taxi',
            // The backend requires a description; the comment is optional for
            // the passenger, so fall back to something meaningful.
            'description': (comment ?? '').trim().isEmpty
                ? 'Шаар ичинде такси'
                : comment!.trim(),
            'from_address': fromAddress,
            'to_address': toAddress,
            'from_latitude': fromLat,
            'from_longitude': fromLon,
            'to_latitude': toLat,
            'to_longitude': toLon,
            'distance_km': distanceKm,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['id'] as num).toInt();
    }
    throw Exception(_errorFrom(response));
  }

  Future<TaxiRide> fetchRide({
    required String token,
    required int rideId,
  }) async {
    final response = await _client
        .get(
          Uri.parse('${AppConfig.baseUrl}/orders/$rideId'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) throw Exception(_errorFrom(response));
    return TaxiRide.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> cancelRide({required String token, required int rideId}) async {
    final response = await _client
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/$rideId/cancel'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) throw Exception(_errorFrom(response));
  }

  Future<void> rateDriver({
    required String token,
    required int rideId,
    required int rating,
    String? comment,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/ratings/courier/$rideId')
        .replace(
          queryParameters: {
            'rating': '$rating',
            if ((comment ?? '').trim().isNotEmpty) 'comment': comment!.trim(),
          },
        );
    await _client.post(uri, headers: _headers(token)).timeout(_timeout);
  }

  /// The ride the passenger is on right now, if any.
  ///
  /// Used when the app reopens mid-ride so the passenger lands back on the
  /// ride screen instead of an empty home page.
  Future<TaxiRide?> fetchActiveRide(String token) async {
    final response = await _client
        .get(
          Uri.parse('${AppConfig.baseUrl}/orders/my'),
          headers: _headers(token),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    final items = decoded is List
        ? decoded
        : (decoded is Map ? decoded['items'] ?? const [] : const []);
    for (final item in items is List ? items : const []) {
      if (item is! Map<String, dynamic>) continue;
      if ((item['category'] ?? '').toString() != 'taxi') continue;
      final ride = TaxiRide.fromJson(item);
      if (ride.phase == TaxiRidePhase.searching ||
          ride.phase == TaxiRidePhase.driverOnTheWay ||
          ride.phase == TaxiRidePhase.inRide) {
        return ride;
      }
    }
    return null;
  }

  String _errorFrom(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['detail'] != null) return '${data['detail']}';
    } catch (_) {}
    return 'Сервер ката берди (${response.statusCode})';
  }
}
