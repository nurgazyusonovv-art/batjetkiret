import 'dart:io';
import 'package:dio/dio.dart';
import 'auth_service.dart';

const _base = 'https://batjetkiret-production.up.railway.app';

class ApiService {
  static Future<Dio> _client() async {
    final token = await AuthService.getToken();
    return Dio(BaseOptions(
      baseUrl: _base,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  static Future<String> login(String phone, String password) async {
    final dio = Dio(BaseOptions(baseUrl: _base));
    final resp = await dio.post('/enterprise-portal/login',
        data: {'phone': phone, 'password': password});
    return resp.data['access_token'] as String;
  }

  // ── Me / Enterprise ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMe() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/me');
    return resp.data as Map<String, dynamic>;
  }

  static Future<void> setOpenStatus(bool? isOpen) async {
    final dio = await _client();
    await dio.patch('/enterprise-portal/me/open-status',
        data: {'is_open': isOpen});
  }

  // ── Stats & Reports ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStats() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/stats');
    return resp.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getReports({int days = 1}) async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/reports',
        queryParameters: {'days': days});
    return resp.data as Map<String, dynamic>;
  }

  // ── Orders ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getOrders({String? status}) async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/orders',
        queryParameters: status != null ? {'status': status} : null);
    return resp.data as List<dynamic>;
  }

  static Future<List<dynamic>> getHistory() async {
    final dio = await _client();
    final resp = await dio.get('/enterprise-portal/history');
    return resp.data as List<dynamic>;
  }

  static Future<void> updateOrderStatus(int orderId, String status,
      {String? note}) async {
    final dio = await _client();
    await dio.post('/enterprise-portal/orders/$orderId/update-status',
        queryParameters: {'status': status, 'note': note});
  }

  static Future<Map<String, dynamic>> createLocalOrder(
      Map<String, dynamic> data) async {
    final dio = await _client();
    final resp = await dio.post('/enterprise-portal/orders/create-local',
        data: data);
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
    await dio.post('/enterprise-portal/categories',
        data: {'name': name, 'sort_order': sortOrder});
  }

  static Future<void> updateCategory(int id, String name,
      {bool isActive = true, int sortOrder = 0}) async {
    final dio = await _client();
    await dio.put('/enterprise-portal/categories/$id',
        data: {'name': name, 'is_active': isActive, 'sort_order': sortOrder});
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

  static Future<void> createProduct(Map<String, dynamic> data) async {
    final dio = await _client();
    await dio.post('/enterprise-portal/products', data: data);
  }

  static Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    final dio = await _client();
    await dio.put('/enterprise-portal/products/$id', data: data);
  }

  static Future<void> deleteProduct(int id) async {
    final dio = await _client();
    await dio.delete('/enterprise-portal/products/$id');
  }

  static Future<void> uploadProductImage(int productId, File imageFile) async {
    final dio = await _client();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    await dio.post('/enterprise-portal/products/$productId/image', data: form);
  }
}
