import 'package:dio/dio.dart';
import 'auth_service.dart';

const _baseUrl = 'https://batjetkiret-production.up.railway.app';

class ApiService {
  static Future<Dio> _client() async {
    final token = await AuthService.getToken();
    return Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  static Future<List<dynamic>> getResetRequests() async {
    final dio = await _client();
    final resp = await dio.get('/admin/password-reset-requests');
    return resp.data as List<dynamic>;
  }

  static Future<void> dismiss(int resetId) async {
    final dio = await _client();
    await dio.post('/admin/password-reset-requests/$resetId/dismiss');
  }

  static Future<List<dynamic>> getTopUpRequests() async {
    final dio = await _client();
    final resp = await dio.get('/admin/topup-requests/pending');
    return resp.data as List<dynamic>;
  }

  static Future<void> approveTopUp(int id) async {
    final dio = await _client();
    await dio.post('/admin/topup-requests/$id/approve');
  }

  static Future<void> rejectTopUp(int id, String note) async {
    final dio = await _client();
    await dio.post(
      '/admin/topup-requests/$id/reject',
      queryParameters: {'admin_note': note},
    );
  }

  static Future<String> getTopUpScreenshot(int id) async {
    final dio = await _client();
    final resp = await dio.get('/admin/topup-requests/$id/screenshot');
    return resp.data['file_url'] as String;
  }

  // ── Support Chats ──────────────────────────────────────────────────────────

  static Future<List<dynamic>> getSupportChats() async {
    final dio = await _client();
    final resp = await dio.get('/admin/support-chats');
    return resp.data as List<dynamic>;
  }

  static Future<List<dynamic>> getChatMessages(int chatId) async {
    final dio = await _client();
    final resp = await dio.get('/chat/$chatId/messages');
    return resp.data as List<dynamic>;
  }

  static Future<void> sendSupportMessage(int chatId, String text) async {
    final dio = await _client();
    await dio.post('/chat/$chatId/send', queryParameters: {'text': text});
  }

  static Future<void> markChatRead(int chatId) async {
    final dio = await _client();
    await dio.post('/chat/$chatId/read-messages');
  }

  static String chatWebSocketUrl(int chatId, String token) {
    const wsBase = 'wss://batjetkiret-production.up.railway.app';
    return '$wsBase/chat/ws/$chatId?token=$token';
  }

  // ── Cancel Requests ────────────────────────────────────────────────────────

  static Future<List<dynamic>> getCancelRequests() async {
    final dio = await _client();
    final resp = await dio.get('/admin/cancel-requests');
    return resp.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> approveCancelRequest(
    int orderId, {
    String adminNote = '',
    double? userDeductAmount,
    double? courierPayoutAmount,
  }) async {
    final dio = await _client();
    final resp = await dio.post(
      '/admin/cancel-requests/$orderId/approve',
      data: {
        'admin_note': adminNote,
        'user_deduct_amount': userDeductAmount,
        'courier_payout_amount': courierPayoutAmount,
      },
    );
    return resp.data as Map<String, dynamic>;
  }

  static Future<void> rejectCancelRequest(int orderId,
      {String adminNote = ''}) async {
    final dio = await _client();
    await dio.post(
      '/admin/cancel-requests/$orderId/reject',
      data: {'admin_note': adminNote},
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getStats() async {
    final dio = await _client();
    final resp = await dio.get('/admin/stats');
    return resp.data as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getRevenueTrend({int days = 7}) async {
    final dio = await _client();
    final resp = await dio.get('/admin/revenue-trend', queryParameters: {'days': days});
    return resp.data as List<dynamic>;
  }

  static Future<int> getCancelRequestsCount() async {
    final dio = await _client();
    final resp = await dio.get('/admin/cancel-requests/count');
    return (resp.data['count'] as num?)?.toInt() ?? 0;
  }
}
