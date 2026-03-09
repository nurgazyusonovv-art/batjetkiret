import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/orders/data/order_model.dart';
import 'package:frontend/features/orders/presentation/widgets/advanced_filter_dialog.dart';

void main() {
  Order makeOrder({
    required int id,
    required String createdAt,
    required double price,
  }) {
    return Order(
      id: id,
      category: 'food',
      fromAddress: 'From',
      toAddress: 'To',
      distance: 2,
      status: 'pending',
      description: 'desc',
      estimatedPrice: price,
      createdAt: createdAt,
    );
  }

  group('AdvancedFilterOptions', () {
    test('hasActiveFilters is false when all are null', () {
      const options = AdvancedFilterOptions();
      expect(options.hasActiveFilters, false);
    });

    test('filters by order id', () {
      const options = AdvancedFilterOptions(orderId: '12');
      expect(
        options.matchesOrder(
          makeOrder(id: 12, createdAt: '2026-03-08T10:00:00Z', price: 100),
        ),
        true,
      );
      expect(
        options.matchesOrder(
          makeOrder(id: 99, createdAt: '2026-03-08T10:00:00Z', price: 100),
        ),
        false,
      );
    });

    test('filters by price range using estimatedPrice', () {
      const options = AdvancedFilterOptions(minPrice: 100, maxPrice: 300);
      expect(
        options.matchesOrder(
          makeOrder(id: 1, createdAt: '2026-03-08T10:00:00Z', price: 50),
        ),
        false,
      );
      expect(
        options.matchesOrder(
          makeOrder(id: 2, createdAt: '2026-03-08T10:00:00Z', price: 200),
        ),
        true,
      );
      expect(
        options.matchesOrder(
          makeOrder(id: 3, createdAt: '2026-03-08T10:00:00Z', price: 400),
        ),
        false,
      );
    });

    test('filters by date range', () {
      final range = DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 10),
      );
      final options = AdvancedFilterOptions(dateRange: range);

      expect(
        options.matchesOrder(
          makeOrder(id: 1, createdAt: '2026-03-05T12:00:00Z', price: 150),
        ),
        true,
      );
      expect(
        options.matchesOrder(
          makeOrder(id: 2, createdAt: '2026-02-20T12:00:00Z', price: 150),
        ),
        false,
      );
    });
  });
}
