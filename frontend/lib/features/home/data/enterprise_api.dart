import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import 'enterprise_model.dart';

class EnterpriseApi {
  Future<List<Enterprise>> fetchEnterprises({
    required String token,
    required String category,
  }) async {
    final url = Uri.parse(
      '${AppConfig.baseUrl}/enterprises/active?category=$category',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Enterprise.fromJson(e)).toList();
    } else {
      throw Exception('Ишканалар тизмесин алуу мүмкүн эмес');
    }
  }

  Future<EnterpriseMenu> fetchEnterpriseMenu({
    required String token,
    required int enterpriseId,
  }) async {
    final url = Uri.parse(
      '${AppConfig.baseUrl}/enterprises/$enterpriseId/menu',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return EnterpriseMenu.fromJson(data);
    } else if (response.statusCode == 404) {
      throw Exception('Ишкана табылган жок');
    } else {
      throw Exception('Меню жүктөө мүмкүн эмес');
    }
  }
}
