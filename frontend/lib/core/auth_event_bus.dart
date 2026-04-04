import 'dart:async';

/// Thrown by API methods after firing [AuthEventBus.fireUnauthorized].
/// Cubits catch this silently — no error message is shown to the user
/// because the redirect to login already handles the situation.
class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

/// Fires an event when any API call receives 401/403 (invalid/expired token).
/// main.dart listens and calls AuthCubit.logout() → redirects to login.
class AuthEventBus {
  AuthEventBus._();
  static final AuthEventBus instance = AuthEventBus._();

  final _controller = StreamController<void>.broadcast();

  Stream<void> get onUnauthorized => _controller.stream;

  void fireUnauthorized() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
