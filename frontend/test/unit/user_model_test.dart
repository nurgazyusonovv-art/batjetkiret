import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/data/user_model.dart';

void main() {
  test('User maps courier transport and plate', () {
    final user = User.fromJson({
      'id': 4,
      'phone': '+996700000004',
      'name': 'Courier',
      'is_courier': true,
      'is_admin': false,
      'balance': 100,
      'is_online': true,
      'unique_id': 'BJ000004',
      'courier_transport': 'cargo',
      'courier_vehicle_plate': '02 KG 456 ABC',
      'courier_vehicle_brand': 'Mercedes Sprinter',
      'courier_vehicle_color': 'Ак',
    });

    expect(user.courierTransport, 'cargo');
    expect(user.courierTransportLabel, 'Жүк ташуучу автоунаа');
    expect(user.courierUsesCar, isTrue);
    expect(user.courierVehiclePlate, '02 KG 456 ABC');
    expect(user.courierVehicleBrand, 'Mercedes Sprinter');
    expect(user.courierVehicleColor, 'Ак');
  });
}
