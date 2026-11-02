import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

abstract interface class TicketBrightness {
  Future<void> acquire();
  Future<void> release();
}

/// Serialize changes so a late platform call cannot leave a closed ticket bright.
class DeviceTicketBrightness implements TicketBrightness {
  DeviceTicketBrightness._();
  static final instance = DeviceTicketBrightness._();
  final _screen = ScreenBrightness.instance;
  Future<void> _queue = Future.value();
  int _leases = 0;
  double? _previous;
  Future<void> _enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) => operation()).catchError((Object _) {
      /* Ticket remains readable if platform control is unavailable. */
    });
    return _queue;
  }

  @override
  Future<void> acquire() => _enqueue(() async {
    if (_leases > 0) {
      _leases++;
      return;
    }
    _previous = await _screen.hasApplicationScreenBrightnessChanged
        ? await _screen.application
        : null;
    _leases = 1;
    await _screen.setApplicationScreenBrightness(1);
  });
  @override
  Future<void> release() => _enqueue(() async {
    if (_leases == 0 || --_leases != 0) return;
    final previous = _previous;
    _previous = null;
    if (previous == null) {
      await _screen.resetApplicationScreenBrightness();
    } else {
      await _screen.setApplicationScreenBrightness(previous);
    }
  });
}

class TicketBrightnessScope extends StatefulWidget {
  const TicketBrightnessScope({
    super.key,
    required this.controller,
    required this.child,
  });
  final TicketBrightness controller;
  final Widget child;
  @override
  State<TicketBrightnessScope> createState() => _TicketBrightnessScopeState();
}

class _TicketBrightnessScopeState extends State<TicketBrightnessScope>
    with WidgetsBindingObserver {
  bool _active = false;
  void _set(bool active) {
    if (_active == active) return;
    _active = active;
    // Every controller may fail; do not let an unsupported platform hide the ticket.
    unawaited(
      (active ? widget.controller.acquire() : widget.controller.release())
          .catchError((Object _) {}),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _set(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _set(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    _set(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
