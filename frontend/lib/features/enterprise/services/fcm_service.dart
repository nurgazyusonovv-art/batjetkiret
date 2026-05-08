import 'package:firebase_messaging/firebase_messaging.dart';
import '../widgets/notification_service.dart';
import 'api_service.dart';

// Top-level handler for background/terminated FCM messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final title = message.notification?.title ?? message.data['title'] ?? '🛎 Жаңы заказ';
  final body = message.notification?.body ?? message.data['body'] ?? '';
  await NotificationService.show(title, body);
}

class FcmService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ??
          message.data['title'] ??
          '🛎 Жаңы заказ';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      NotificationService.show(title, body);
    });

    // Save token to backend
    await _sendTokenToServer(messaging);

    // Re-send when token refreshes
    messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _sendTokenToServer(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (_) {}
  }

  static Future<void> _saveToken(String token) async {
    try {
      await ApiService.saveFcmToken(token);
    } catch (_) {}
  }
}
