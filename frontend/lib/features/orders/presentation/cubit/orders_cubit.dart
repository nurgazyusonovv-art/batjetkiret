import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/order_api.dart';
import '../../data/order_model.dart';
import 'orders_state.dart';
import '../../../../core/auth_event_bus.dart';

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({OrderApi? orderApi})
    : _orderApi = orderApi ?? OrderApi(),
      super(const OrdersState());

  final OrderApi _orderApi;

  String? _activeToken;

  void clear() {
    _activeToken = null;
    emit(const OrdersState(isLoading: false));
  }

  Future<void> hydrateOnAuth(String? token) async {
    final normalizedToken = token?.trim();

    if (normalizedToken == null || normalizedToken.isEmpty) {
      clear();
      return;
    }

    if (_activeToken == normalizedToken && state.orders.isNotEmpty) {
      return;
    }

    _activeToken = normalizedToken;
    await loadOrders(normalizedToken);
  }

  Future<void> loadOrders(String token, {bool silent = false}) async {
    if (!silent || state.orders.isEmpty) {
      emit(state.copyWith(isLoading: true, clearError: true));
    } else {
      emit(state.copyWith(clearError: true));
    }

    try {
      final isCourier = await _orderApi.isCourier(token);
      final orders = isCourier
          ? await _orderApi.getCourierOrders(token)
          : await _orderApi.getMyOrders(token);

      emit(
        state.copyWith(
          isLoading: false,
          isCourier: isCourier,
          orders: orders,
          clearError: true,
        ),
      );
    } on UnauthorizedException {
      emit(state.copyWith(isLoading: false, clearError: true));
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Update a single order in the list (used after operations on an order)
  void updateOrder(Order updatedOrder) {
    final updatedOrders = state.orders.map((order) {
      return order.id == updatedOrder.id ? updatedOrder : order;
    }).toList();

    emit(state.copyWith(orders: updatedOrders, clearError: true));
  }

  /// Remove an order from the list (used if order is deleted)
  void removeOrder(int orderId) {
    final filteredOrders = state.orders
        .where((order) => order.id != orderId)
        .toList();

    emit(state.copyWith(orders: filteredOrders, clearError: true));
  }

  /// Apply live status updates received via WebSocket.
  void applyRealtimeOrderStatuses(Map<int, String> statusByOrderId) {
    if (statusByOrderId.isEmpty) return;

    final updatedOrders = state.orders.map((order) {
      final nextStatus = statusByOrderId[order.id];
      if (nextStatus == null || nextStatus == order.status) {
        return order;
      }
      return order.copyWith(status: nextStatus);
    }).toList();

    emit(state.copyWith(orders: updatedOrders, clearError: true));
  }
}
