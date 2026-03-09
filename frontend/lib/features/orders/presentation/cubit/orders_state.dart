import '../../data/order_model.dart';

class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final String? error;
  final bool isCourier;

  const OrdersState({
    this.orders = const [],
    this.isLoading = true,
    this.error,
    this.isCourier = false,
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isCourier,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isCourier: isCourier ?? this.isCourier,
    );
  }

  /// Get a single order by ID from the list
  Order? getOrderById(int id) {
    try {
      return orders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get active orders (not completed)
  List<Order> getActiveOrders() {
    return orders
        .where(
          (o) =>
              o.status != 'completed' &&
              o.status != 'cancelled' &&
              o.status != 'delivered',
        )
        .toList();
  }

  /// Get completed orders
  List<Order> getCompletedOrders() {
    return orders
        .where((o) => o.status == 'completed' || o.status == 'delivered')
        .toList();
  }
}
