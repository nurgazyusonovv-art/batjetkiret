import 'dart:async';
import 'dart:typed_data';
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
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;

        // payload format: "chat:<id>" or "order:<id>"
        if (payload.startsWith('order:')) {
          final orderId = int.tryParse(payload.substring(6));
          if (orderId != null) NotificationNavigator.openOrderById(orderId);
        } else {
          final chatId = int.tryParse(payload);
          if (chatId != null && chatId > 0) {
            NotificationNavigator.openChatById(chatId);
          }
        }
      },
    );

    // Custom notification sound (android/app/src/main/res/raw/notification_tone.mp3).
    // Channel ids are suffixed _v2 because Android caches a channel's sound at
    // creation time and ignores later changes — a new id forces the new sound.
    const sound = RawResourceAndroidNotificationSound('notification_tone');

    const messagesChannel = AndroidNotificationChannel(
      'batken_messages_v2',
      'Билдирүүлөр',
      description: 'Жаңы билдирүүлөр жана чат хабарлары',
      importance: Importance.max,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );
    const topupChannel = AndroidNotificationChannel(
      'topup_status_v2',
      'Топап статусу',
      description: 'Топап тастыкталды же четке кагылды',
      importance: Importance.max,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );
    const orderChannel = AndroidNotificationChannel(
      'order_status_v2',
      'Заказ статусу',
      description: 'Заказыңыздын статусу өзгөрдү',
      importance: Importance.max,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );
    const supportChannel = AndroidNotificationChannel(
      'support_chat_v2',
      'Колдоо кызматы',
      description: 'Колдоо кызматынан жооп',
      importance: Importance.max,
      playSound: true,
      sound: sound,
      enableVibration: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(messagesChannel);
    await androidPlugin?.createNotificationChannel(topupChannel);
    await androidPlugin?.createNotificationChannel(orderChannel);
    await androidPlugin?.createNotificationChannel(supportChannel);

    // Request iOS permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Show a system notification with sound. Payload supports "order:<id>" or plain chat id.
  static Future<void> showNotification(
    int id,
    String title,
    String body, {
    int? chatId,
    int? orderId,
    String channelId = 'batken_messages_v2',
  }) async {
    if (!_initialized) return;

    String? payload;
    if (orderId != null) {
      payload = 'order:$orderId';
    } else if (chatId != null) {
      payload = '$chatId';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName(channelId),
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification_tone'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  static String _channelName(String channelId) {
    switch (channelId) {
      case 'topup_status_v2':
        return 'Топап статусу';
      case 'order_status_v2':
        return 'Заказ статусу';
      case 'support_chat_v2':
        return 'Колдоо кызматы';
      default:
        return 'Билдирүүлөр';
    }
  }

  /// Add notification to in-app overlay stream.
  /// [withSound] = true shows a system notification so device sound + vibration fires.
  static void addNotification(
    Map<String, dynamic> notification, {
    bool withSound = true,
  }) {
    _notificationStream.add(notification);

    if (withSound && _initialized) {
      final title = notification['title'] as String? ?? '';
      final body = notification['body'] as String? ?? '';
      final orderId = notification['order_id'] is int
          ? notification['order_id'] as int
          : int.tryParse('${notification['order_id'] ?? ''}');
      final type = notification['type'] as String? ?? 'info';
      final channelId = _channelForType(type);

      showNotification(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        orderId: orderId,
        channelId: channelId,
      );
    }
  }

  static String _channelForType(String type) {
    switch (type) {
      case 'topup_approved':
      case 'topup_rejected':
        return 'topup_status_v2';
      case 'order_status':
        return 'order_status_v2';
      case 'SUPPORT':
        return 'support_chat_v2';
      default:
        return 'batken_messages_v2';
    }
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
      'type': 'order_status',
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
    }, withSound: false);
  }

  static void dispose() {
    _notificationStream.close();
  }
}
