import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static int _idCounter = 0;

  static const _channelId = 'enterprise_orders';
  static const _channelName = 'Заказдар';

  static Future<void> init() async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Create high-importance channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // Request permission on Android 13+ (API 33+)
    await androidPlugin?.requestNotificationsPermission();

    _ready = true;
  }

  static Future<void> show(String title, String body) async {
    if (!_ready) return;
    _idCounter = (_idCounter + 1) % 10000;
    await _plugin.show(
      _idCounter,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ticker: 'Жаңы заказ',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
