import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../orders/data/order_api.dart';
import '../../../../core/utils/distance_calculator.dart';
import 'order_create_state.dart';

class OrderCreateCubit extends Cubit<OrderCreateState> {
  OrderCreateCubit({OrderApi? orderApi})
    : _orderApi = orderApi ?? OrderApi(),
      super(const OrderCreateState());

  final OrderApi _orderApi;

  String? goToNextStep({
    required String fromAddress,
    required String toAddress,
    LatLng? fromLocation,
    LatLng? toLocation,
  }) {
    switch (state.currentStep) {
      case OrderCreateStep.pickupLocation:
        if (fromAddress.trim().isEmpty) {
          return 'Адресс киргизиңиз';
        }
        emit(state.copyWith(currentStep: OrderCreateStep.deliveryLocation));
        return null;
      case OrderCreateStep.deliveryLocation:
        if (toAddress.trim().isEmpty) {
          return 'Адресс киргизиңиз';
        }

        // Use coordinates if available from map picker, otherwise use address-based geocoding
        _calculateDistanceAsync(
          fromAddress,
          toAddress,
          fromLocation: fromLocation,
          toLocation: toLocation,
        );
        emit(state.copyWith(currentStep: OrderCreateStep.description));
        return null;
      case OrderCreateStep.description:
        return null;
    }
  }

  Future<void> _calculateDistanceAsync(
    String fromAddress,
    String toAddress, {
    LatLng? fromLocation,
    LatLng? toLocation,
  }) async {
    try {
      // If coordinates are provided from map picker, use them directly
      LatLng? fromCoords = fromLocation;
      LatLng? toCoords = toLocation;

      // Debug: print coordinates
      print('🗺️ Distance calculation:');
      print('  From coords: $fromCoords');
      print('  To coords: $toCoords');

      // If coordinates available, use them
      if (fromCoords != null && toCoords != null) {
        // Use Yandex Router API to calculate driving distance
        final distance = await YandexRouter.calculateDrivingDistance(
          from: fromCoords,
          to: toCoords,
        );
        
        if (distance != null) {
          print('  ✅ Calculated driving distance: ${distance.toStringAsFixed(2)} km');
          emit(state.copyWith(calculatedDistance: distance));
          return;
        }
      }

      // Otherwise, try to geocode the addresses
      print('  ⚠️ Coordinates missing, trying to geocode addresses...');
      fromCoords ??= await RealGeocoder.getCoordinates(fromAddress);
      toCoords ??= await RealGeocoder.getCoordinates(toAddress);

      if (fromCoords != null && toCoords != null) {
        // Use Yandex Router API to calculate driving distance
        final distance = await YandexRouter.calculateDrivingDistance(
          from: fromCoords,
          to: toCoords,
        );
        
        if (distance != null) {
          print('  ✅ Geocoded and calculated driving distance: ${distance.toStringAsFixed(2)} km');
          emit(state.copyWith(calculatedDistance: distance));
          return;
        }
      } else {
        // Fallback: simple estimation if coordinates not found
        print('  ❌ Geocoding failed, using fallback estimation');
        final avgLength = (fromAddress.length + toAddress.length) / 2;
        final estimatedDistance = (avgLength / 10).clamp(1.0, 100.0);
        emit(state.copyWith(calculatedDistance: estimatedDistance));
      }
    } catch (e) {
      // Use default estimate on error
      print('  ❌ Distance calculation error: $e');
      emit(state.copyWith(calculatedDistance: 10.0));
    }
  }

  bool goToPreviousStep() {
    if (state.currentStep == OrderCreateStep.pickupLocation) {
      return true;
    }

    switch (state.currentStep) {
      case OrderCreateStep.pickupLocation:
        return true;
      case OrderCreateStep.deliveryLocation:
        emit(state.copyWith(currentStep: OrderCreateStep.pickupLocation));
        return false;
      case OrderCreateStep.description:
        emit(state.copyWith(currentStep: OrderCreateStep.deliveryLocation));
        return false;
    }
  }

  Future<void> createOrder({
    required String token,
    required String category,
    required String fromAddress,
    required String toAddress,
    required String description,
    LatLng? fromLocation,
    LatLng? toLocation,
  }) async {
    final normalizedFrom = fromAddress.trim();
    final normalizedTo = toAddress.trim();
    final normalizedDescription = description.trim();

    if (normalizedFrom.isEmpty ||
        normalizedTo.isEmpty ||
        normalizedDescription.isEmpty) {
      throw Exception('Бардык талаалар толтурулушу керек');
    }

    final distanceKm = state.calculatedDistance ?? 0;
    if (distanceKm <= 0) {
      throw Exception('Аралык туура эсептелген жок');
    }

    emit(state.copyWith(isLoading: true));
    try {
      await _orderApi.createOrder(
        token: token,
        category: category,
        description: normalizedDescription,
        fromAddress: normalizedFrom,
        toAddress: normalizedTo,
        fromLatitude: fromLocation?.latitude,
        fromLongitude: fromLocation?.longitude,
        toLatitude: toLocation?.latitude,
        toLongitude: toLocation?.longitude,
        distanceKm: distanceKm,
      );
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}

  // Calculate distance using RealGeocoder (Yandex API) with MockGeocoder fallback
  // Use RealGeocoder with fallback to MockGeocoder if API key not set
  //final fromCoords = await RealGeocoder.getCoordinates(fromAddress);
  //final toCoords = await RealGeocoder.getCoordinates(toAddress);
