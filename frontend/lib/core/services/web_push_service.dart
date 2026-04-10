import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../config.dart';

/// Web Push subscription service for Flutter web.
///
/// All browser PushManager logic lives in web/index.html (`batkenSubscribePush`):
/// - Re-uses an existing browser subscription when available.
/// - Requests permission and subscribes to push if not yet subscribed.
/// - Returns the subscription JSON via callback.
///
/// This class fetches the VAPID key, invokes that JS function, and upserts
/// the resulting subscription into the backend (idempotent — safe to call on
/// every login and every cold start).
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
      // Push is non-critical — never crash the app.
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
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['public_key'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Calls `window.batkenSubscribePush(vapidKey, onSuccess, onError)`.
  ///
  /// Uses [dart:js_interop_unsafe]'s [globalContext] to reach the global JS
  /// function and passes Dart closures converted to [JSFunction] via `.toJS`.
  static Future<String?> _callJsSubscribe(String vapidKey) async {
    final completer = Completer<String?>();
    try {
      // Convert Dart closures to JSFunction (dart:js_interop ≥ Dart 3.0).
      final onSuccess =
          ((JSAny? r) => completer.complete(r?.dartify() as String?)).toJS;
      final onError = ((JSAny? _) => completer.complete(null)).toJS;

      // Call window.batkenSubscribePush(vapidKey, onSuccess, onError)
      globalContext.callMethod(
        'batkenSubscribePush'.toJS,
        vapidKey.toJS,
        onSuccess,
        onError,
      );
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
