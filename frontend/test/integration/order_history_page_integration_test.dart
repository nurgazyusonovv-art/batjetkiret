import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/orders/data/order_model.dart';
import 'package:frontend/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:frontend/features/orders/presentation/cubit/orders_state.dart';
import 'package:frontend/features/orders/presentation/order_history_page.dart';

class MockOrdersCubit extends MockCubit<OrdersState> implements OrdersCubit {}

void main() {
  group('OrderHistoryPage integration', () {
    late MockOrdersCubit ordersCubit;

    setUp(() {
      ordersCubit = MockOrdersCubit();
    });

    testWidgets('search input filters rendered order history list', (
      tester,
    ) async {
      final state = OrdersState(
        isLoading: false,
        isCourier: false,
        orders: [
          Order(
            id: 101,
            category: 'food',
            fromAddress: 'Bishkek A',
            toAddress: 'Bishkek B',
            distance: 3,
            status: 'completed',
            description: 'Food order',
            estimatedPrice: 250,
            createdAt: DateTime.now().toIso8601String(),
          ),
          Order(
            id: 202,
            category: 'groceries',
            fromAddress: 'Osh A',
            toAddress: 'Osh B',
            distance: 5,
            status: 'completed',
            description: 'Groceries order',
            estimatedPrice: 350,
            createdAt: DateTime.now().toIso8601String(),
          ),
        ],
      );

      when(() => ordersCubit.state).thenReturn(state);
      whenListen(
        ordersCubit,
        Stream<OrdersState>.value(state),
        initialState: state,
      );
      when(
        () => ordersCubit.loadOrders(any(), silent: any(named: 'silent')),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OrdersCubit>.value(
            value: ordersCubit,
            child: const OrderHistoryPage(token: 'token'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#101'), findsOneWidget);
      expect(find.text('#202'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '101');
      await tester.pumpAndSettle();

      expect(find.text('#101'), findsOneWidget);
      expect(find.text('#202'), findsNothing);
    });
  });
}
