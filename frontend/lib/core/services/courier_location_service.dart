import 'dart:async';

import 'package:frontend/core/config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Reports an online courier's position so dispatch can offer a ride to the
/// drivers nearest the passenger.
///
/// Only runs while the courier is online: a driver who is off shift should not
/// be broadcasting where they are, and a stale position would pull rides
/// towards someone who cannot take them.
class CourierLocationService {
  CourierLocationService._();

  static Timer? _timer;
  static String? _token;

  /// Often enough that dispatch sees a moving car in roughly the right place,
  /// rarely enough not to drain the battery.
  static const Duration _interval = Duration(minutes: 2);

  static bool get isRunning => _timer != null;

  static void start(String token) {
    if (_timer != null && _token == token) return;
    stop();
    _token = token;
    _report();
    _timer = Timer.periodic(_interval, (_) => _report());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _token = null;
  }

  static Future<void> _report() async {
    final token = _token;
    if (token == null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await http
          .put(
            Uri.parse('${AppConfig.baseUrl}/users/me/location'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body:
                '{"latitude":${position.latitude},"longitude":${position.longitude}}',
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // A missed report just means dispatch uses the previous position.
    }
  }
}
