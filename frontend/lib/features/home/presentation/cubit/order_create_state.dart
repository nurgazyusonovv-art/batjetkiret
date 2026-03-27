enum OrderCreateStep {
  enterpriseSelection, // Show list of enterprises in category
  enterpriseMenu,      // Show enterprise product menu
  pickupLocation,      // Manual path: enter from address + map
  deliveryLocation,    // Enter delivery address + map (both paths)
  description,         // Summary + description / notes
}

class OrderCreateState {
  final OrderCreateStep currentStep;
  final bool isLoading;
  final double? calculatedDistance;

  // Enterprise selection
  final int? enterpriseId;
  final String? enterpriseName;
  final String? enterpriseAddress;
  final double? enterpriseLat;
  final double? enterpriseLon;

  // Whether user chose an enterprise (true) or manual entry (false)
  final bool isEnterprisePath;

  // Selected menu items: product_id → quantity
  final Map<int, int> selectedItems;

  const OrderCreateState({
    this.currentStep = OrderCreateStep.enterpriseSelection,
    this.isLoading = false,
    this.calculatedDistance,
    this.enterpriseId,
    this.enterpriseName,
    this.enterpriseAddress,
    this.enterpriseLat,
    this.enterpriseLon,
    this.isEnterprisePath = false,
    this.selectedItems = const {},
  });

  int get totalItemCount =>
      selectedItems.values.fold(0, (sum, qty) => sum + qty);

  OrderCreateState copyWith({
    OrderCreateStep? currentStep,
    bool? isLoading,
    double? calculatedDistance,
    bool clearCalculatedDistance = false,
    int? enterpriseId,
    String? enterpriseName,
    String? enterpriseAddress,
    double? enterpriseLat,
    double? enterpriseLon,
    bool clearEnterprise = false,
    bool? isEnterprisePath,
    Map<int, int>? selectedItems,
  }) {
    return OrderCreateState(
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      calculatedDistance: clearCalculatedDistance
          ? null
          : (calculatedDistance ?? this.calculatedDistance),
      enterpriseId: clearEnterprise ? null : (enterpriseId ?? this.enterpriseId),
      enterpriseName: clearEnterprise ? null : (enterpriseName ?? this.enterpriseName),
      enterpriseAddress: clearEnterprise ? null : (enterpriseAddress ?? this.enterpriseAddress),
      enterpriseLat: clearEnterprise ? null : (enterpriseLat ?? this.enterpriseLat),
      enterpriseLon: clearEnterprise ? null : (enterpriseLon ?? this.enterpriseLon),
      isEnterprisePath: clearEnterprise ? false : (isEnterprisePath ?? this.isEnterprisePath),
      selectedItems: selectedItems ?? this.selectedItems,
    );
  }
}
