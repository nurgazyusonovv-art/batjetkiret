class AuthState {
  final bool isInitialized;
  final bool isLogin;
  final bool isLoading;
  final String? token;
  final String? error;
  final String? success;

  const AuthState({
    this.isInitialized = false,
    this.isLogin = true,
    this.isLoading = false,
    this.token,
    this.error,
    this.success,
  });

  AuthState copyWith({
    bool? isInitialized,
    bool? isLogin,
    bool? isLoading,
    String? token,
    bool clearToken = false,
    String? error,
    bool clearError = false,
    String? success,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLogin: isLogin ?? this.isLogin,
      isLoading: isLoading ?? this.isLoading,
      token: clearToken ? null : (token ?? this.token),
      error: clearError ? null : (error ?? this.error),
      success: clearSuccess ? null : (success ?? this.success),
    );
  }
}
