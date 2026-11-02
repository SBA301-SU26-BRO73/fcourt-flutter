import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/entities/pending_payment.dart';
import '../../domain/repositories/admin_payment_repository.dart';

class AdminPaymentApprovalScreen extends StatefulWidget {
  const AdminPaymentApprovalScreen({
    super.key,
    required this.repository,
    required this.branchId,
    this.receiptBuilder,
  });
  final AdminPaymentRepository repository;
  final int branchId;
  final Widget Function(Uri)? receiptBuilder;
  @override
  State<AdminPaymentApprovalScreen> createState() =>
      _AdminPaymentApprovalScreenState();
}

class _AdminPaymentApprovalScreenState
    extends State<AdminPaymentApprovalScreen> {
  final List<PendingPayment> _payments = [];
  String? _error;
  bool _loading = false, _more = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AdminPaymentApprovalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchId != widget.branchId) {
      _generation++;
      _loading = false;
      _payments.clear();
      _load();
    }
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.pending(
        widget.branchId,
        offset: append ? _payments.length : 0,
      );
      if (mounted && generation == _generation) {
        setState(() {
          if (!append) _payments.clear();
          _payments.addAll(rows);
          _more = rows.length == 50;
        });
      }
    } on PaymentFailure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _review(PendingPayment payment) async {
    final generation = _generation;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => _ApprovalSheet(
        repository: widget.repository,
        payment: payment,
        receiptBuilder: widget.receiptBuilder,
      ),
    );
    if (!mounted || generation != _generation || result != true) return;
    setState(() => _payments.removeWhere((p) => p.id == payment.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã cập nhật thanh toán')));
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Duyệt biên lai'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          tooltip: 'Tải lại',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
          if (!_loading && _error == null && _payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Text(
                'Không có biên lai chờ duyệt',
                textAlign: TextAlign.center,
              ),
            ),
          for (final payment in _payments)
            Card(
              child: ListTile(
                onTap: () => _review(payment),
                title: Text('${payment.customerName} · ${payment.bookingCode}'),
                subtitle: Text(
                  '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(payment.amountVnd)}\n${DateFormat('dd/MM/yyyy HH:mm').format(payment.submittedAt)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          if (_more)
            TextButton(
              onPressed: _loading ? null : () => _load(append: true),
              child: const Text('Xem thêm'),
            ),
        ],
      ),
    ),
  );
}

class _ApprovalSheet extends StatefulWidget {
  const _ApprovalSheet({
    required this.repository,
    required this.payment,
    this.receiptBuilder,
  });
  final AdminPaymentRepository repository;
  final PendingPayment payment;
  final Widget Function(Uri)? receiptBuilder;
  @override
  State<_ApprovalSheet> createState() => _ApprovalSheetState();
}

class _ApprovalSheetState extends State<_ApprovalSheet> {
  final _reason = TextEditingController();
  bool _busy = false, _rejecting = false;
  int _turns = 0;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(bool confirm) async {
    if (_busy) return;
    if (!confirm &&
        (_reason.text.trim().isEmpty || _reason.text.trim().length > 500)) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (confirm) {
        await widget.repository.confirm(widget.payment.id);
      } else {
        await widget.repository.reject(widget.payment.id, _reason.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on PaymentFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.payment.bookingCode,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              NumberFormat.currency(
                locale: 'vi_VN',
                symbol: '₫',
                decimalDigits: 0,
              ).format(widget.payment.amountVnd),
            ),
            SizedBox(
              height: 280,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: RotatedBox(
                  quarterTurns: _turns,
                  child:
                      widget.receiptBuilder?.call(widget.payment.receiptUri) ??
                      Image.network(
                        widget.payment.receiptUri.toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'Chưa tải được biên lai. Đóng và mở lại để thử lại.',
                          ),
                        ),
                      ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _turns++),
              icon: const Icon(Icons.rotate_right),
              label: const Text('Xoay ảnh'),
            ),
            if (_rejecting)
              TextField(
                controller: _reason,
                maxLength: 500,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Lý do từ chối'),
                maxLines: 2,
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
                onPressed: _busy ? null : () => _decide(true),
                child: const Text('Xác nhận nhận tiền'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed: _busy
                    ? null
                    : () {
                        if (!_rejecting) {
                          setState(() => _rejecting = true);
                        } else {
                          _decide(false);
                        }
                      },
                child: Text(_rejecting ? 'Gửi từ chối' : 'Từ chối thanh toán'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
