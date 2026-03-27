import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../notifications/notifications_service.dart';

/// Called by Firebase when a background/terminated message arrives.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // Background messages are automatically shown by Firebase on Android.
  // No additional handling needed unless custom logic is required.
}

class FcmService {
  static const _tokenKey = 'fcm_device_token';
  static bool _initialized = false;

  static Future<void> initialize(String authToken) async {
    if (_initialized) {
      // Already initialized — just make sure token is sent to backend
      await _syncTokenToBackend(authToken);
      return;
    }
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // Foreground messages — show as heads-up local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      final title = notification.title ?? '';
      final body = notification.body ?? '';

      // Show system heads-up notification with sound
      NotificationsService.showNotification(
        message.hashCode,
        title,
        body,
      );

      // Show in-app overlay banner
      NotificationsService.addNotification({
        'title': title,
        'body': body,
        'type': 'info',
      });
    });

    // Get and sync FCM token
    await _syncTokenToBackend(authToken);

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(authToken, newToken);
    });
  }

  static Future<void> _syncTokenToBackend(String authToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;

      // Only send if token changed
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getString(_tokenKey);
      if (lastSent == token) return;

      await _sendTokenToBackend(authToken, token);
    } catch (_) {}
  }

  static Future<void> _sendTokenToBackend(
      String authToken, String fcmToken) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/me/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': fcmToken}),
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, fcmToken);
      }
    } catch (_) {}
  }
}
