// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../config.dart';

/// Web Push subscription for Flutter web.
/// All browser PushManager logic lives in index.html (batkenSubscribePush).
/// This class fetches the VAPID key, calls that JS function, then saves the
/// resulting subscription object to the backend.
class WebPushService {
  static bool _subscribed = false;

  static Future<void> subscribeIfNeeded(String authToken) async {
    if (!kIsWeb) return;
    if (_subscribed) return;

    try {
      final vapidKey = await _fetchVapidKey(authToken);
      if (vapidKey == null) return;

      final subJson = await _callJsSubscribe(vapidKey);
      if (subJson == null) return;

      final sub = jsonDecode(subJson) as Map<String, dynamic>;
      await _sendToBackend(authToken, sub);
      _subscribed = true;
    } catch (_) {}
  }

  static Future<String?> _fetchVapidKey(String authToken) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/vapid-key'),
        headers: {'Authorization': 'Bearer $authToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['public_key'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Calls window.batkenSubscribePush(vapidKey) → Promise<string|null>
  /// That function is defined in web/index.html.
  static Future<String?> _callJsSubscribe(String vapidKey) async {
    final completer = Completer<String?>();
    try {
      js.context.callMethod('batkenSubscribePush', [
        vapidKey,
        js.allowInterop((dynamic result) {
          completer.complete(result as String?);
        }),
        js.allowInterop((dynamic _err) {
          completer.complete(null);
        }),
      ]);
    } catch (_) {
      return null;
    }
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () => null);
  }

  static Future<void> _sendToBackend(
      String authToken, Map<String, dynamic> sub) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/me/push-subscribe'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'subscription': sub}),
      );
    } catch (_) {}
  }
}
