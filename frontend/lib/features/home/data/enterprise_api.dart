import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import 'enterprise_model.dart';

const _enterpriseRequestTimeout = Duration(seconds: 25);
const _enterpriseTimeoutMessage =
    'Интернет жай болуп жатат. Кайра аракет кылыңыз.';

class EnterpriseClosedException implements Exception {
  const EnterpriseClosedException();
}

class EnterpriseApi {
  Future<List<Enterprise>> fetchEnterprises({
    String? token,
    required String category,
  }) async {
    final url = Uri.parse(
      '${AppConfig.baseUrl}/enterprises/active?category=$category',
    );
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(_enterpriseRequestTimeout);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Enterprise.fromJson(e)).toList();
      } else {
        throw Exception('Ишканалар тизмесин алуу мүмкүн эмес');
      }
    } on TimeoutException {
      throw Exception(_enterpriseTimeoutMessage);
    } on FormatException {
      throw Exception('Серверден маалымат туура эмес келди');
    }
  }

  Future<EnterpriseMenu> fetchEnterpriseMenu({
    String? token,
    required int enterpriseId,
  }) async {
    final url = Uri.parse(
      '${AppConfig.baseUrl}/enterprises/$enterpriseId/menu',
    );
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(_enterpriseRequestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EnterpriseMenu.fromJson(data);
      } else if (response.statusCode == 423) {
        throw EnterpriseClosedException();
      } else if (response.statusCode == 404) {
        throw Exception('Ишкана табылган жок');
      } else {
        throw Exception('Меню жүктөө мүмкүн эмес');
      }
    } on TimeoutException {
      throw Exception(_enterpriseTimeoutMessage);
    } on FormatException {
      throw Exception('Серверден маалымат туура эмес келди');
    }
  }
}
