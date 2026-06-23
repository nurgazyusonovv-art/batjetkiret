import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../notifications/notifications_service.dart';
import 'notification_navigator.dart';

/// Called by Firebase when a background/terminated message arrives.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // Background messages are automatically shown by Firebase on Android.
}

int? _chatIdFromMessage(RemoteMessage message) {
  final raw = message.data['chat_id'];
  if (raw == null) return null;
  return int.tryParse(raw.toString());
}

int? _orderIdFromMessage(RemoteMessage message) {
  final raw = message.data['order_id'];
  if (raw == null) return null;
  return int.tryParse(raw.toString());
}

String _titleFromMessage(RemoteMessage message) {
  return message.notification?.title ?? message.data['title'] ?? '';
}

String _bodyFromMessage(RemoteMessage message) {
  return message.notification?.body ?? message.data['body'] ?? '';
}

class FcmService {
  static const _tokenKey = 'fcm_device_token';
  static bool _initialized = false;

  static Future<void> initialize(String authToken) async {
    if (kIsWeb) return;
    if (_initialized) {
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

    // App was TERMINATED and user tapped notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      final orderId = _orderIdFromMessage(initial);
      final chatId = _chatIdFromMessage(initial);
      if (orderId != null) {
        NotificationNavigator.openOrderByIdWithRetry(orderId);
      } else if (chatId != null) {
        NotificationNavigator.openChatByIdWithRetry(chatId);
      }
    }

    // App was in BACKGROUND and user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final orderId = _orderIdFromMessage(message);
      final chatId = _chatIdFromMessage(message);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (orderId != null) {
          NotificationNavigator.openOrderById(orderId);
        } else if (chatId != null) {
          NotificationNavigator.openChatById(chatId);
        }
      });
    });

    // App in FOREGROUND — show in-app banner + play sound
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = _titleFromMessage(message);
      final body = _bodyFromMessage(message);
      if (title.isEmpty && body.isEmpty) return;

      final chatId = _chatIdFromMessage(message);
      final orderId = _orderIdFromMessage(message);
      final type = message.data['type'] ?? 'info';

      // Show system notification with sound (handles chat payload for tap nav)
      NotificationsService.showNotification(
        message.hashCode,
        title,
        body,
        chatId: chatId,
        orderId: orderId,
        channelId: _channelForType(type),
      );

      // In-app overlay banner (without duplicate sound — sound comes from showNotification above)
      NotificationsService.addNotification({
        'title': title,
        'body': body,
        'type': type,
        'order_id': orderId,
      }, withSound: false);
    });

    // Get and sync FCM token
    await _syncTokenToBackend(authToken);

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(authToken, newToken);
    });
  }

  static String _channelForType(String type) {
    switch (type) {
      case 'topup_approved':
      case 'topup_rejected':
        return 'topup_status';
      case 'order_status':
        return 'order_status';
      default:
        return 'batken_messages';
    }
  }

  static Future<void> _syncTokenToBackend(String authToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;

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
