import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config.dart';

class SupportNotificationsService {
  Future<void> sendNotificationToAdmin({
    required String title,
    required String message,
    required String token,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/notifications/support-message').replace(
        queryParameters: {'title': title, 'message': message},
      );
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      // Try to parse error details from response
      String errorDetail =
          'Билдирүүнү жөнөтүүдө ката кетти (${response.statusCode})';
      if (response.body.isNotEmpty) {
        try {
          final dynamic body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body.containsKey('detail')) {
            final detail = body['detail'];
            if (detail is String) {
              errorDetail = detail;
            }
          }
        } catch (e) {
          // If JSON decoding fails, just use the raw response or error code message
          errorDetail =
              'Билдирүүнү жөнөтүүдө ката кетти (${response.statusCode})';
        }
      }
      throw Exception(errorDetail);
    } on http.ClientException catch (e) {
      throw Exception('Админге билдирүү жөнөтүүдө сервер ката: $e');
    } catch (e) {
      throw Exception('Билдирүүнү жөнөтүүдө ката кетти: $e');
    }
  }
}
