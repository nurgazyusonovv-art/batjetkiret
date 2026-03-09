enum OrderCreateStep { pickupLocation, deliveryLocation, description }

class OrderCreateState {
  final OrderCreateStep currentStep;
  final bool isLoading;
  final double? calculatedDistance;

  const OrderCreateState({
    this.currentStep = OrderCreateStep.pickupLocation,
    this.isLoading = false,
    this.calculatedDistance,
  });

  OrderCreateState copyWith({
    OrderCreateStep? currentStep,
    bool? isLoading,
    double? calculatedDistance,
    bool clearCalculatedDistance = false,
  }) {
    return OrderCreateState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      calculatedDistance: clearCalculatedDistance
          ? null
          : (calculatedDistance ?? this.calculatedDistance),
    );
  }
}
