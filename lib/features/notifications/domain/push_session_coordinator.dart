import 'dart:async';

typedef PushRegister = Future<void> Function();
typedef PushUnregister = Future<void> Function();

class PushSessionCoordinator {
  PushSessionCoordinator({
    required PushRegister register,
    required PushUnregister unregister,
  }) : _register = register,
       _unregister = unregister;

  final PushRegister _register;
  final PushUnregister _unregister;
  bool _loggedIn = false;
  Future<void> _pending = Future<void>.value();

  bool get isLoggedIn => _loggedIn;

  void onAuthenticationChanged(bool authenticated) {
    if (authenticated == _loggedIn) return;
    _loggedIn = authenticated;
    _enqueue(authenticated ? _register : _unregister);
  }

  void onTokenRefresh() {
    if (_loggedIn) _enqueue(_register);
  }

  Future<void> get settled => _pending;

  void _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) async {
      try {
        await action();
      } catch (_) {
        // Lỗi đăng ký push không được ảnh hưởng tới phiên đăng nhập.
      }
    });
  }
}
