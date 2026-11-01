import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/counter.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({
    super.key,
    required this.repository,
    required this.bookingId,
  });
  final CounterRepository repository;
  final int bookingId;
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _key = newCommandKey();
  bool _busy = false;
  String? _error;
  CashReceipt? _quote;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final quote = await widget.repository.checkoutPreview(widget.bookingId);
      if (mounted) setState(() => _quote = quote);
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _quote == null) return;
    setState(() => _busy = true);
    try {
      await widget.repository.checkout(widget.bookingId, _key);
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
      title: const Text('Xác nhận trả sân'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Đơn #${widget.bookingId}\nMáy chủ xác nhận hoàn tất và giải phóng sân. Kiểm tra các khoản phát sinh trước khi trả sân.',
          ),
          if (_quote case final q?)
            Text(
              'Dự tính phụ thu: ${moneyLabel(q.surcharge)}\nTổng: ${moneyLabel(q.total)}',
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : _quote == null
              ? _load
              : _submit,
          child: Text(_busy ? 'Đang trả sân…' : 'Xác nhận trả sân'),
        ),
      ],
    ),
  );
}
