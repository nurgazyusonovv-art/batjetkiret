import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';
import 'ad_popup_model.dart';

class AdPopupApi {
  static Future<AdPopupItem?> fetchCurrent() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.baseUrl}/ad-popup'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (body == 'null' || body.isEmpty) return null;
        final json = jsonDecode(body);
        if (json == null) return null;
        return AdPopupItem.fromJson(json as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
