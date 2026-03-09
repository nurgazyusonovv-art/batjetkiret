import '../../data/user_model.dart';

class ProfileState {
  final User? user;
  final bool isLoading;
  final String? error;
  final double ratingAverage;
  final int ratingTotalReviews;
  final int unreadNotifications;
  final Map<String, dynamic>? courierStats;
  final bool isCourierStatsLoading;
  final DateTime? courierStatsUpdatedAt;

  const ProfileState({
    this.user,
    this.isLoading = true,
    this.error,
    this.ratingAverage = 0,
    this.ratingTotalReviews = 0,
    this.unreadNotifications = 0,
    this.courierStats,
    this.isCourierStatsLoading = false,
    this.courierStatsUpdatedAt,
  });

  ProfileState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
    double? ratingAverage,
    int? ratingTotalReviews,
    int? unreadNotifications,
    Map<String, dynamic>? courierStats,
    bool? isCourierStatsLoading,
    DateTime? courierStatsUpdatedAt,
  }) {
    return ProfileState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingTotalReviews: ratingTotalReviews ?? this.ratingTotalReviews,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      courierStats: courierStats ?? this.courierStats,
      isCourierStatsLoading:
          isCourierStatsLoading ?? this.isCourierStatsLoading,
      courierStatsUpdatedAt:
          courierStatsUpdatedAt ?? this.courierStatsUpdatedAt,
    );
  }
}
