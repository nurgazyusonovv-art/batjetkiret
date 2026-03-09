import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/orders/data/order_api.dart';
import 'package:frontend/features/home/presentation/cubit/order_create_cubit.dart';
import 'package:frontend/features/home/presentation/cubit/order_create_state.dart';

// Mock OrderApi
class MockOrderApi extends Mock implements OrderApi {}

void main() {
  group('OrderCreateCubit', () {
    late MockOrderApi mockOrderApi;

    setUp(() {
      mockOrderApi = MockOrderApi();
    });

    // Test: Initial state verification
    test('emits initial state with pickupLocation step', () {
      final cubit = OrderCreateCubit(orderApi: mockOrderApi);

      expect(cubit.state.currentStep, OrderCreateStep.pickupLocation);
      expect(cubit.state.isLoading, false);
      expect(cubit.state.calculatedDistance, null);
    });

    // Test: goToNextStep validates empty pickup location
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToNextStep returns error for empty pickup location',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) async {
        final error = cubit.goToNextStep(
          fromAddress: '   ',
          toAddress: 'Улица 2',
        );
        expect(error, 'Адресс киргизиңиз');
      },
    );

    // Test: goToNextStep transitions from pickupLocation to deliveryLocation
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToNextStep transitions from pickupLocation to deliveryLocation',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');
      },
      expect: () => [
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.deliveryLocation,
        ),
      ],
    );

    // Test: goToNextStep validates empty delivery location
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToNextStep returns error for empty delivery location',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) async {
        // Move to deliveryLocation first
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');

        // Try to move to description with empty toAddress
        final error = cubit.goToNextStep(
          fromAddress: 'Улица 1',
          toAddress: '   ',
        );
        expect(error, 'Адресс киргизиңиз');
      },
    );

    // Test: goToNextStep calculates distance correctly from pickupLocation to deliveryLocation
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToNextStep calculates distance when moving to description step',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) async {
        // Move to deliveryLocation
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');

        // Move to description (calculates distance)
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');
      },
      expect: () => [
        // Transition to deliveryLocation
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.deliveryLocation,
        ),
        // Transition to description with calculated distance
        isA<OrderCreateState>()
            .having(
              (s) => s.currentStep,
              'currentStep',
              OrderCreateStep.description,
            )
            .having(
              (s) => s.calculatedDistance,
              'calculatedDistance',
              greaterThan(0.0),
            ),
      ],
    );

    // Test: goToNextStep distance calculation (address length based)
    test('goToNextStep calculates distance based on address lengths', () {
      final cubit = OrderCreateCubit(orderApi: mockOrderApi);

      cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');
      cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');

      // Just verify distance is calculated and positive
      expect(cubit.state.calculatedDistance, isNotNull);
      expect(cubit.state.calculatedDistance, greaterThan(0.0));
    });

    // Test: goToPreviousStep returns true when at pickupLocation (should pop)
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToPreviousStep returns true when at pickup location',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) async {
        final shouldPop = cubit.goToPreviousStep();
        expect(shouldPop, true);
      },
    );

    // Test: goToPreviousStep transitions from deliveryLocation to pickupLocation
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToPreviousStep transitions from deliveryLocation to pickupLocation',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        // Move forward to deliveryLocation
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');

        // Go back
        cubit.goToPreviousStep();
      },
      expect: () => [
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.deliveryLocation,
        ),
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.pickupLocation,
        ),
      ],
    );

    // Test: goToPreviousStep transitions from description to deliveryLocation
    blocTest<OrderCreateCubit, OrderCreateState>(
      'goToPreviousStep transitions from description to deliveryLocation',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        // Move to deliveryLocation
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');

        // Move to description
        cubit.goToNextStep(fromAddress: 'Улица 1', toAddress: 'Улица 2');

        // Go back
        cubit.goToPreviousStep();
      },
      expect: () => [
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.deliveryLocation,
        ),
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.description,
        ),
        isA<OrderCreateState>().having(
          (s) => s.currentStep,
          'currentStep',
          OrderCreateStep.deliveryLocation,
        ),
      ],
    );

    // Test: createOrder validates all required fields
    blocTest<OrderCreateCubit, OrderCreateState>(
      'createOrder throws when any field is empty',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        // Set distance so it's valid
        cubit.emit(cubit.state.copyWith(calculatedDistance: 1.5));

        expect(
          () => cubit.createOrder(
            token: 'token123',
            category: 'food',
            fromAddress: '   ',
            toAddress: 'Улица 2',
            description: 'Описание',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    // Test: createOrder validates distance is calculated
    blocTest<OrderCreateCubit, OrderCreateState>(
      'createOrder throws when distance is not calculated (empty)',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        expect(
          () => cubit.createOrder(
            token: 'token123',
            category: 'food',
            fromAddress: 'Улица 1',
            toAddress: 'Улица 2',
            description: 'Описание',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    // Test: createOrder validates distance is positive
    blocTest<OrderCreateCubit, OrderCreateState>(
      'createOrder throws when distance is zero or negative',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        cubit.emit(cubit.state.copyWith(calculatedDistance: 0.0));

        expect(
          () => cubit.createOrder(
            token: 'token123',
            category: 'food',
            fromAddress: 'Улица 1',
            toAddress: 'Улица 2',
            description: 'Описание',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    // Test: createOrder successfully creates order with valid inputs
    blocTest<OrderCreateCubit, OrderCreateState>(
      'createOrder successfully creates order with valid inputs',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      seed: () => const OrderCreateState(calculatedDistance: 2.5),
      act: (cubit) async {
        when(
          () => mockOrderApi.createOrder(
            token: 'token123',
            category: 'food',
            description: 'Тестовое описание',
            fromAddress: 'Улица 1',
            toAddress: 'Улица 2',
            distanceKm: 2.5,
          ),
        ).thenAnswer((_) async => {});

        await cubit.createOrder(
          token: 'token123',
          category: 'food',
          fromAddress: 'Улица 1',
          toAddress: 'Улица 2',
          description: 'Тестовое описание',
        );
      },
      expect: () => [
        isA<OrderCreateState>().having((s) => s.isLoading, 'isLoading', true),
        isA<OrderCreateState>().having((s) => s.isLoading, 'isLoading', false),
      ],
    );

    // Test: createOrder trims whitespace from all fields
    blocTest<OrderCreateCubit, OrderCreateState>(
      'createOrder trims whitespace from input fields',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      seed: () => const OrderCreateState(calculatedDistance: 1.5),
      act: (cubit) async {
        when(
          () => mockOrderApi.createOrder(
            token: 'token123',
            category: 'food',
            description: 'Описание',
            fromAddress: 'Улица 1',
            toAddress: 'Улица 2',
            distanceKm: 1.5,
          ),
        ).thenAnswer((_) async => {});

        await cubit.createOrder(
          token: 'token123',
          category: 'food',
          fromAddress: '  Улица 1  ',
          toAddress: '  Улица 2  ',
          description: '  Описание  ',
        );
      },
      expect: () => [
        isA<OrderCreateState>().having((s) => s.isLoading, 'isLoading', true),
        isA<OrderCreateState>().having((s) => s.isLoading, 'isLoading', false),
      ],
    );

    // Test: Full wizard flow (step 1 -> step 2 -> step 3)
    blocTest<OrderCreateCubit, OrderCreateState>(
      'full step wizard flow works correctly',
      build: () => OrderCreateCubit(orderApi: mockOrderApi),
      act: (cubit) {
        // Step 1: Pickup location
        expect(cubit.state.currentStep, OrderCreateStep.pickupLocation);

        // Move to delivery location
        final error1 = cubit.goToNextStep(
          fromAddress: 'Булгун сокак, 101',
          toAddress: 'Байтик Баатыр, 15',
        );
        expect(error1, null);
        expect(cubit.state.currentStep, OrderCreateStep.deliveryLocation);

        // Move to description (calculates distance)
        final error2 = cubit.goToNextStep(
          fromAddress: 'Булгун сокак, 101',
          toAddress: 'Байтик Баатыр, 15',
        );
        expect(error2, null);
        expect(cubit.state.currentStep, OrderCreateStep.description);
        expect(cubit.state.calculatedDistance, greaterThan(0.0));
      },
    );
  });
}
