import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/order_api.dart';
import '../../data/order_model.dart';
import 'order_detail_state.dart';

class OrderDetailCubit extends Cubit<OrderDetailState> {
  OrderDetailCubit({required Order initialOrder, OrderApi? orderApi})
    : _orderApi = orderApi ?? OrderApi(),
      super(OrderDetailState(currentOrder: initialOrder));

  final OrderApi _orderApi;

  Future<void> reloadCurrentOrder({
    required String? token,
    required bool isCourier,
  }) async {
    if (token == null) return;

    emit(state.copyWith(isReloading: true, clearError: true));
    try {
      final orders = isCourier
          ? await _orderApi.getCourierOrders(token)
          : await _orderApi.getMyOrders(token);

      final latestOrder = orders
          .where((order) => order.id == state.currentOrder.id)
          .firstOrNull;

      if (latestOrder == null) {
        emit(state.copyWith(isReloading: false, error: 'Заказ табылган жок'));
        return;
      }

      emit(state.copyWith(currentOrder: latestOrder, isReloading: false));
    } catch (error) {
      emit(
        state.copyWith(
          isReloading: false,
          error: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> acceptOrder(String? token) async {
    await _updateOrderStatus(token, 'accept');
  }

  Future<void> startDelivery(String? token) async {
    await _updateOrderStatus(token, 'start');
  }

  Future<String> markDelivered(String? token) async {
    if (token == null) {
      throw Exception('Сессия бүттү. Кайра кириңиз.');
    }

    emit(state.copyWith(isUpdatingStatus: true));
    try {
      final verificationCode = await _orderApi.markDelivered(
        token,
        state.currentOrder.id,
      );

      _updateLocalOrderStatus('delivered', verificationCode: verificationCode);
      return verificationCode;
    } finally {
      emit(state.copyWith(isUpdatingStatus: false));
    }
  }

  Future<void> completeDelivery(String? token, String verificationCode) async {
    if (token == null) {
      throw Exception('Сессия бүттү. Кайра кириңиз.');
    }

    emit(state.copyWith(isUpdatingStatus: true));
    try {
      await _orderApi.completeDelivery(
        token,
        state.currentOrder.id,
        verificationCode,
      );
      _updateLocalOrderStatus('complete');
    } finally {
      emit(state.copyWith(isUpdatingStatus: false));
    }
  }

  Future<void> _updateOrderStatus(String? token, String action) async {
    if (token == null) {
      emit(state.copyWith(error: 'Сессия бүттү. Кайра кириңиз.'));
      return;
    }

    emit(state.copyWith(isUpdatingStatus: true, clearError: true));
    try {
      switch (action) {
        case 'accept':
          await _orderApi.acceptCourierOrder(token, state.currentOrder.id);
          break;
        case 'start':
          await _orderApi.startDelivery(token, state.currentOrder.id);
          break;
      }

      _updateLocalOrderStatus(action);
    } catch (error) {
      emit(
        state.copyWith(
          isUpdatingStatus: false,
          error: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return;
    }
    emit(state.copyWith(isUpdatingStatus: false));
  }

  void _updateLocalOrderStatus(String action, {String? verificationCode}) {
    final current = state.currentOrder;
    final updatedOrder = switch (action) {
      'accept' => current.copyWith(status: 'accepted'),
      'start' => current.copyWith(status: 'in_transit'),
      'complete' => current.copyWith(
        status: 'completed',
        verificationCode: null,
      ),
      'delivered' => current.copyWith(
        status: 'delivered',
        verificationCode: verificationCode ?? current.verificationCode,
      ),
      'cancel_user' => current.copyWith(status: 'cancelled'),
      'cancel_courier' => current.copyWith(status: 'pending'),
      _ => current,
    };

    emit(state.copyWith(currentOrder: updatedOrder, clearError: true));
  }

  // Колдонуучу заказды жокко чыгаруу
  Future<void> cancelOrder(String? token) async {
    if (token == null) {
      emit(state.copyWith(error: 'Сессия бүттү. Кайра кириңиз.'));
      return;
    }

    emit(state.copyWith(isUpdatingStatus: true, clearError: true));
    try {
      await _orderApi.cancelOrder(token, state.currentOrder.id);
      _updateLocalOrderStatus('cancel_user');
    } catch (error) {
      emit(
        state.copyWith(
          isUpdatingStatus: false,
          error: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return;
    }
    emit(state.copyWith(isUpdatingStatus: false));
  }

  // Колдонуучу курьер жолдо болгон заказга жокко чыгаруу суроосун жөнөтүү
  Future<void> requestCancelOrder(String? token, {String reason = ''}) async {
    if (token == null) {
      emit(state.copyWith(error: 'Сессия бүттү. Кайра кириңиз.'));
      return;
    }
    emit(state.copyWith(isUpdatingStatus: true, clearError: true));
    try {
      await _orderApi.requestCancelOrder(token, state.currentOrder.id, reason: reason);
      // Mark cancel_requested locally so the button changes to "waiting" state
      final updated = state.currentOrder.copyWith(cancelRequested: true);
      emit(state.copyWith(isUpdatingStatus: false, currentOrder: updated));
    } catch (error) {
      emit(state.copyWith(
        isUpdatingStatus: false,
        error: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  // Курьер заказдан баш тартуу
  Future<void> cancelCourierOrder(String? token) async {
    if (token == null) {
      emit(state.copyWith(error: 'Сессия бүттү. Кайра кириңиз.'));
      return;
    }

    emit(state.copyWith(isUpdatingStatus: true, clearError: true));
    try {
      await _orderApi.cancelCourierOrder(token, state.currentOrder.id);
      _updateLocalOrderStatus('cancel_courier');
    } catch (error) {
      emit(
        state.copyWith(
          isUpdatingStatus: false,
          error: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
      return;
    }
    emit(state.copyWith(isUpdatingStatus: false));
  }
}
