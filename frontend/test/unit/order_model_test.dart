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
