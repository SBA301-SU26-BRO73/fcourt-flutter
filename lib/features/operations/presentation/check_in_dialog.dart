import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/check_in_failure.dart';
import '../domain/schedule.dart';
import '../../../app/theme/tokens.dart';

class CheckInDialog extends StatefulWidget {
  const CheckInDialog({
    super.key,
    required this.repository,
    required this.code,
    this.manual = false,
  });
  final OperationsRepository repository;
  final String code;
  final bool manual;
  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  TicketPreview? _preview;
  String? _error;
  bool _busy = true;
  bool _submitted = false;
  bool _done = false;
  final _key = newCommandKey();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.repository.preview(widget.code);
      if (mounted) setState(() => _preview = value);
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _submitted = true;
      _error = null;
    });
    try {
      final bookingId = await widget.repository.checkIn(
        widget.code,
        _key,
        manual: widget.manual,
      );
      if (bookingId != _preview?.bookingId) {
        throw const UnknownFailure(
          'Kết quả nhận sân không khớp vé đã kiểm tra',
        );
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      final p = _preview!;
      if (!p.offline) {
        // Online: một hộp xác nhận duy nhất, kết quả báo bằng thông báo ngắn.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Nhận sân thành công · ${p.name} · ${p.courtName}'),
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: ChartColors.success,
            size: 40,
          ),
          title: Text(p.offline ? 'HỢP LỆ (OFFLINE)' : 'Nhận sân thành công'),
          content: Text(
            '${p.name}\n${p.courtName}\n${displayDate(p.date)} · ${p.start}–${p.end}${p.offline ? '\nĐã ghi trên máy này. Đang chờ đối soát máy chủ.' : ''}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hoàn tất nhận sân'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(_error == null ? 'Xác nhận nhận sân' : 'Chưa thể nhận sân'),
      icon: Icon(
        _error == null ? Icons.verified_outlined : Icons.error_outline,
        color: _error == null
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_preview case final p?)
              Text(
                '${p.name}\n${p.courtName}\n${displayDate(p.date)} · ${p.start}–${p.end}',
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_submitted && _error != null)
              const Text(
                'Chưa rõ kết quả? Thử lại cùng lệnh để đối soát, không quét lại vé.',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Đóng'),
        ),
        if (_preview == null)
          FilledButton(
            onPressed: _busy ? null : _load,
            child: const Text('Kiểm tra lại'),
          ),
        if (_preview != null)
          FilledButton(
            onPressed: _busy || _done ? null : _confirm,
            child: Text(
              _submitted ? 'Thử lại lệnh nhận sân' : 'Xác nhận nhận sân',
            ),
          ),
      ],
    ),
  );
}
