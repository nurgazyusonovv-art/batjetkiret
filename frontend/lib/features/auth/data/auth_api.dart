import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config.dart';

class AuthApi {
  Future<String> register({
    required String phone,
    required String name,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'name': name, 'password': password}),
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
    final response = await http.post(
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

  Future<String> forgotPassword({required String phone}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/forgot-password?phone=$phone'),
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
