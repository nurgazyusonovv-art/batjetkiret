import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

const _baseUrl = 'https://batjetkiret-production.up.railway.app';
const _storage = FlutterSecureStorage();
final _dio = Dio(BaseOptions(baseUrl: _baseUrl));

class AuthService {
  static Future<String?> getToken() => _storage.read(key: 'token');

  static Future<void> login(String phone, String password) async {
    final resp = await _dio.post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );
    final token = resp.data['access_token'] as String;
    await _storage.write(key: 'token', value: token);
    uploadFcmToken(); // fire-and-forget, не блокируем логин
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'token');
  }

  static Future<void> uploadFcmToken() async {
    final authToken = await getToken();
    if (authToken == null) return;

    String? fcmToken;
    // 5 жолу кайра сурайбыз, exception болсо жөн өтөбүз
    for (int i = 0; i < 5; i++) {
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) break;
      } catch (_) {
        // SERVICE_NOT_AVAILABLE — кийинки iteration'до кайра сурайбыз
      }
      await Future.delayed(Duration(seconds: 3 * (i + 1)));
    }

    if (fcmToken == null) return;

    try {
      final resp = await _dio.post(
        '/admin/fcm-token',
        data: {'fcm_token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
      // ignore: avoid_print
      print('[AdminApp] FCM token uploaded: status=${resp.statusCode}');
    } catch (e) {
      // ignore: avoid_print
      print('[AdminApp] FCM token upload FAILED: $e');
    }
  }
}
