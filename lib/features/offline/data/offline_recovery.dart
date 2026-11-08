import 'dart:async';

/// Foreground recovery. Native background scheduling remains a backstop.
class OfflineRecovery {
  OfflineRecovery({
    required this.flush,
    required this.shiftSync,
    this.refreshInterval = const Duration(minutes: 5),
    this.retryInterval = const Duration(seconds: 30),
    this.drainInterval = const Duration(seconds: 2),
  });
  final Future<void> Function() flush;
  final Future<bool> Function() shiftSync;
  final Duration refreshInterval, retryInterval, drainInterval;
  Timer? _refresh, _retry, _drain;
  bool _active = false, _running = false, _disposed = false;

  void resume() {
    if (_disposed) return;
    _active = true;
    _refresh ??= Timer.periodic(refreshInterval, (_) => unawaited(recover()));
    _drain ??= Timer.periodic(drainInterval, (_) => unawaited(_flush()));
    unawaited(recover());
  }

  Future<void> _flush() async {
    try {
      await flush();
    } catch (_) {
      /* Durable queue is retried. */
    }
  }

  Future<void> recover() async {
    if (!_active || _disposed || _running) return;
    _running = true;
    _retry?.cancel();
    var refreshed = false;
    try {
      await _flush();
      if (_active && !_disposed) refreshed = await shiftSync();
    } catch (_) {
      // Storage and transport failures keep the retry scheduled.
    } finally {
      _running = false;
      if (!refreshed && _active && !_disposed) {
        _retry = Timer(retryInterval, () => unawaited(recover()));
      }
    }
  }

  void pause() {
    _active = false;
    _refresh?.cancel();
    _refresh = null;
    _retry?.cancel();
    _retry = null;
    _drain?.cancel();
    _drain = null;
  }

  void dispose() {
    _disposed = true;
    pause();
  }
}
