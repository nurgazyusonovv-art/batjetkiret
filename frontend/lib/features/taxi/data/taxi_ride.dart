/// The phase a taxi order is in, from the passenger's point of view.
enum TaxiRidePhase {
  /// Waiting for a driver to take the order.
  searching,

  /// A driver took it and is on the way to the passenger.
  driverOnTheWay,

  /// The passenger is in the car.
  inRide,

  /// Ride finished — time to rate it.
  finished,

  cancelled,
}

/// A taxi order as the ride screen needs it.
///
/// Deliberately separate from the delivery `Order` model: this screen shows a
/// ride, and only the fields a ride has.
class TaxiRide {
  const TaxiRide({
    required this.id,
    required this.status,
    required this.fromAddress,
    required this.toAddress,
    required this.price,
    required this.distanceKm,
    this.driverName,
    this.driverPhone,
    this.carBrand,
    this.carColor,
    this.carPlate,
  });

  final int id;
  final String status;
  final String fromAddress;
  final String toAddress;
  final double price;
  final double distanceKm;
  final String? driverName;
  final String? driverPhone;
  final String? carBrand;
  final String? carColor;
  final String? carPlate;

  bool get hasDriver => (driverName ?? '').isNotEmpty;

  TaxiRidePhase get phase {
    switch (status.toUpperCase()) {
      case 'WAITING_COURIER':
        return TaxiRidePhase.searching;
      case 'ACCEPTED':
      case 'PREPARING':
      case 'READY':
        return TaxiRidePhase.driverOnTheWay;
      case 'PICKED_UP':
      case 'ON_THE_WAY':
      case 'IN_TRANSIT':
        return TaxiRidePhase.inRide;
      case 'DELIVERED':
      case 'COMPLETED':
        return TaxiRidePhase.finished;
      case 'CANCELLED':
        return TaxiRidePhase.cancelled;
      default:
        return TaxiRidePhase.searching;
    }
  }

  /// A ride can only be called off before the passenger is picked up.
  bool get isCancellable =>
      phase == TaxiRidePhase.searching || phase == TaxiRidePhase.driverOnTheWay;

  String get carLabel {
    final parts = [
      carBrand,
      carColor,
    ].where((p) => (p ?? '').trim().isNotEmpty).map((p) => p!.trim());
    return parts.isEmpty ? 'Унаа' : parts.join(', ');
  }

  factory TaxiRide.fromJson(Map<String, dynamic> json) {
    final courier = json['courier'];
    final driver = courier is Map<String, dynamic> ? courier : const {};
    double asDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    return TaxiRide(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? '').toString(),
      fromAddress: (json['from_address'] ?? '').toString(),
      toAddress: (json['to_address'] ?? '').toString(),
      price: asDouble(json['price'] ?? json['estimated_price']),
      distanceKm: asDouble(json['distance_km']),
      driverName: (driver['name'] ?? json['courier_name'])?.toString(),
      driverPhone: (driver['phone'] ?? json['courier_phone'])?.toString(),
      carBrand:
          (driver['courier_vehicle_brand'] ?? json['courier_vehicle_brand'])
              ?.toString(),
      carColor:
          (driver['courier_vehicle_color'] ?? json['courier_vehicle_color'])
              ?.toString(),
      carPlate:
          (driver['courier_vehicle_plate'] ?? json['courier_vehicle_plate'])
              ?.toString(),
    );
  }
}
