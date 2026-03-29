import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/user_api.dart';
import '../../../orders/data/order_api.dart';
import 'profile_state.dart';
import '../../../../core/storage/hive_service.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({UserApi? userApi, OrderApi? orderApi})
    : _userApi = userApi ?? UserApi(),
      _orderApi = orderApi ?? OrderApi(),
      super(const ProfileState());

  final UserApi _userApi;
  final OrderApi _orderApi;
  String? _activeToken;

  Future<void> hydrateOnAuth(String? token) async {
    final normalizedToken = token?.trim();

    if (normalizedToken == null || normalizedToken.isEmpty) {
      clear();
      return;
    }

    if (_activeToken == normalizedToken && state.user != null) {
      return;
    }

    _activeToken = normalizedToken;
    await loadUser(normalizedToken);
  }

  void clear() {
    _activeToken = null;
    emit(const ProfileState(isLoading: false));
  }

  Future<void> loadUser(String token, {bool silent = false}) async {
    if (!silent || state.user == null) {
      emit(state.copyWith(isLoading: true, clearError: true));
    } else {
      emit(state.copyWith(clearError: true));
    }

    try {
      final user = await _userApi.getMe(token);
      final ratingData = user.isCourier
          ? await _userApi.getCourierRating(token)
          : await _userApi.getUserRating(token);
      final unreadNotifications = await _userApi.getUnreadNotificationsCount(
        token,
      );

      final averageRating = (ratingData['average_rating'] is num)
          ? (ratingData['average_rating'] as num).toDouble()
          : 0.0;

      final totalReviews = (ratingData['total_reviews'] is num)
          ? (ratingData['total_reviews'] as num).toInt()
          : 0;

      emit(
        state.copyWith(
          user: user,
          isLoading: false,
          clearError: true,
          ratingAverage: averageRating,
          ratingTotalReviews: totalReviews,
          unreadNotifications: unreadNotifications,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: error.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> becomeCourier(String token) async {
    await _userApi.becomeCourier(token);
    await loadUser(token);
  }

  Future<void> removeCourier(String token) async {
    await _userApi.removeCourier(token);
    await loadUser(token);
  }

  Future<void> updateProfile(
    String token, {
    String? name,
    String? phone,
    String? address,
  }) async {
    await _userApi.updateProfile(
      token,
      name: name,
      phone: phone,
      address: address,
    );
    await loadUser(token);
  }

  Future<void> toggleOnlineStatus(String token, bool isOnline) async {
    // Update backend first; only persist locally if it succeeds.
    await _userApi.updateProfile(token, isOnline: isOnline);
    await HiveService.saveCourierOnlineStatus(isOnline);
    await loadUser(token, silent: true);
  }

  Future<void> loadCourierStats(String token, {bool silent = false}) async {
    if (!silent || state.courierStats == null) {
      emit(state.copyWith(isCourierStatsLoading: true, clearCourierStatsError: true));
    }

    try {
      final stats = await _orderApi.getCourierStats(token);
      emit(
        state.copyWith(
          courierStats: stats,
          isCourierStatsLoading: false,
          courierStatsUpdatedAt: DateTime.now(),
          clearCourierStatsError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isCourierStatsLoading: false,
          courierStatsError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> topupBalance(String token, double amount) async {
    await _userApi.topupBalance(token, amount);
    await loadUser(token, silent: true);

    // Reload courier stats if user is courier
    if (state.user?.isCourier == true) {
      await loadCourierStats(token);
    }
  }
}
