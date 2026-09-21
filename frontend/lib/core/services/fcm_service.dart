import 'dart:convert';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../notifications/notifications_service.dart';
import 'notification_navigator.dart';

/// Called by Firebase when a background/terminated message arrives.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
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

/// Campaign pushes carry the advertised shop so tapping opens it.
int? _enterpriseIdFromMessage(RemoteMessage message) {
  final raw = message.data['enterprise_id'];
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
  static final StreamController<int?> _newOrderController =
      StreamController<int?>.broadcast();

  static Stream<int?> get onNewOrder => _newOrderController.stream;

  static Future<void> initialize(String authToken) async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) return;
    if (_initialized) {
      await _syncTokenToBackend(authToken);
      return;
    }
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied by user');
      return;
    }
    await messaging.setForegroundNotificationPresentationOptions(
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
      final enterpriseId = _enterpriseIdFromMessage(initial);
      if (enterpriseId != null) {
        NotificationNavigator.openEnterpriseByIdWithRetry(
          enterpriseId,
          initial.data['enterprise_category'] as String?,
        );
      } else if (orderId != null) {
        NotificationNavigator.openOrderByIdWithRetry(orderId);
      } else if (chatId != null) {
        NotificationNavigator.openChatByIdWithRetry(chatId);
      }
    }

    // App was in BACKGROUND and user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final orderId = _orderIdFromMessage(message);
      final chatId = _chatIdFromMessage(message);
      final enterpriseId = _enterpriseIdFromMessage(message);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (enterpriseId != null) {
          NotificationNavigator.openEnterpriseById(
            enterpriseId,
            message.data['enterprise_category'] as String?,
          );
        } else if (orderId != null) {
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
      final channelId = message.data['channel_id'] ?? _channelForType(type);

      if (type.toString().toLowerCase() == 'new_order') {
        _newOrderController.add(orderId);
      }

      final imageUrl = (message.data['image_url'] as String?)?.trim();

      // Show system notification with sound (handles chat payload for tap nav)
      NotificationsService.showNotification(
        message.hashCode,
        title,
        body,
        chatId: chatId,
        orderId: orderId,
        channelId: channelId,
        imageUrl: (imageUrl?.isEmpty ?? true) ? null : imageUrl,
      );

      // In-app overlay banner (without duplicate sound — sound comes from showNotification above)
      NotificationsService.addNotification({
        'title': title,
        'body': body,
        'type': type,
        'order_id': orderId,
        'image_url': imageUrl,
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
    switch (type.toLowerCase()) {
      case 'topup_approved':
      case 'topup_rejected':
      case 'topup':
        return NotificationsService.topupStatusChannelId;
      case 'order_status':
      case 'delivery_status':
        return NotificationsService.orderStatusChannelId;
      case 'support':
      case 'support_chat':
      case 'support_message':
        return NotificationsService.supportChatChannelId;
      case 'new_order':
      case 'cancel_request':
      case 'cancel_requests':
        return NotificationsService.urgentOrdersChannelId;
      default:
        return NotificationsService.messagesChannelId;
    }
  }

  static Future<void> _syncTokenToBackend(String authToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsReady = await _waitForApnsToken(messaging);
        if (!apnsReady) {
          debugPrint('FCM token sync deferred: APNs token is not ready');
          return;
        }
      }
      final token = await messaging.getToken();
      if (token == null) return;

      // Always sync on login. One device may sign in with another account while
      // Firebase keeps the same token, so a device-only cache is not sufficient.
      await _sendTokenToBackend(authToken, token);
    } catch (error) {
      debugPrint('FCM token sync failed: $error');
    }
  }

  static Future<bool> _waitForApnsToken(FirebaseMessaging messaging) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  static Future<void> _sendTokenToBackend(
    String authToken,
    String fcmToken,
  ) async {
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
    } catch (error) {
      debugPrint('FCM token backend sync failed: $error');
    }
  }
}
