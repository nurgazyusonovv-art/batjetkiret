import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config.dart';
import 'notification_item.dart';
import 'user_model.dart';

class UserApi {
  Future<User> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = _decode(response.body);
      if (response.statusCode == 200) {
        return User.fromJson(data);
      }

      throw Exception(
        _extractError(data, fallback: 'Failed to fetch user data'),
      );
    } on SocketException {
      throw Exception(AppConfig.networkErrorMessage);
    } on http.ClientException {
      throw Exception(AppConfig.networkErrorMessage);
    } on FormatException {
      throw Exception('Сервер жообу туура эмес форматта келди');
    }
  }

  Future<void> becomeCourier(String token) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/courier/activate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response.body);
    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      _extractError(data, fallback: 'Failed to activate courier mode'),
    );
  }

  Future<void> removeCourier(String token) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/courier/deactivate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = _decode(response.body);
    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      _extractError(data, fallback: 'Failed to deactivate courier mode'),
    );
  }

  Future<User> updateProfile(
    String token, {
    String? name,
    String? phone,
    String? address,
    bool? isOnline,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    if (isOnline != null) body['is_online'] = isOnline;

    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final data = _decode(response.body);
    if (response.statusCode == 200) {
      return User.fromJson(data);
    }

    throw Exception(_extractError(data, fallback: 'Failed to update profile'));
  }

  Future<Map<String, dynamic>> getCourierRating(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/ratings/courier/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = _decode(response.body);
      if (response.statusCode == 200) {
        return data;
      }

      throw Exception(
        _extractError(data, fallback: 'Рейтингти алуу ишке ашпады'),
      );
    } on SocketException {
      throw Exception(AppConfig.networkErrorMessage);
    } on http.ClientException {
      throw Exception(AppConfig.networkErrorMessage);
    } on FormatException {
      throw Exception('Сервер жообу туура эмес форматта келди');
    }
  }

  Future<Map<String, dynamic>> getUserRating(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/ratings/user/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = _decode(response.body);
      if (response.statusCode == 200) {
        return data;
      }

      throw Exception(
        _extractError(data, fallback: 'Рейтингти алуу ишке ашпады'),
      );
    } on SocketException {
      throw Exception(AppConfig.networkErrorMessage);
    } on http.ClientException {
      throw Exception(AppConfig.networkErrorMessage);
    } on FormatException {
      throw Exception('Сервер жообу туура эмес форматта келди');
    }
  }

  Future<int> getUnreadNotificationsCount(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = _decode(response.body);
      if (response.statusCode == 200) {
        return (data['unread'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } on SocketException {
      return 0;
    } on http.ClientException {
      return 0;
    } on FormatException {
      return 0;
    }
  }

  Future<List<NotificationItem>> getNotifications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is List) {
          return raw
              .whereType<Map<String, dynamic>>()
              .map(NotificationItem.fromJson)
              .toList();
        }
        return [];
      }

      final data = _decode(response.body);
      throw Exception(
        _extractError(data, fallback: 'Билдирмелерди жүктөөдө ката кетти'),
      );
    } on SocketException {
      throw Exception(AppConfig.networkErrorMessage);
    } on http.ClientException {
      throw Exception(AppConfig.networkErrorMessage);
    } on FormatException {
      throw Exception('Сервер жообу туура эмес форматта келди');
    }
  }

  Future<void> markAllNotificationsRead(String token) async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/notifications/mark-all-read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (_) {}
  }

  Future<void> deleteNotification(String token, int notificationId) async {
    try {
      await http.delete(
        Uri.parse('${AppConfig.baseUrl}/notifications/$notificationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (_) {}
  }

  Future<void> markNotificationRead(String token, int notificationId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/notifications/$notificationId/read'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) return;

    final data = _decode(response.body);
    throw Exception(
      _extractError(data, fallback: 'Билдирмени белгилөөдө ката кетти'),
    );
  }

  Future<void> updateLocation(String token, double lat, double lon) async {
    try {
      await http.put(
        Uri.parse('${AppConfig.baseUrl}/users/me/location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'latitude': lat, 'longitude': lon}),
      );
    } catch (_) {}
  }

  Future<double> topupBalance(String token, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/wallet/topup?amount=$amount'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = _decode(response.body);
        return (data['balance'] as num?)?.toDouble() ?? 0.0;
      }

      final data = _decode(response.body);
      throw Exception(
        _extractError(data, fallback: 'Балансты толуктоодо ката кетти'),
      );
    } on SocketException {
      throw Exception(AppConfig.networkErrorMessage);
    } on http.ClientException {
      throw Exception(AppConfig.networkErrorMessage);
    } on FormatException {
      throw Exception('Сервер жообу туура эмес форматта келди');
    }
  }

  Future<List<Map<String, dynamic>>> getTransactions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/wallet/transactions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is List) {
          return raw.whereType<Map<String, dynamic>>().toList();
        }
        return [];
      }

      final data = _decode(response.body);
      throw Exception(
        _extractError(data, fallback: 'Транзакцияларды жүктөөдө ката кетти'),
      );
    } on SocketException {
      throw Exception(AppConfig.networkErrorMessage);
    } on http.ClientException {
      throw Exception(AppConfig.networkErrorMessage);
    } on FormatException {
      throw Exception('Сервер жообу туура эмес форматта келди');
    }
  }

  Future<int> startSupportChat(String token) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/support/start'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = _decode(response.body);
    if (response.statusCode == 200) {
      return (data['chat_id'] as num).toInt();
    }
    throw Exception(_extractError(data, fallback: 'Чат ачылбады'));
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    final raw = jsonDecode(body);
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return <String, dynamic>{};
  }

  String _extractError(Map<String, dynamic> data, {required String fallback}) {
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map<String, dynamic>) {
        final message = first['msg'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    }
    return fallback;
  }
}
