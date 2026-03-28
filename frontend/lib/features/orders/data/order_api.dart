import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../../core/config.dart';
import 'chat_message_model.dart';
import 'chat_context_model.dart';
import 'order_model.dart';
import 'order_status_audit_entry.dart';

class OrderApi {
  String _mapServerDetail(String detail) {
    // Backend already returns Kyrgyz error messages — pass them through as-is.
    return detail;
  }

  String _getNetworkErrorMessage(dynamic e) {
    if (e is SocketException || e is http.ClientException) {
      return '${AppConfig.networkErrorMessage}${AppConfig.baseUrl}\nОшибка: $e';
    }
    return e.toString();
  }

  Future<bool> isCourier(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic>) {
          return jsonData['is_courier'] == true;
        }
        throw Exception('Сервер жообу туура эмес форматта келди');
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Колдонуучунун ролун текшерүүдө ката кетти',
      );
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        throw Exception(_getNetworkErrorMessage(e));
      }
      rethrow;
    }
  }

  Future<void> createOrder({
    required String token,
    required String category,
    required String description,
    required String fromAddress,
    required String toAddress,
    double? fromLatitude,
    double? fromLongitude,
    double? toLatitude,
    double? toLongitude,
    double distanceKm = 1.0,
    int? enterpriseId,
    int? intercityCityId,
    double? itemsTotal,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category,
        'description': description,
        'from_address': fromAddress,
        'to_address': toAddress,
        'from_latitude': fromLatitude,
        'from_longitude': fromLongitude,
        'to_latitude': toLatitude,
        'to_longitude': toLongitude,
        'distance_km': distanceKm,
      };
      if (enterpriseId != null) body['enterprise_id'] = enterpriseId;
      if (intercityCityId != null) body['intercity_city_id'] = intercityCityId;
      if (itemsTotal != null && itemsTotal > 0) body['items_total'] = itemsTotal;

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/orders/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      final dynamic decoded = jsonDecode(response.body);
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      if (detail is String) {
        throw Exception(_mapServerDetail(detail));
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] is String) {
          throw Exception(first['msg'] as String);
        }
      }

      throw Exception('Заказ түзүүдө ката кетти');
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Заказ түзүүдө ката кетти');
    }
  }

  Future<List<Order>> getMyOrders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/my'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> ordersJson = jsonData is List ? jsonData : [];
        final result = ordersJson
            .map((order) => Order.fromJson(order as Map<String, dynamic>))
            .toList();
        return result;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Заказдарды жүктөө ишинде ошибка',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Заказдарды жүктөө ишинде ошибка');
    }
  }

  Future<List<Order>> getCourierOrders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/my'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> ordersJson = jsonData is List ? jsonData : [];
        final result = ordersJson
            .map((order) => Order.fromJson(order as Map<String, dynamic>))
            .toList();
        return result;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул бөлүм курьерлер үчүн гана.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Курьер заказдарын жүктөөдө ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Курьер заказдарын жүктөөдө ката кетти');
    }
  }

  Future<List<Order>> getAvailableCourierOrders(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/available'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> ordersJson = jsonData is List ? jsonData : [];
        return ordersJson
            .map((order) => Order.fromJson(order as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул бөлүм курьерлер үчүн гана.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String
              ? detail
              : 'Күтүүдөгү заказдарды жүктөөдө ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Күтүүдөгү заказдарды жүктөөдө ката кетти');
    }
  }

  Future<void> acceptCourierOrder(String token, int orderId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/$orderId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул аракет курьерлер үчүн гана.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Заказды кабыл алууда ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Заказды кабыл алууда ката кетти');
    }
  }

  Future<void> startDelivery(String token, int orderId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/$orderId/start'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул аракет курьерлер үчүн гана.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Жеткирүүнү баштоодо ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Жеткирүүнү баштоодо ката кетти');
    }
  }

  Future<void> completeDelivery(
    String token,
    int orderId,
    String verificationCode,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/$orderId/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'verification_code': verificationCode}),
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул аракет курьерлер үчүн гана.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Жеткирүүнү аяктоодо ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Жеткирүүнү аяктоодо ката кетти');
    }
  }

  Future<List<OrderStatusAuditEntry>> getOrderStatusAudit({
    required String token,
    required int orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/status-audit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          final raw = body['status_audit'];
          if (raw is List) {
            return raw
                .whereType<Map<String, dynamic>>()
                .map(OrderStatusAuditEntry.fromJson)
                .toList();
          }
        }
        return [];
      }

      if (response.statusCode == 404) return [];

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Статус тарыхын жүктөөдө ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Статус тарыхын жүктөөдө ката кетти');
    }
  }

  Future<String> markDelivered(String token, int orderId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/$orderId/delivered'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['verification_code'] != null) {
          return body['verification_code'].toString();
        }
        throw Exception('Тастыктоо коду алынган жок');
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул аракет курьерлер үчүн гана.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Жеткирилди деп белгилөөдө ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Жеткирилди деп белгилөөдө ката кетти');
    }
  }

  // Колдонуучу заказды отмена кылуу (күтүүдө статусунда гана)
  Future<void> cancelOrder(String token, int orderId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Сизде бул заказды жокко чыгаруу укугу жок.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Заказды жокко чыгарууда ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Заказды жокко чыгарууда ката кетти');
    }
  }

  // Курьер заказдан баш тартуу (кабыл алынган статусунда гана, -10 сом)
  Future<void> cancelCourierOrder(String token, int orderId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/$orderId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Сизде бул заказды жокко чыгаруу укугу жок.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Заказдан баш тартууда ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Заказдан баш тартууда ката кетти');
    }
  }

  Future<void> rateCourier({
    required String token,
    required int orderId,
    required int rating,
    String? comment,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/ratings/courier/$orderId')
          .replace(
            queryParameters: {
              'rating': rating.toString(),
              if (comment != null && comment.trim().isNotEmpty)
                'comment': comment.trim(),
            },
          );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) return;

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Курьерди баалоодо ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Курьерди баалоодо ката кетти');
    }
  }

  Future<void> rateUser({
    required String token,
    required int orderId,
    required int rating,
    String? comment,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/ratings/user/$orderId')
          .replace(
            queryParameters: {
              'rating': rating.toString(),
              if (comment != null && comment.trim().isNotEmpty)
                'comment': comment.trim(),
            },
          );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) return;

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String
            ? detail
            : 'Колдонуучунун маданияттуулугун баалоодо ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Колдонуучунун маданияттуулугун баалоодо ката кетти');
    }
  }

  Future<bool> isOrderAlreadyRated({
    required String token,
    required int orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/ratings/status/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return body['rated'] == true;
        }
      }

      if (response.statusCode == 404 || response.statusCode == 403) {
        return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<int> getOrderChatId({
    required String token,
    required int orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chat/order/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['chat_id'] != null) {
          return (body['chat_id'] as num).toInt();
        }
        throw Exception('Чат бөлмөсү табылган жок');
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(detail is String ? detail : 'Чатты ачууда ката кетти');
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Чатты ачууда ката кетти');
    }
  }

  Future<List<ChatMessage>> getChatMessages({
    required String token,
    required int chatId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chat/$chatId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is List) {
          return body
              .whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList();
        }
        throw Exception('Сервер жообу туура эмес форматта келди');
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Чат билдирүүлөрүн жүктөөдө ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Чат билдирүүлөрүн жүктөөдө ката кетти');
    }
  }

  Future<ChatContext> getChatContextByChatId({
    required String token,
    required int chatId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chat/$chatId/context'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return ChatContext.fromJson(body);
        }
        throw Exception('Сервер жообу туура эмес форматта келди');
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(detail is String ? detail : 'Чат контекстин алууда ката');
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Чат контекстин алууда ката');
    }
  }

  Future<void> sendChatMessage({
    required String token,
    required int chatId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}/chat/$chatId/send',
      ).replace(queryParameters: {'text': trimmed});

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) return;

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Билдирүү жөнөтүүдө ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Билдирүү жөнөтүүдө ката кетти');
    }
  }

  Uri buildChatWebSocketUri({required int chatId, required String token}) {
    return _buildWebSocketUri(path: '/chat/ws/$chatId', token: token);
  }

  Uri buildMyOrdersWebSocketUri({required String token}) {
    return _buildWebSocketUri(path: '/orders/ws/my', token: token);
  }

  Uri _buildWebSocketUri({required String path, required String token}) {
    final base = Uri.parse(AppConfig.baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';

    // Some runtimes may surface an invalid explicit ':0' port.
    // Keep only real custom ports and let ws/wss defaults apply otherwise.
    final int? port = (base.hasPort && base.port > 0) ? base.port : null;

    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: port,
      path: path,
      queryParameters: {'token': token},
    );
  }

  Future<void> markChatMessagesAsRead({
    required String token,
    required int chatId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chat/$chatId/read-messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        return;
      }
    } catch (_) {
      // Ignore read-marker errors, chat should remain usable.
    }
  }

  Future<int> getOrderUnreadChatCount({
    required String token,
    required int orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chat/order/$orderId/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return (body['unread_count'] as num?)?.toInt() ?? 0;
        }
        return 0;
      }

      if (response.statusCode == 404) {
        return 0;
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markOrderChatAsRead({
    required String token,
    required int orderId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/chat/$orderId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        return;
      }
    } catch (_) {
      // Ignore read-marker errors, chat should remain usable.
    }
  }

  Future<void> deleteOrder(String token, int orderId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      } else if (response.statusCode == 403) {
        throw Exception('Бул заказды өчүрүүгө укугуңуз жок.');
      } else if (response.statusCode == 404) {
        throw Exception('Заказ табылган жок.');
      } else {
        final dynamic body = jsonDecode(response.body);
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        throw Exception(
          detail is String ? detail : 'Заказды өчүрүүдө ката кетти',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Заказды өчүрүүдө ката кетти');
    }
  }

  Future<Map<String, dynamic>> deleteAllOrders(String token) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/orders/my/all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return body;
        }
        return {'message': 'Бардык заказдар тазаланды'};
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      if (response.statusCode == 403) {
        throw Exception('Сизде бул аракетке укук жок.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Заказдарды тазалоодо ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Заказдарды тазалоодо ката кетти');
    }
  }

  Future<Map<String, dynamic>> getCourierStats(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/courier/orders/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return body;
        }
        throw Exception('Сервер жообу туура эмес форматта келди');
      }

      if (response.statusCode == 401) {
        throw Exception('Сессия бүттү. Кайра кириңиз.');
      }

      if (response.statusCode == 403) {
        throw Exception('Бул маалымат курьерлер үчүн гана.');
      }

      final dynamic body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(
        detail is String ? detail : 'Статистиканы жүктөөдө ката кетти',
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Сервер жообу туура эмес форматта келди');
      }
      if (e is Exception) rethrow;
      throw Exception('Статистиканы жүктөөдө ката кетти');
    }
  }
}
