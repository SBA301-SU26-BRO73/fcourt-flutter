import 'dart:async';

typedef PushRegister = Future<void> Function();
typedef PushUnregister = Future<void> Function();

class PushSessionCoordinator {
  PushSessionCoordinator({
    required this._register,
    required this._unregister,
    // Runs when the session ends. By then the access token is gone, so it
    // must only drop the local cache and never call the server (it would 401).
    // Explicit logout unregisters remotely beforehand (AuthRepositoryImpl
    // beforeLogout); on session expiry stale endpoints are disabled by
    // SNS/FCM once pushes to them fail.
    this._clearLocal,
  });

  final PushRegister _register;
  final PushUnregister _unregister;
  final PushUnregister? _clearLocal;
  bool _loggedIn = false;
  Future<void> _pending = Future<void>.value();

  bool get isLoggedIn => _loggedIn;

  void onAuthenticationChanged(bool authenticated) {
    if (authenticated == _loggedIn) return;
    _loggedIn = authenticated;
    _enqueue(authenticated ? _register : (_clearLocal ?? _unregister));
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
