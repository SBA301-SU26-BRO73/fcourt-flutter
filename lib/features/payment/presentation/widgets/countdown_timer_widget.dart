import 'dart:async';

import 'package:flutter/material.dart';

class CountdownTimerWidget extends StatefulWidget {
  const CountdownTimerWidget({
    super.key,
    required this.expiresAt,
    required this.onExpired,
    this.now,
  });
  final DateTime expiresAt;
  final VoidCallback onExpired;
  final DateTime Function()? now;

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<CountdownTimerWidget> {
  late final Timer _timer;
  bool _notified = false;
  @override
  bool get wantKeepAlive => true;

  int get seconds {
    final milliseconds = widget.expiresAt
        .difference((widget.now ?? DateTime.now)())
        .inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (seconds == 0 && !_notified) {
      _notified = true;
      widget.onExpired();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _notified = false;
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final remaining = seconds;
    final warning = remaining < 60;
    return Semantics(
      label: 'Thời gian giữ chỗ còn lại',
      child: Text(
        '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}',
        key: const ValueKey('hold-countdown'),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: warning
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
