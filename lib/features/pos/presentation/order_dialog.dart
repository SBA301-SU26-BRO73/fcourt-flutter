import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../../core/error/failure.dart';
import '../../operations/domain/counter.dart';
import '../domain/pos.dart';

String orderStatus(String status) => switch (status) {
  'PAID' => 'Đã thanh toán',
  'ON_BOOKING' => 'Đã gộp vào booking',
  'PENDING_CHARGE' => 'Đang chờ gộp booking',
  'CANCELLED' => 'Đã hủy',
  _ => 'Cần kiểm tra',
};

class OrderDialog extends StatefulWidget {
  const OrderDialog({super.key, required this.repository, required this.order});
  final PosRepository repository;
  final PosOrder order;
  @override
  State<OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<OrderDialog> with WidgetsBindingObserver {
  late PosOrder _order = widget.order;
  Timer? _timer;
  int _attempts = 0;
  bool _loading = false;
  String? _error;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_active && _order.status == 'PENDING_CHARGE' && _attempts < 30) {
      _timer = Timer(const Duration(seconds: 1), _refresh);
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    _attempts++;
    try {
      final result = await widget.repository.order(_order.id);
      if (mounted) {
        setState(() {
          _order = result;
          _error = null;
        });
      }
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _schedule();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final handOver = _order.mayHandOver;
    return Wp3bDialog(
      icon: handOver ? Icons.receipt_long_outlined : Icons.hourglass_top,
      tone: handOver ? context.fc.success : context.fc.warning,
      title: _order.code,
      message: orderStatus(_order.status),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            handOver ? 'Có thể giao hàng theo hóa đơn.' : 'CHƯA GIAO HÀNG. Chờ xác nhận gộp booking; không thu lại bằng lệnh mới.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: handOver ? colors.onSurfaceVariant : colors.error,
              fontWeight: handOver ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.lg),
          Wp3bInfoBlock(
            children: [
              ..._order.lines.map(
                (l) => Wp3bInfoRow(
                  '${l.quantity} × ${l.name}',
                  moneyLabel(l.total),
                ),
              ),
              Divider(height: 16, color: colors.outlineVariant),
              Wp3bInfoRow('Tổng', moneyLabel(_order.total), strong: true),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: Gap.md),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.error),
              ),
            ),
          if (_attempts >= 30 && _order.status == 'PENDING_CHARGE')
            Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Text(
                'Đã dừng tự làm mới. Kiểm tra lại hóa đơn để đối soát; không xuất đơn mới cho cùng lần bán.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
      actions: [
        Wp3bAction('Đóng', onPressed: () => Navigator.pop(context)),
        Wp3bAction(
          'Kiểm tra trạng thái',
          kind: Wp3bActionKind.tonal,
          onPressed: _loading ? null : _refresh,
        ),
      ],
    );
  }
}

class OrderHistory extends StatefulWidget {
  const OrderHistory({super.key, required this.repository});
  final PosRepository repository;
  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends State<OrderHistory> {
  final _orders = <PosOrder>[];
  bool _busy = false;
  bool _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rows = await widget.repository.history(offset: _orders.length);
      if (mounted) {
        setState(() {
          _orders.addAll(rows);
          _more = rows.length == 50;
          _error = null;
        });
      }
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hóa đơn tại quầy')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        if (!_busy && _orders.isEmpty)
          const Text('Chưa có hóa đơn. Tạo đơn từ giỏ hàng POS.'),
        ..._orders.map(
          (o) => ListTile(
            title: Text(o.code),
            subtitle: Text('${orderStatus(o.status)} · ${moneyLabel(o.total)}'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  OrderDialog(repository: widget.repository, order: o),
            ),
          ),
        ),
        if (_more)
          TextButton(
            onPressed: _busy ? null : _load,
            child: const Text('Tải thêm hóa đơn'),
          ),
      ],
    ),
  );
}
