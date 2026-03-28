import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../orders/data/order_api.dart';
import '../../../../core/utils/distance_calculator.dart';
import 'order_create_state.dart';

class OrderCreateCubit extends Cubit<OrderCreateState> {
  OrderCreateCubit({OrderApi? orderApi})
    : _orderApi = orderApi ?? OrderApi(),
      super(const OrderCreateState());

  final OrderApi _orderApi;

  // ── Enterprise ──────────────────────────────────────────────────────────────

  void selectEnterprise({
    required int id,
    required String name,
    required String address,
    double? lat,
    double? lon,
  }) {
    emit(state.copyWith(
      enterpriseId: id,
      enterpriseName: name,
      enterpriseAddress: address,
      enterpriseLat: lat,
      enterpriseLon: lon,
      isEnterprisePath: true,
      selectedItems: {},
    ));
  }

  void clearEnterprise() {
    emit(state.copyWith(
      clearEnterprise: true,
      selectedItems: {},
    ));
  }

  /// Jump directly to enterprise menu step (called when enterprise card is tapped).
  void goToEnterpriseMenuStep() {
    emit(state.copyWith(currentStep: OrderCreateStep.enterpriseMenu));
  }

  /// Jump directly to pickup location step (manual path, "Башка ишкана").
  void goToPickupStep() {
    emit(state.copyWith(
      currentStep: OrderCreateStep.pickupLocation,
      clearEnterprise: true,
      selectedItems: {},
    ));
  }

  // ── Item selection (enterprise menu path) ──────────────────────────────────

  void addItem(int productId) {
    final updated = Map<int, int>.from(state.selectedItems);
    updated[productId] = (updated[productId] ?? 0) + 1;
    emit(state.copyWith(selectedItems: updated));
  }

  void removeItem(int productId) {
    final updated = Map<int, int>.from(state.selectedItems);
    final current = updated[productId] ?? 0;
    if (current <= 1) {
      updated.remove(productId);
    } else {
      updated[productId] = current - 1;
    }
    emit(state.copyWith(selectedItems: updated));
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Returns error message if validation fails, null on success.
  String? goToNextStep({
    String fromAddress = '',
    String toAddress = '',
    LatLng? fromLocation,
    LatLng? toLocation,
  }) {
    switch (state.currentStep) {
      case OrderCreateStep.enterpriseSelection:
        // Enterprise cards navigate directly; this branch handles "Башка ишкана"
        emit(state.copyWith(
          currentStep: OrderCreateStep.pickupLocation,
          clearEnterprise: true,
        ));
        return null;

      case OrderCreateStep.enterpriseMenu:
        if (state.selectedItems.isEmpty) {
          return 'Жок дегенде бир товар тандаңыз';
        }
        emit(state.copyWith(currentStep: OrderCreateStep.deliveryLocation));
        return null;

      case OrderCreateStep.pickupLocation:
        if (fromAddress.trim().isEmpty) {
          return 'Жөнөтүүнүн адресин киргизиңиз';
        }
        emit(state.copyWith(currentStep: OrderCreateStep.deliveryLocation));
        return null;

      case OrderCreateStep.deliveryLocation:
        if (toAddress.trim().isEmpty) {
          return 'Жеткирүүнүн адресин киргизиңиз';
        }
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

  /// Returns true if the page should be popped.
  bool goToPreviousStep() {
    switch (state.currentStep) {
      case OrderCreateStep.enterpriseSelection:
        return true;

      case OrderCreateStep.enterpriseMenu:
        emit(state.copyWith(currentStep: OrderCreateStep.enterpriseSelection));
        return false;

      case OrderCreateStep.pickupLocation:
        emit(state.copyWith(currentStep: OrderCreateStep.enterpriseSelection));
        return false;

      case OrderCreateStep.deliveryLocation:
        if (state.isEnterprisePath) {
          emit(state.copyWith(currentStep: OrderCreateStep.enterpriseMenu));
        } else {
          emit(state.copyWith(currentStep: OrderCreateStep.pickupLocation));
        }
        return false;

      case OrderCreateStep.description:
        emit(state.copyWith(currentStep: OrderCreateStep.deliveryLocation));
        return false;
    }
  }

  // ── Distance calculation ───────────────────────────────────────────────────

  Future<void> _calculateDistanceAsync(
    String fromAddress,
    String toAddress, {
    LatLng? fromLocation,
    LatLng? toLocation,
  }) async {
    try {
      LatLng? fromCoords = fromLocation;
      LatLng? toCoords = toLocation;

      if (fromCoords != null && toCoords != null) {
        final distance = await YandexRouter.calculateDrivingDistance(
          from: fromCoords,
          to: toCoords,
        );
        if (distance != null) {
          emit(state.copyWith(calculatedDistance: distance));
          return;
        }
      }

      fromCoords ??= await RealGeocoder.getCoordinates(fromAddress);
      toCoords ??= await RealGeocoder.getCoordinates(toAddress);

      if (fromCoords != null && toCoords != null) {
        final distance = await YandexRouter.calculateDrivingDistance(
          from: fromCoords,
          to: toCoords,
        );
        if (distance != null) {
          emit(state.copyWith(calculatedDistance: distance));
          return;
        }
        final straight = DistanceCalculator.calculateDistance(
          from: fromCoords,
          to: toCoords,
        );
        emit(state.copyWith(
          calculatedDistance: (straight * 1.4).clamp(0.5, 500.0),
        ));
      }
      // If geocoding failed, leave calculatedDistance null → createOrder validates
    } catch (_) {
      // createOrder validates and shows error.
    }
  }

  // ── Order creation ─────────────────────────────────────────────────────────

  Future<void> createOrder({
    required String token,
    required String category,
    required String fromAddress,
    required String toAddress,
    required String description,
    LatLng? fromLocation,
    LatLng? toLocation,
    int? enterpriseId,
    double? itemsTotal,
  }) async {
    final normalizedFrom = fromAddress.trim();
    final normalizedTo = toAddress.trim();
    final normalizedDescription = description.trim();

    if (normalizedFrom.isEmpty || normalizedTo.isEmpty) {
      throw Exception('Жөнөтүү жана жеткирүү адрестерин толтуруңуз');
    }
    if (normalizedDescription.isEmpty) {
      throw Exception('Заказдын сыпаттамасын жазыңыз');
    }

    final distanceKm = state.calculatedDistance ?? 0;
    if (distanceKm <= 0) {
      throw Exception('Аралык туура эсептелген жок. Картадан тандап кайра аракет кылыңыз');
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
        enterpriseId: enterpriseId,
        itemsTotal: itemsTotal,
      );
    } finally {
      emit(state.copyWith(isLoading: false));
    }
  }
}
