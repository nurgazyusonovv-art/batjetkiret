import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config.dart';

class AuthApi {
  static const _requestTimeout = Duration(seconds: 20);

  Future<String> register({
    required String phone,
    required String name,
    required String password,
    String? referralCode,
  }) async {
    final code = (referralCode ?? '').trim();
    final response = await _post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'name': name,
        'password': password,
        // Optional: a friend's invite code. The server ignores an unknown one
        // rather than refusing the registration.
        if (code.isNotEmpty) 'referral_code': code,
      }),
    );

    final data = _decode(response.body);
    if (response.statusCode == 200 && data['access_token'] != null) {
      return data['access_token'] as String;
    }

    throw Exception(_extractError(data, fallback: 'Register failed'));
  }

  Future<String> login({
    required String phone,
    required String password,
  }) async {
    final response = await _post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    final data = _decode(response.body);
    if (response.statusCode == 200 && data['access_token'] != null) {
      return data['access_token'] as String;
    }

    throw Exception(_extractError(data, fallback: 'Login failed'));
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final response = await _post(
      Uri.parse(
        '${AppConfig.baseUrl}/auth/reset-password?phone=${Uri.encodeComponent(phone)}&code=$code&new_password=${Uri.encodeComponent(newPassword)}',
      ),
    );

    if (response.statusCode != 200) {
      final data = _decode(response.body);
      throw Exception(_extractError(data, fallback: 'Reset password failed'));
    }
  }

  Future<String> forgotPassword({required String phone}) async {
    final response = await _post(
      Uri.parse(
        '${AppConfig.baseUrl}/auth/forgot-password?phone=${Uri.encodeComponent(phone)}',
      ),
    );

    final data = _decode(response.body);
    if (response.statusCode == 200) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      return 'Code sent';
    }

    throw Exception(_extractError(data, fallback: 'Forgot password failed'));
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'Сервер жооп берген жок. Интернет байланышын текшерип, кайра аракет кылыңыз.',
      );
    } on http.ClientException {
      throw Exception(
        'Серверге туташуу мүмкүн болгон жок. Интернет байланышын текшериңиз.',
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final raw = jsonDecode(body);
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      return <String, dynamic>{};
    } catch (_) {
      // Backend may return plain text (e.g. "Internal Server Error").
      return <String, dynamic>{'detail': body};
    }
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
