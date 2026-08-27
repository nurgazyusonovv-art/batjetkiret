class User {
  final int id;
  final String phone;
  final String name;
  final bool isCourier;
  final bool isAdmin;
  final double balance;
  final String? address;
  final bool isOnline;
  final String uniqueId;
  final String courierTransport;
  final String? courierVehiclePlate;
  final String? courierVehicleBrand;
  final String? courierVehicleColor;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.isCourier,
    required this.isAdmin,
    required this.balance,
    this.address,
    this.isOnline = false,
    required this.uniqueId,
    this.courierTransport = 'walking',
    this.courierVehiclePlate,
    this.courierVehicleBrand,
    this.courierVehicleColor,
  });

  bool get courierUsesCar =>
      courierTransport == 'car' || courierTransport == 'cargo';

  String get courierTransportLabel {
    switch (courierTransport) {
      case 'car':
        return 'Жеңил автоунаа';
      case 'cargo':
        return 'Жүк ташуучу автоунаа';
      case 'scooter':
        return 'Скутер';
      default:
        return 'Жөө';
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      isCourier: json['is_courier'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      balance: (json['balance'] ?? 0).toDouble(),
      address: json['address'],
      isOnline: json['is_online'] ?? false,
      uniqueId: json['unique_id'] ?? '',
      courierTransport: (json['courier_transport'] ?? 'walking').toString(),
      courierVehiclePlate: json['courier_vehicle_plate']?.toString(),
      courierVehicleBrand: json['courier_vehicle_brand']?.toString(),
      courierVehicleColor: json['courier_vehicle_color']?.toString(),
    );
  }
}
