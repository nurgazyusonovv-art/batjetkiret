import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_navigator.dart';

class NotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static final _notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStream.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // User tapped a local notification — open chat if payload has chat_id
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          final chatId = int.tryParse(payload);
          if (chatId != null && chatId > 0) {
            NotificationNavigator.openChatById(chatId);
          }
        }
      },
    );

    // Create Android notification channel with sound + vibration
    const channel = AndroidNotificationChannel(
      'batken_messages',
      'Билдирүүлөр',
      description: 'Жаңы билдирүүлөр жана чат хабарлары',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request iOS permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Show a system notification with sound. [chatId] is passed as payload
  /// so tapping the notification opens the correct chat.
  static Future<void> showNotification(
    int id,
    String title,
    String body, {
    int? chatId,
  }) async {
    if (!_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'batken_messages',
      'Билдирүүлөр',
      channelDescription: 'Жаңы билдирүүлөр жана чат хабарлары',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true);
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: chatId != null ? '$chatId' : null,
    );
  }

  /// Add notification to in-app overlay stream
  static void addNotification(Map<String, dynamic> notification) {
    _notificationStream.add(notification);
  }

  static void notifyNewOrder(String orderId, String status) {
    addNotification({
      'type': 'new_order',
      'order_id': orderId,
      'status': status,
      'title': 'Жаңы заказ',
      'body': 'Жаңы доставка заказы бар',
      'timestamp': DateTime.now(),
    });
  }

  static void notifyOrderStatusChanged(String orderId, String newStatus) {
    addNotification({
      'type': 'order_status_changed',
      'order_id': orderId,
      'status': newStatus,
      'title': 'Заказ статусу өзгөрдү',
      'body': 'Заказ #$orderId $newStatus статусуна өттү',
      'timestamp': DateTime.now(),
    });
  }

  static void notifyRating(String courierName, double rating) {
    addNotification({
      'type': 'rating_received',
      'courier_name': courierName,
      'rating': rating,
      'title': 'Сиз рейтинг алдыңыз!',
      'body': '$courierName сизди $rating жылдыз менен баалаган',
      'timestamp': DateTime.now(),
    });
  }

  static void notifyTopupApproved(double amount) {
    addNotification({
      'type': 'topup_approved',
      'amount': amount,
      'title': 'Баланс толуктолду',
      'body': '$amount сом кошулду',
      'timestamp': DateTime.now(),
    });
  }

  static void notifyError(String title, String message) {
    addNotification({
      'type': 'error',
      'title': title,
      'body': message,
      'timestamp': DateTime.now(),
    });
  }

  static void dispose() {
    _notificationStream.close();
  }
}
