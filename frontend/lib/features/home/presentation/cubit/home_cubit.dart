import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../orders/data/order_api.dart';
import '../../../orders/data/order_model.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/auth_event_bus.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({OrderApi? orderApi})
    : _orderApi = orderApi ?? OrderApi(),
      super(const HomeState());

  final OrderApi _orderApi;
  String? _activeToken;

  Future<void> hydrateOnAuth(String? token) async {
    final normalizedToken = token?.trim();

    if (normalizedToken == null || normalizedToken.isEmpty) {
      clear();
      return;
    }

    if (_activeToken == normalizedToken && state.availableOrders.isNotEmpty) {
      return;
    }

    _activeToken = normalizedToken;
    await _loadSavedLocation();
    await loadCourierHomeData(normalizedToken);
  }

  void clear() {
    _activeToken = null;
    emit(const HomeState(isCourierLoading: false));
  }

  Future<void> updateLocation(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_address', address);

    emit(state.copyWith(selectedLocation: address));
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('user_address');
    if (savedLocation != null && savedLocation.isNotEmpty) {
      emit(state.copyWith(selectedLocation: savedLocation));
    }
  }

  Future<void> loadCourierHomeData(String token, {bool silent = false}) async {
    if (!silent || state.availableOrders.isEmpty) {
      emit(state.copyWith(isCourierLoading: true, clearCourierError: true));
    } else {
      emit(state.copyWith(clearCourierError: true));
    }

    try {
      final isCourier = await _orderApi.isCourier(token);
      List<Order> availableOrders = [];

      // Load courier's online status from Hive
      final isOnline = HiveService.getCourierOnlineStatus();

      // Only fetch available orders if courier is online
      if (isCourier && isOnline) {
        availableOrders = await _orderApi.getAvailableCourierOrders(token);
      }

      emit(
        state.copyWith(
          isCourier: isCourier,
          availableOrders: availableOrders,
          isCourierLoading: false,
          clearCourierError: true,
        ),
      );
    } on UnauthorizedException {
      emit(state.copyWith(isCourierLoading: false, clearCourierError: true));
    } catch (error) {
      emit(
        state.copyWith(
          isCourierLoading: false,
          courierError: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> acceptOrder(String token, int orderId) async {
    final accepting = Set<int>.from(state.acceptingOrderIds)..add(orderId);
    emit(state.copyWith(acceptingOrderIds: accepting));

    try {
      await _orderApi.acceptCourierOrder(token, orderId);
      await loadCourierHomeData(token);
    } finally {
      final next = Set<int>.from(state.acceptingOrderIds)..remove(orderId);
      emit(state.copyWith(acceptingOrderIds: next));
    }
  }

  /// Refresh available orders based on current online status
  Future<void> refreshAvailableOrders(String token) async {
    final isOnline = HiveService.getCourierOnlineStatus();

    try {
      if (state.isCourier && isOnline) {
        final availableOrders = await _orderApi.getAvailableCourierOrders(
          token,
        );
        emit(state.copyWith(availableOrders: availableOrders));
      } else {
        // Clear orders if offline
        emit(state.copyWith(availableOrders: []));
      }
    } catch (error) {
      // Silently fail, don't update error state
    }
  }
}
