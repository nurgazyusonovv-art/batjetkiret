import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:frontend/core/auth_event_bus.dart';
import 'package:frontend/core/config.dart';
import 'package:frontend/features/advertisements/data/advertisement_model.dart';
import 'package:http/http.dart' as http;

class AdvertisementApi {
  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  String _messageFromResponse(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {}
    return fallback;
  }

  void _handleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      AuthEventBus.instance.fireUnauthorized();
      throw const UnauthorizedException();
    }
  }

  Future<AdvertisementSettings> getSettings(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/advertisements/settings'),
      headers: _headers(token),
    );
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(
        _messageFromResponse(response, 'Настройкалар жүктөлгөн жок'),
      );
    }
    return AdvertisementSettings.fromJson(jsonDecode(response.body));
  }

  Future<List<Advertisement>> getActive() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/advertisements'),
    );
    if (response.statusCode != 200) {
      throw Exception('Жарнамалар жүктөлгөн жок');
    }
    final decoded = jsonDecode(response.body);
    return (decoded as List)
        .map((e) => Advertisement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> registerView(int id) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/advertisements/$id/view'),
    );
    if (response.statusCode != 200) {
      return 0;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ((decoded['view_count'] as num?) ?? 0).toInt();
  }

  Future<List<Advertisement>> getMine(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/advertisements/my'),
      headers: _headers(token),
    );
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(
        _messageFromResponse(response, 'Менин жарнамаларым жүктөлгөн жок'),
      );
    }
    final decoded = jsonDecode(response.body);
    return (decoded as List)
        .map((e) => Advertisement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadImage({
    required String token,
    required PlatformFile file,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/advertisements/upload-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes as Uint8List,
          filename: file.name,
        ),
      );
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    } else {
      throw Exception('Сүрөт тандалган жок');
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_messageFromResponse(response, 'Сүрөт жүктөлгөн жок'));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['url'] as String;
  }

  Future<Advertisement> create({
    required String token,
    required String title,
    required String description,
    required int durationDays,
    String? category,
    String? contactPhone,
    String? imageUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/advertisements'),
      headers: _headers(token),
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'contact_phone': contactPhone,
        'image_url': imageUrl,
        'duration_days': durationDays,
      }),
    );
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_messageFromResponse(response, 'Жарнама түзүлгөн жок'));
    }
    return Advertisement.fromJson(jsonDecode(response.body));
  }

  Future<Advertisement> stop({required String token, required int id}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/advertisements/$id/stop'),
      headers: _headers(token),
    );
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(
        _messageFromResponse(response, 'Жарнама токтотулган жок'),
      );
    }
    return Advertisement.fromJson(jsonDecode(response.body));
  }

  Future<Advertisement> delete({required String token, required int id}) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}/advertisements/$id'),
      headers: _headers(token),
    );
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception(_messageFromResponse(response, 'Жарнама өчүрүлгөн жок'));
    }
    return Advertisement.fromJson(jsonDecode(response.body));
  }
}
