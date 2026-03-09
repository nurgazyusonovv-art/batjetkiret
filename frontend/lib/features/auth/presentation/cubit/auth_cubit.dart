import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/token_storage.dart';
import '../../data/auth_api.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthApi? authApi})
    : _authApi = authApi ?? AuthApi(),
      super(const AuthState());

  final AuthApi _authApi;

  Future<void> bootstrap() async {
    final token = await TokenStorage.getToken();
    emit(
      state.copyWith(
        isInitialized: true,
        token: (token != null && token.isNotEmpty) ? token : null,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  void toggleMode(bool isLogin) {
    emit(
      state.copyWith(
        isLogin: isLogin,
        clearError: true,
        clearSuccess: true,
        token: null,
      ),
    );
  }

  Future<void> submit({
    required String phone,
    required String password,
    String? name,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));

    try {
      final token = state.isLogin
          ? await _authApi.login(phone: phone, password: password)
          : await _authApi.register(
              phone: phone,
              name: (name ?? '').trim(),
              password: password,
            );

      await TokenStorage.saveToken(token);

      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          token: token,
          success: state.isLogin
              ? 'Ийгиликтүү кирдиңиз'
              : 'Каттоо ийгиликтүү аяктады',
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isInitialized: true,
          isLoading: false,
          error: error.toString().replaceFirst('Exception: ', ''),
          clearSuccess: true,
        ),
      );
    }
  }

  Future<void> logout() async {
    await TokenStorage.clearToken();
    emit(
      state.copyWith(
        isInitialized: true,
        clearToken: true,
        clearError: true,
        clearSuccess: true,
      ),
    );
  }

  Future<String> forgotPassword(String phone) {
    return _authApi.forgotPassword(phone: phone);
  }
}
