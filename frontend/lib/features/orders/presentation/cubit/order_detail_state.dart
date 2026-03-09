import '../../data/order_model.dart';

class OrderDetailState {
  final Order currentOrder;
  final bool isUpdatingStatus;
  final bool isReloading;
  final String? error;

  const OrderDetailState({
    required this.currentOrder,
    this.isUpdatingStatus = false,
    this.isReloading = false,
    this.error,
  });

  OrderDetailState copyWith({
    Order? currentOrder,
    bool? isUpdatingStatus,
    bool? isReloading,
    String? error,
    bool clearError = false,
  }) {
    return OrderDetailState(
      currentOrder: currentOrder ?? this.currentOrder,
      isUpdatingStatus: isUpdatingStatus ?? this.isUpdatingStatus,
      isReloading: isReloading ?? this.isReloading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
