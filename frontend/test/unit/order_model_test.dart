import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/orders/data/order_model.dart';

void main() {
  group('Order.fromJson', () {
    test('normalizes backend status and parses price/distance fields', () {
      final order = Order.fromJson({
        'id': 7,
        'category': 'food',
        'from_address': 'A',
        'to_address': 'B',
        'distance_km': 3.5,
        'status': 'COMPLETED',
        'description': 'test',
        'price': 180,
        'created_at': '2026-03-08T10:20:00Z',
      });

      expect(order.id, 7);
      expect(order.status, 'completed');
      expect(order.distance, 3.5);
      expect(order.estimatedPrice, 180.0);
      expect(order.categoryName, 'Тамак-аш');
    });

    test('falls back to pending when status is empty', () {
      final order = Order.fromJson({
        'id': 9,
        'category': 'other',
        'from_address': 'A',
        'to_address': 'B',
        'distance': 2,
        'status': '',
        'description': 'test',
        'created_at': '2026-03-08T10:20:00Z',
      });

      expect(order.status, 'pending');
    });

    test('maps courier and user nested objects', () {
      final order = Order.fromJson({
        'id': 11,
        'category': 'groceries',
        'from_address': 'A',
        'to_address': 'B',
        'distance': 1,
        'status': 'ACCEPTED',
        'description': 'test',
        'created_at': '2026-03-08T10:20:00Z',
        'courier': {'id': 2, 'name': 'Courier', 'phone': '+996700000001'},
        'user': {'id': 3, 'name': 'User', 'phone': '+996700000002'},
      });

      expect(order.status, 'accepted');
      expect(order.courierId, 2);
      expect(order.courierName, 'Courier');
      expect(order.userId, 3);
      expect(order.userName, 'User');
    });

    test('maps an admin external order and its contact phone', () {
      final order = Order.fromJson({
        'id': 15,
        'category': 'delivery',
        'order_type': 'delivery',
        'source': 'admin_external',
        'customer_phone': '+996700123456',
        'from_address': 'Баткен, базар',
        'to_address': 'Баткен, борбор',
        'distance_km': 0,
        'price': 0,
        'status': 'WAITING_COURIER',
        'description': 'Документ',
        'created_at': '2026-07-31T10:20:00Z',
      });

      expect(order.isAdminExternal, isTrue);
      expect(order.orderType, 'delivery');
      expect(order.customerPhone, '+996700123456');
      expect(order.userPhone, '+996700123456');
    });

    test('maps courier transport details', () {
      final order = Order.fromJson({
        'id': 16,
        'category': 'food',
        'from_address': 'A',
        'to_address': 'B',
        'distance_km': 2,
        'price': 150,
        'status': 'ACCEPTED',
        'description': 'Тамак',
        'created_at': '2026-07-31T10:20:00Z',
        'courier': {
          'id': 4,
          'name': 'Courier',
          'phone': '+996700000004',
          'transport': 'car',
          'vehicle_plate': '01 KG 123 ABC',
          'vehicle_brand': 'Toyota Camry',
          'vehicle_color': 'Кара',
        },
      });

      expect(order.courierTransport, 'car');
      expect(order.courierTransportLabel, 'Жеңил автоунаа');
      expect(order.courierVehiclePlate, '01 KG 123 ABC');
      expect(order.courierVehicleBrand, 'Toyota Camry');
      expect(order.courierVehicleColor, 'Кара');
    });
  });

  group('Order.copyWith', () {
    test('keeps old fields and updates provided ones', () {
      final original = Order(
        id: 1,
        category: 'food',
        fromAddress: 'A',
        toAddress: 'B',
        distance: 4,
        status: 'pending',
        description: 'desc',
        estimatedPrice: 120,
        createdAt: '2026-03-08T10:20:00Z',
      );

      final updated = original.copyWith(
        status: 'accepted',
        estimatedPrice: 140,
      );

      expect(updated.id, 1);
      expect(updated.status, 'accepted');
      expect(updated.estimatedPrice, 140);
      expect(updated.fromAddress, 'A');
    });
  });
}
