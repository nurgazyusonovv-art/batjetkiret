import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config.dart';

class NotificationsService {
  Future<void> sendNotificationToAdmin({
    required String title,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title, 'message': message}),
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
