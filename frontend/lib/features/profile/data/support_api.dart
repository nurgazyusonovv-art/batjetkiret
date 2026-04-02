import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';

class ContactInfo {
  final String telegram;
  final String whatsapp;
  const ContactInfo({required this.telegram, required this.whatsapp});
}

class AppSettings {
  final String telegram;
  final String whatsapp;
  final double userServiceFee;
  final double courierServiceFee;
  final double deliveryBasePrice;
  final double deliveryPricePerKm;

  const AppSettings({
    required this.telegram,
    required this.whatsapp,
    required this.userServiceFee,
    required this.courierServiceFee,
    required this.deliveryBasePrice,
    required this.deliveryPricePerKm,
  });

  static const AppSettings defaults = AppSettings(
    telegram: '',
    whatsapp: '',
    userServiceFee: 5,
    courierServiceFee: 5,
    deliveryBasePrice: 80,
    deliveryPricePerKm: 20,
  );
}

class SupportApi {
  Future<ContactInfo> getContactInfo() async {
    final settings = await getAppSettings();
    return ContactInfo(telegram: settings.telegram, whatsapp: settings.whatsapp);
  }

  Future<AppSettings> getAppSettings() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/public-settings'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AppSettings(
          telegram: (data['contact_telegram'] ?? '').toString(),
          whatsapp: (data['contact_whatsapp'] ?? '').toString(),
          userServiceFee: double.tryParse(data['user_service_fee']?.toString() ?? '') ?? 5,
          courierServiceFee: double.tryParse(data['courier_service_fee']?.toString() ?? '') ?? 5,
          deliveryBasePrice: double.tryParse(data['delivery_base_price']?.toString() ?? '') ?? 80,
          deliveryPricePerKm: double.tryParse(data['delivery_price_per_km']?.toString() ?? '') ?? 20,
        );
      }
    } catch (_) {}
    return AppSettings.defaults;
  }
}
