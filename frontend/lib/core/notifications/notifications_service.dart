import 'dart:async';

/// Простой сервис уведомлений на базе WebSocket
/// Уведомления поступают через существующую WebSocket систему
class NotificationsService {
  static final _notificationStream =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Инициализация сервиса уведомлений
  static Future<void> initialize() async {}

  /// Stream уведомлений для слушания в UI
  static Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStream.stream;

  /// Добавить уведомление в поток (вызывается из других сервисов)
  static void addNotification(Map<String, dynamic> notification) {
    _notificationStream.add(notification);
  }

  /// Добавить уведомление о новом заказе
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

  /// Добавить уведомление об изменении статуса заказа
  static void notifyOrderStatusChanged(String orderId, String newStatus) {
    addNotification({
      'type': 'order_status_changed',
      'order_id': orderId,
      'status': newStatus,
      'title': 'Заказ статусы өзгөрдү',
      'body': 'Заказ #$orderId $newStatus статусуна өтүүдү',
      'timestamp': DateTime.now(),
    });
  }

  /// Добавить уведомление о рейтинге
  static void notifyRating(String courierName, double rating) {
    addNotification({
      'type': 'rating_received',
      'courier_name': courierName,
      'rating': rating,
      'title': 'Сиз рейтинг алдыңыз!',
      'body': '$courierName сизди $rating жылдыз бер баалаган',
      'timestamp': DateTime.now(),
    });
  }

  /// Добавить уведомление о пополнении баланса
  static void notifyTopupApproved(double amount) {
    addNotification({
      'type': 'topup_approved',
      'amount': amount,
      'title': 'Баланс толуктолду',
      'body': '$amount SOM кошулду',
      'timestamp': DateTime.now(),
    });
  }

  /// Добавить уведомление об ошибке
  static void notifyError(String title, String message) {
    addNotification({
      'type': 'error',
      'title': title,
      'body': message,
      'timestamp': DateTime.now(),
    });
  }

  /// Очистка ресурсов (при logout)
  static void dispose() {
    _notificationStream.close();
  }
}
