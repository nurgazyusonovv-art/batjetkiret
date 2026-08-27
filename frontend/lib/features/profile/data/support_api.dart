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
  final double deliveryExtraAfterKm;
  final double deliveryExtraPricePerKm;
  final double taxiBasePrice;
  final double taxiPricePerKm;
  final double taxiExtraAfterKm;
  final double taxiExtraPricePerKm;

  const AppSettings({
    required this.telegram,
    required this.whatsapp,
    required this.userServiceFee,
    required this.courierServiceFee,
    required this.deliveryBasePrice,
    required this.deliveryPricePerKm,
    required this.deliveryExtraAfterKm,
    required this.deliveryExtraPricePerKm,
    required this.taxiBasePrice,
    required this.taxiPricePerKm,
    required this.taxiExtraAfterKm,
    required this.taxiExtraPricePerKm,
  });

  static const AppSettings defaults = AppSettings(
    telegram: '',
    whatsapp: '',
    userServiceFee: 5,
    courierServiceFee: 5,
    deliveryBasePrice: 80,
    deliveryPricePerKm: 20,
    deliveryExtraAfterKm: 4,
    deliveryExtraPricePerKm: 0,
    taxiBasePrice: 100,
    taxiPricePerKm: 30,
    taxiExtraAfterKm: 4,
    taxiExtraPricePerKm: 0,
  );

  double deliveryPriceFor(double distanceKm) {
    final extraKm = (distanceKm - deliveryExtraAfterKm)
        .clamp(0, double.infinity)
        .toDouble();
    return deliveryBasePrice +
        distanceKm * deliveryPricePerKm +
        extraKm * deliveryExtraPricePerKm;
  }

  double taxiPriceFor(double distanceKm) {
    final extraKm = (distanceKm - taxiExtraAfterKm)
        .clamp(0, double.infinity)
        .toDouble();
    return taxiBasePrice +
        distanceKm * taxiPricePerKm +
        extraKm * taxiExtraPricePerKm;
  }
}

class SupportApi {
  Future<ContactInfo> getContactInfo() async {
    final settings = await getAppSettings();
    return ContactInfo(
      telegram: settings.telegram,
      whatsapp: settings.whatsapp,
    );
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
          userServiceFee:
              double.tryParse(data['user_service_fee']?.toString() ?? '') ?? 5,
          courierServiceFee:
              double.tryParse(data['courier_service_fee']?.toString() ?? '') ??
              5,
          deliveryBasePrice:
              double.tryParse(data['delivery_base_price']?.toString() ?? '') ??
              80,
          deliveryPricePerKm:
              double.tryParse(
                data['delivery_price_per_km']?.toString() ?? '',
              ) ??
              20,
          deliveryExtraAfterKm:
              double.tryParse(
                data['delivery_extra_after_km']?.toString() ?? '',
              ) ??
              double.tryParse(data['delivery_included_km']?.toString() ?? '') ??
              4,
          deliveryExtraPricePerKm:
              double.tryParse(
                data['delivery_extra_price_per_km']?.toString() ?? '',
              ) ??
              0,
          taxiBasePrice:
              double.tryParse(data['taxi_base_price']?.toString() ?? '') ?? 100,
          taxiPricePerKm:
              double.tryParse(data['taxi_price_per_km']?.toString() ?? '') ??
              30,
          taxiExtraAfterKm:
              double.tryParse(data['taxi_extra_after_km']?.toString() ?? '') ??
              double.tryParse(data['taxi_included_km']?.toString() ?? '') ??
              4,
          taxiExtraPricePerKm:
              double.tryParse(
                data['taxi_extra_price_per_km']?.toString() ?? '',
              ) ??
              0,
        );
      }
    } catch (_) {}
    return AppSettings.defaults;
  }
}
