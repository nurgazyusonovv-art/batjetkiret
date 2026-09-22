import 'package:frontend/features/profile/data/support_api.dart';

/// Fare for a city taxi ride.
///
/// Mirrors the backend's calculate_price so the passenger is quoted what they
/// will be charged. The server still prices the order itself from its own
/// distance, so treat this as an estimate, not a promise.
class TaxiFare {
  const TaxiFare({
    required this.distanceKm,
    required this.price,
    required this.serviceFee,
  });

  final double distanceKm;
  final double price;
  final double serviceFee;

  static TaxiFare estimate({
    required double distanceKm,
    required AppSettings settings,
  }) {
    final extraKm = (distanceKm - settings.taxiExtraAfterKm).clamp(
      0.0,
      double.infinity,
    );
    final price =
        settings.taxiBasePrice +
        distanceKm * settings.taxiPricePerKm +
        extraKm * settings.taxiExtraPricePerKm;
    return TaxiFare(
      distanceKm: distanceKm,
      price: price,
      serviceFee: settings.userServiceFee,
    );
  }

  String get priceLabel => '${price.round()} сом';

  String get distanceLabel => distanceKm < 1
      ? '${(distanceKm * 1000).round()} м'
      : '${distanceKm.toStringAsFixed(1)} км';
}
