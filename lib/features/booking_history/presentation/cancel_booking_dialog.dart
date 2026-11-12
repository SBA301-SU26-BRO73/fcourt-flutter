import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/booking.dart';
import '../domain/cancellation.dart';

class CancelBookingDialog extends StatefulWidget {
  const CancelBookingDialog({
    super.key,
    required this.id,
    required this.repository,
    required this.policy,
  });
  final int id;
  final CancellationRepository repository;
  final CancellationPolicy policy;
  @override
  State<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<CancelBookingDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  late CancellationPolicy _policy;
  @override
  void initState() {
    super.initState();
    _policy = widget.policy;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_busy) return;
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do hủy');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final booking = await widget.repository.cancel(widget.id, _reason.text);
      if (mounted) {
        setState(() => _busy = false);
        Navigator.of(context).pop<Booking>(booking);
      }
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      try {
        final policy = await widget.repository.quote(widget.id);
        if (mounted) setState(() => _policy = policy);
      } on Failure {
        /* Keep original failure and allow a later retry. */
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Hủy đặt sân'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chỉ được hủy trước giờ chơi ít nhất ${_policy.cutoffHours} giờ.',
            ),
            if (_policy.startsAt != null)
              Text(
                'Giờ chơi: ${DateFormat('dd/MM/yyyy HH:mm').format(_policy.startsAt!.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
              ),
            if (_policy.cancelBefore != null)
              Text(
                'Hạn hủy: ${DateFormat('dd/MM/yyyy HH:mm').format(_policy.cancelBefore!.toUtc().add(const Duration(hours: 7)))}',
              ),
            Text(
              'Hoàn tiền dự kiến: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(_policy.refundAmount)}',
            ),
            const Text(
              'Hủy sân không tự động chuyển tiền. Bạn cần gửi yêu cầu hoàn tiền sau khi hủy.',
            ),
            if (!_policy.allowed) Text(_policy.reason),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Lý do hủy'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Giữ đặt sân'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _busy || !_policy.allowed ? null : _cancel,
          child: Text(_busy ? 'Đang hủy…' : 'Xác nhận hủy'),
        ),
      ],
    ),
  );
}
