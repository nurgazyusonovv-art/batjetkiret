import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/orders/data/order_api.dart';
import 'package:frontend/features/orders/data/order_model.dart';
import 'package:frontend/features/orders/presentation/cubit/order_detail_cubit.dart';
import 'package:frontend/features/orders/presentation/cubit/order_detail_state.dart';

// Mock OrderApi
class MockOrderApi extends Mock implements OrderApi {}

void main() {
  group('OrderDetailCubit', () {
    late MockOrderApi mockOrderApi;
    late Order testOrder;

    setUp(() {
      mockOrderApi = MockOrderApi();
      testOrder = Order(
        id: 1,
        category: 'food',
        fromAddress: 'Улица 1',
        toAddress: 'Улица 2',
        distance: 5.0,
        status: 'pending',
        description: 'Тест заказ',
        estimatedPrice: 100.0,
        courierName: null,
        courierPhone: null,
        courierId: null,
        createdAt: '2024-01-01',
        verificationCode: null,
      );
    });

    // Test: Initial state verification
    test('emits initial state with provided order', () {
      final cubit = OrderDetailCubit(
        initialOrder: testOrder,
        orderApi: mockOrderApi,
      );

      expect(cubit.state.currentOrder, testOrder);
      expect(cubit.state.isUpdatingStatus, false);
    });

    // Test: acceptOrder transitions status to 'accepted'
    blocTest<OrderDetailCubit, OrderDetailState>(
      'acceptOrder updates status to accepted',
      build: () =>
          OrderDetailCubit(initialOrder: testOrder, orderApi: mockOrderApi),
      act: (cubit) async {
        when(
          () => mockOrderApi.acceptCourierOrder('token123', 1),
        ).thenAnswer((_) async => {});
        await cubit.acceptOrder('token123');
      },
      expect: () => [
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          true,
        ),
        isA<OrderDetailState>().having(
          (s) => s.currentOrder.status,
          'status',
          'accepted',
        ),
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          false,
        ),
      ],
    );

    // Test: startDelivery transitions status to 'in_transit'
    blocTest<OrderDetailCubit, OrderDetailState>(
      'startDelivery updates status to in_transit',
      build: () => OrderDetailCubit(
        initialOrder: testOrder.copyWithStatus('accepted'),
        orderApi: mockOrderApi,
      ),
      act: (cubit) async {
        when(
          () => mockOrderApi.startDelivery('token123', 1),
        ).thenAnswer((_) async => {});
        await cubit.startDelivery('token123');
      },
      expect: () => [
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          true,
        ),
        isA<OrderDetailState>().having(
          (s) => s.currentOrder.status,
          'status',
          'in_transit',
        ),
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          false,
        ),
      ],
    );

    // Test: markDelivered transitions status to 'delivered' and returns verification code
    blocTest<OrderDetailCubit, OrderDetailState>(
      'markDelivered updates status to delivered and returns verification code',
      build: () => OrderDetailCubit(
        initialOrder: testOrder.copyWithStatus('in_transit'),
        orderApi: mockOrderApi,
      ),
      act: (cubit) async {
        when(
          () => mockOrderApi.markDelivered('token123', 1),
        ).thenAnswer((_) async => 'VER12345');
        await cubit.markDelivered('token123');
      },
      expect: () => [
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          true,
        ),
        isA<OrderDetailState>()
            .having((s) => s.currentOrder.status, 'status', 'delivered')
            .having(
              (s) => s.currentOrder.verificationCode,
              'verificationCode',
              'VER12345',
            ),
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          false,
        ),
      ],
    );

    // Test: completeDelivery transitions status to 'completed'
    blocTest<OrderDetailCubit, OrderDetailState>(
      'completeDelivery updates status to completed',
      build: () => OrderDetailCubit(
        initialOrder: testOrder.copyWithStatus(
          'delivered',
          verificationCode: 'VER12345',
        ),
        orderApi: mockOrderApi,
      ),
      act: (cubit) async {
        when(
          () => mockOrderApi.completeDelivery('token123', 1, 'VER12345'),
        ).thenAnswer((_) async => {});
        await cubit.completeDelivery('token123', 'VER12345');
      },
      expect: () => [
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          true,
        ),
        isA<OrderDetailState>().having(
          (s) => s.currentOrder.status,
          'status',
          'completed',
        ),
        isA<OrderDetailState>().having(
          (s) => s.isUpdatingStatus,
          'isUpdatingStatus',
          false,
        ),
      ],
    );

    // Test: acceptOrder throws when token is null
    blocTest<OrderDetailCubit, OrderDetailState>(
      'acceptOrder throws exception when token is null',
      build: () =>
          OrderDetailCubit(initialOrder: testOrder, orderApi: mockOrderApi),
      act: (cubit) async {
        expect(() => cubit.acceptOrder(null), throwsA(isA<Exception>()));
      },
      expect: () => [],
    );

    // Test: reloadCurrentOrder updates with latest order data
    blocTest<OrderDetailCubit, OrderDetailState>(
      'reloadCurrentOrder fetches and updates current order',
      build: () =>
          OrderDetailCubit(initialOrder: testOrder, orderApi: mockOrderApi),
      act: (cubit) async {
        final updatedOrder = testOrder.copyWithStatus('accepted');
        when(
          () => mockOrderApi.getCourierOrders('token123'),
        ).thenAnswer((_) async => [updatedOrder]);
        await cubit.reloadCurrentOrder(token: 'token123', isCourier: true);
      },
      expect: () => [
        isA<OrderDetailState>().having(
          (s) => s.currentOrder.status,
          'status',
          'accepted',
        ),
      ],
    );

    // Test: reloadCurrentOrder silently fails when order not found
    blocTest<OrderDetailCubit, OrderDetailState>(
      'reloadCurrentOrder silently handles order not found',
      build: () =>
          OrderDetailCubit(initialOrder: testOrder, orderApi: mockOrderApi),
      act: (cubit) async {
        when(
          () => mockOrderApi.getCourierOrders('token123'),
        ).thenAnswer((_) async => []);
        await cubit.reloadCurrentOrder(token: 'token123', isCourier: true);
      },
      expect: () => [],
    );

    // Test: Full order lifecycle final states are correct
    blocTest<OrderDetailCubit, OrderDetailState>(
      'full order lifecycle ends with completed status',
      build: () =>
          OrderDetailCubit(initialOrder: testOrder, orderApi: mockOrderApi),
      act: (cubit) async {
        when(
          () => mockOrderApi.acceptCourierOrder('token123', 1),
        ).thenAnswer((_) async => {});
        when(
          () => mockOrderApi.startDelivery('token123', 1),
        ).thenAnswer((_) async => {});
        when(
          () => mockOrderApi.markDelivered('token123', 1),
        ).thenAnswer((_) async => 'CODE123');
        when(
          () => mockOrderApi.completeDelivery('token123', 1, 'CODE123'),
        ).thenAnswer((_) async => {});

        await cubit.acceptOrder('token123');
        await cubit.startDelivery('token123');
        await cubit.markDelivered('token123');
        await cubit.completeDelivery('token123', 'CODE123');
      },
      verify: (cubit) {
        // Verify final state
        expect(cubit.state.currentOrder.status, 'completed');
        expect(cubit.state.isUpdatingStatus, false);
      },
    );
  });
}

// Extension to help test updates on Order
extension OrderTestExtension on Order {
  Order copyWithStatus(String newStatus, {String? verificationCode}) {
    return Order(
      id: id,
      category: category,
      fromAddress: fromAddress,
      toAddress: toAddress,
      distance: distance,
      status: newStatus,
      description: description,
      estimatedPrice: estimatedPrice,
      courierName: courierName,
      courierPhone: courierPhone,
      courierId: courierId,
      createdAt: createdAt,
      verificationCode: verificationCode ?? this.verificationCode,
    );
  }
}
