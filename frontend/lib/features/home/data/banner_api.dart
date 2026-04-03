import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import 'banner_model.dart';

class BannerApi {
  Future<List<BannerItem>> fetchBanners() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.baseUrl}/banners'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => BannerItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }
}
