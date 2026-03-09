import 'package:frontend/features/orders/data/order_model.dart';

class HomeState {
  final String selectedLocation;
  final bool isCourier;
  final bool isCourierLoading;
  final String? courierError;
  final List<Order> availableOrders;
  final Set<int> acceptingOrderIds;

  const HomeState({
    this.selectedLocation = 'адрес киргиз',
    this.isCourier = false,
    this.isCourierLoading = true,
    this.courierError,
    this.availableOrders = const [],
    this.acceptingOrderIds = const {},
  });

  HomeState copyWith({
    String? selectedLocation,
    bool? isCourier,
    bool? isCourierLoading,
    String? courierError,
    bool clearCourierError = false,
    List<Order>? availableOrders,
    Set<int>? acceptingOrderIds,
  }) {
    return HomeState(
      selectedLocation: selectedLocation ?? this.selectedLocation,
      isCourier: isCourier ?? this.isCourier,
      isCourierLoading: isCourierLoading ?? this.isCourierLoading,
      courierError: clearCourierError
          ? null
          : (courierError ?? this.courierError),
      availableOrders: availableOrders ?? this.availableOrders,
      acceptingOrderIds: acceptingOrderIds ?? this.acceptingOrderIds,
    );
  }
}
