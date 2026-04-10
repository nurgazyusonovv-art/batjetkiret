// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../config.dart';

/// Web Push subscription for Flutter web.
///
/// Browser PushManager logic lives in web/index.html (`batkenSubscribePush`):
/// - Checks for an existing browser subscription first (no extra permission prompt).
/// - Requests permission and subscribes if needed.
/// - Returns the subscription JSON via callback.
///
/// This class fetches the VAPID key, invokes that JS function, and upserts
/// the resulting subscription into the backend (idempotent — safe to call on
/// every login and on every app start).
class WebPushService {
  WebPushService._();

  static Future<void> subscribeIfNeeded(String authToken) async {
    if (!kIsWeb) return;

    try {
      final vapidKey = await _fetchVapidKey(authToken);
      if (vapidKey == null) return;

      final subJson = await _callJsSubscribe(vapidKey);
      if (subJson == null) return;

      final sub = jsonDecode(subJson) as Map<String, dynamic>;
      await _sendToBackend(authToken, sub);
    } catch (_) {
      // Push is non-critical — never crash the app
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Future<String?> _fetchVapidKey(String authToken) async {
    try {
      final res = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/users/vapid-key'),
            headers: {'Authorization': 'Bearer $authToken'},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['public_key'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Calls `window.batkenSubscribePush(vapidKey, onSuccess, onError)`.
  /// The JS function resolves with the subscription JSON string or calls onError.
  static Future<String?> _callJsSubscribe(String vapidKey) async {
    final completer = Completer<String?>();
    try {
      js.context.callMethod('batkenSubscribePush', [
        vapidKey,
        js.allowInterop((dynamic result) => completer.complete(result as String?)),
        js.allowInterop((dynamic _err) => completer.complete(null)),
      ]);
    } catch (_) {
      return null;
    }
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => null,
    );
  }

  static Future<void> _sendToBackend(
    String authToken,
    Map<String, dynamic> sub,
  ) async {
    try {
      await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/users/me/push-subscribe'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'subscription': sub}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
