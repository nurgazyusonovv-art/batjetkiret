import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../services/notification_navigator.dart';

class NotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static final _notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStream.stream;

  static const messagesChannelId = 'batken_messages_v3';
  static const orderStatusChannelId = 'order_status_v3';
  static const topupStatusChannelId = 'topup_status_v3';
  static const supportChatChannelId = 'support_chat_v3';
  static const urgentOrdersChannelId = 'urgent_orders_v3';

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

    // Custom notification sounds live under android/app/src/main/res/raw.
    // Channel ids are suffixed _v3 because Android caches a channel's sound at
    // creation time and ignores later changes — a new id forces the new sound.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final spec in _channelSpecs) {
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          spec.id,
          spec.name,
          description: spec.description,
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(spec.sound),
          enableVibration: true,
          enableLights: true,
        ),
      );
    }
    await androidPlugin?.requestNotificationsPermission();

    // Request iOS permissions
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Show a system notification with sound. Payload supports `order:<id>` or a plain chat id.
  static Future<void> showNotification(
    int id,
    String title,
    String body, {
    int? chatId,
    int? orderId,
    String channelId = messagesChannelId,
    String? imageUrl,
  }) async {
    if (!_initialized) return;

    final resolvedChannelId = _normalizeChannelId(channelId);
    final spec = _specForChannel(resolvedChannelId);
    String? payload;
    if (orderId != null) {
      payload = 'order:$orderId';
    } else if (chatId != null) {
      payload = '$chatId';
    }

    // Campaign pictures are shown as an expandable big picture. The bitmap
    // travels to the system over a binder transaction with a ~1MB budget, so a
    // heavy image is dropped rather than risking a failed notification.
    final picture = await _downloadPicture(imageUrl);

    final androidDetails = AndroidNotificationDetails(
      resolvedChannelId,
      spec.name,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(spec.sound),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
      styleInformation: picture == null
          ? null
          : BigPictureStyleInformation(
              ByteArrayAndroidBitmap(picture),
              largeIcon: ByteArrayAndroidBitmap(picture),
              contentTitle: title,
              summaryText: body,
              hideExpandedLargeIcon: true,
            ),
    );
    final iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
      sound: '${spec.sound}.wav',
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details, payload: payload);
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
      final imageUrl = (notification['image_url'] as String?)?.trim();

      showNotification(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        orderId: orderId,
        channelId: channelId,
        imageUrl: (imageUrl?.isEmpty ?? true) ? null : imageUrl,
      );
    }
  }

  static String _channelForType(String type) {
    switch (type.toLowerCase()) {
      case 'topup_approved':
      case 'topup_rejected':
      case 'topup':
        return topupStatusChannelId;
      case 'order_status':
      case 'delivery_status':
        return orderStatusChannelId;
      case 'support':
      case 'support_chat':
      case 'support_message':
        return supportChatChannelId;
      case 'new_order':
      case 'cancel_request':
      case 'cancel_requests':
        return urgentOrdersChannelId;
      default:
        return messagesChannelId;
    }
  }

  static String _normalizeChannelId(String channelId) {
    switch (channelId) {
      case 'batken_messages':
      case 'batken_messages_v2':
        return messagesChannelId;
      case 'order_status':
      case 'order_status_v2':
        return orderStatusChannelId;
      case 'topup_requests':
      case 'topup_status':
      case 'topup_status_v2':
        return topupStatusChannelId;
      case 'support_chat':
      case 'support_chat_v2':
        return supportChatChannelId;
      case 'urgent_orders':
      case 'urgent_orders_v2':
        return urgentOrdersChannelId;
      default:
        return channelId;
    }
  }

  static _NotificationChannelSpec _specForChannel(String channelId) {
    return _channelSpecs.firstWhere(
      (spec) => spec.id == channelId,
      orElse: () => _channelSpecs.first,
    );
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

class _NotificationChannelSpec {
  const _NotificationChannelSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.sound,
  });

  final String id;
  final String name;
  final String description;
  final String sound;
}

const _channelSpecs = [
  _NotificationChannelSpec(
    id: NotificationsService.messagesChannelId,
    name: 'Билдирүүлөр',
    description: 'Жаңы билдирүүлөр жана чат хабарлары',
    sound: 'message_tone',
  ),
  _NotificationChannelSpec(
    id: NotificationsService.orderStatusChannelId,
    name: 'Заказ статусу',
    description: 'Заказыңыздын статусу өзгөргөндө',
    sound: 'order_tone',
  ),
  _NotificationChannelSpec(
    id: NotificationsService.topupStatusChannelId,
    name: 'Баланс жана төлөм',
    description: 'Топап жана төлөм статусу',
    sound: 'topup_tone',
  ),
  _NotificationChannelSpec(
    id: NotificationsService.supportChatChannelId,
    name: 'Колдоо кызматы',
    description: 'Колдоо кызматынан билдирүүлөр',
    sound: 'support_tone',
  ),
  _NotificationChannelSpec(
    id: NotificationsService.urgentOrdersChannelId,
    name: 'Шашылыш заказдар',
    description: 'Жаңы заказ жана маанилүү эскертмелер',
    sound: 'urgent_tone',
  ),
];

/// Fetches a campaign picture for a notification, or null when there is none,
/// the download fails, or the image is too heavy to hand to the system.
Future<Uint8List?> _downloadPicture(String? url) async {
  if (url == null || url.isEmpty) return null;
  const maxBytes = 800 * 1024;
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final bytes = response.bodyBytes;
    return bytes.length > maxBytes ? null : bytes;
  } catch (_) {
    return null;
  }
}
