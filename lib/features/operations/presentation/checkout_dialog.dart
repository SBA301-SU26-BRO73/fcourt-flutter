import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
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
  String _key = newCommandKey();
  bool _busy = false;
  String? _error;
  CashReceipt? _quote;
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
      final quote = await widget.repository.checkoutPreview(widget.bookingId);
      if (mounted) setState(() => _quote = quote);
    } on Failure catch (e) {
      _failed(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _failed(Failure error) {
    if (!mounted) return;
    setState(() {
      _error = error.message;
      if (error is ServerFailure && error.statusCode == 409) {
        _quote = null;
        _key = newCommandKey();
        _error =
            'Phí hoặc trạng thái đã thay đổi. Kiểm tra lại trước khi xác nhận.';
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || _quote == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.checkout(
        widget.bookingId,
        _key,
        expectedSurcharge: _quote!.surcharge,
        expectedTotal: _quote!.total,
      );
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      _failed(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Wp3bDialog(
        icon: Icons.logout_rounded,
        title: 'Xác nhận trả sân',
        message:
            'Đơn #${widget.bookingId}\nMáy chủ xác nhận hoàn tất và giải phóng sân. Kiểm tra các khoản phát sinh trước khi trả sân.',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_quote case final q?) ...[
              Wp3bInfoBlock(
                children: [
                  Wp3bInfoRow(
                    'Dự tính phụ thu quá giờ',
                    moneyLabel(q.surcharge),
                  ),
                  Wp3bInfoRow('Dịch vụ gộp booking', moneyLabel(q.posAmount)),
                  Wp3bInfoRow(
                    'Cần thu thêm',
                    moneyLabel(q.surcharge + q.posAmount),
                    strong: true,
                  ),
                  Wp3bInfoRow('Giá trị đơn sau phụ thu', moneyLabel(q.total)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: Gap.md),
                child: Text(
                  'Không thu lại tiền sân đã thanh toán. Phí phát sinh theo từng 30 phút và giá slot tương ứng.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.md),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          Wp3bAction(
            _busy
                ? 'Đang trả sân…'
                : _quote == null
                ? 'Kiểm tra lại phí'
                : 'Xác nhận trả sân',
            onPressed: _busy
                ? null
                : _quote == null
                ? _load
                : _submit,
          ),
          Wp3bAction(
            'Hủy',
            kind: Wp3bActionKind.text,
            onPressed: _busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
