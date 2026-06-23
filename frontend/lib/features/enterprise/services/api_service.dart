import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:frontend/core/config.dart';
import 'package:file_picker/file_picker.dart';
import 'auth_service.dart';

class ApiService {
  static Future<Dio> _client() async {
    final token = await AuthService.getToken();
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<String> login(String phone, String password) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final resp = await dio.post(
      '/enterprise-portal/login',
      data: {'phone': phone, 'password': password},
    );
    return resp.data['access_token'] as String;
  }

  // ── Me / Enterprise ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMe() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/me');
    return resp.data as Map<String, dynamic>;
  }

  static Future<String> uploadEnterpriseLogo(
    int enterpriseId,
    PlatformFile imageFile,
  ) async {
    final dio = await _client();
    final bytes = imageFile.bytes ?? Uint8List(0);
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'logo.jpg';
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await dio.post('/enterprises/$enterpriseId/logo', data: form);
    return resp.data['logo_data'] as String;
  }

  static Future<void> saveFcmToken(String token) async {
    final dio = await _client();
    await dio.post('/enterprise-portal/fcm-token', data: {'token': token});
  }

  /// [isOpen] = true → force open, false → force closed, null → auto (follow working hours).
  static Future<bool?> setOpenStatus(bool? isOpen) async {
    final dio = await _client();
    final resp = await dio.patch(
      '/enterprise-portal/me/open-status',
      data: {'is_open': isOpen},
    );
    return resp.data['is_open_override'] as bool?;
  }

  // ── Stats & Reports ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStats() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/stats');
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getReports({int days = 1}) async {
    final dio = await _client();
    final resp = await dio.get(
      '/enterprise-portal/reports',
      queryParameters: {'days': days},
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Orders ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getOrders({String? status}) async {
    final dio = await _client();
    final resp = await dio.get(
      '/enterprise-portal/orders',
      queryParameters: status != null ? {'status': status} : null,
    );
    return resp.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getOrderDetail(int orderId) async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/orders/$orderId');
    return resp.data as Map<String, dynamic>;
  }

  // ── Payments ─────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getPayments({String? status}) async {
    final dio = await _client();
    final resp = await dio.get(
      '/enterprise-portal/payments',
      queryParameters: status != null ? {'status': status} : null,
    );
    return resp.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> confirmPayment(
    int paymentId, {
    String? note,
  }) async {
    final dio = await _client();
    final resp = await dio.post(
      '/enterprise-portal/payments/$paymentId/confirm',
      data: note != null ? {'note': note} : {},
    );
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> rejectPayment(
    int paymentId, {
    String? note,
  }) async {
    final dio = await _client();
    final resp = await dio.post(
      '/enterprise-portal/payments/$paymentId/reject',
      data: note != null ? {'note': note} : {},
    );
    return resp.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getHistory() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/history');
    return resp.data as List<dynamic>;
  }

  static Future<void> updateOrderStatus(
    int orderId,
    String status, {
    String? note,
  }) async {
    final dio = await _client();
    await dio.post(
      '/enterprise-portal/orders/$orderId/update-status',
      queryParameters: {'status': status, 'note': note},
    );
  }

  static Future<Map<String, dynamic>> createLocalOrder(
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    final resp = await dio.post(
      '/enterprise-portal/orders/create-local',
      data: data,
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Categories ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getCategories() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/categories');
    return resp.data as List<dynamic>;
  }

  static Future<void> createCategory(String name, {int sortOrder = 0}) async {
    final dio = await _client();
    await dio.post(
      '/enterprise-portal/categories',
      data: {'name': name, 'sort_order': sortOrder},
    );
  }

  static Future<void> updateCategory(
    int id,
    String name, {
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final dio = await _client();
    await dio.put(
      '/enterprise-portal/categories/$id',
      data: {'name': name, 'is_active': isActive, 'sort_order': sortOrder},
    );
  }

  static Future<void> deleteCategory(int id) async {
    final dio = await _client();
    await dio.delete('/enterprise-portal/categories/$id');
  }

  // ── Products ────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getProducts() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/products');
    return resp.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    final resp = await dio.post('/enterprise-portal/products', data: data);
    return resp.data as Map<String, dynamic>;
  }

  static Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    final dio = await _client();
    await dio.put('/enterprise-portal/products/$id', data: data);
  }

  static Future<void> deleteProduct(int id) async {
    final dio = await _client();
    await dio.delete('/enterprise-portal/products/$id');
  }

  static Future<void> uploadProductImage(
    int productId,
    PlatformFile imageFile,
  ) async {
    final dio = await _client();
    final bytes = imageFile.bytes ?? Uint8List(0);
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'product.jpg';
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await dio.post('/enterprise-portal/products/$productId/image', data: form);
  }

  // ── Location ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateLocation(
    double lat,
    double lon,
  ) async {
    final dio = await _client();
    final resp = await dio.patch(
      '/enterprise-portal/me/location',
      data: {'lat': lat, 'lon': lon},
    );
    return resp.data as Map<String, dynamic>;
  }

  // ── Payment QR ───────────────────────────────────────────────────────────────

  static Future<String> uploadPaymentQr(PlatformFile imageFile) async {
    final dio = await _client();
    final bytes = imageFile.bytes ?? Uint8List(0);
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'qr.jpg';
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final resp = await dio.post('/enterprise-portal/payment-qr', data: form);
    return resp.data['payment_qr_url'] as String;
  }

  static Future<void> deletePaymentQr() async {
    final dio = await _client();
    await dio.delete('/enterprise-portal/payment-qr');
  }

  // ── Password ─────────────────────────────────────────────────────────────────

  static Future<void> changePassword(String current, String newPass) async {
    final dio = await _client();
    await dio.post(
      '/enterprise-portal/change-password',
      data: {'current_password': current, 'new_password': newPass},
    );
  }

  // ── History ──────────────────────────────────────────────────────────────────

  static Future<void> deleteHistoryOrder(int orderId) async {
    final dio = await _client();
    await dio.delete('/enterprise-portal/history/$orderId');
  }

  static Future<void> clearHistory() async {
    final dio = await _client();
    await dio.delete('/enterprise-portal/history');
  }
}
