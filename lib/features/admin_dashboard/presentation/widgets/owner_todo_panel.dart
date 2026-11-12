import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../admin_bookings/domain/admin_booking_query.dart';
import '../../../admin_bookings/domain/admin_booking_repository.dart';
import '../../../admin_facility/domain/entities/branch.dart';
import '../../../admin_facility/domain/repositories/branch_repository.dart';
import '../../../payment/domain/entities/payment_checkout.dart';
import '../../../payment/domain/entities/pending_payment.dart';
import '../../../payment/domain/repositories/admin_payment_repository.dart';
import '../../../refunds/domain/admin_refunds.dart';

/// Một biên lai chờ duyệt kèm chi nhánh của nó.
class TodoReceipt {
  const TodoReceipt(this.branchId, this.payment);
  final int branchId;
  final PendingPayment payment;
}

/// Số liệu "việc cần làm" của chủ sân, gộp qua tối đa [OwnerTodoLoader.maxBranches] chi nhánh.
class OwnerTodoSummary {
  const OwnerTodoSummary({
    this.receipts = const [],
    this.receiptCount = 0,
    this.refundCount = 0,
    this.todayCount = 0,
    this.receiptBranchId,
    this.refundBranchId,
  });
  final List<TodoReceipt> receipts;
  final int receiptCount, refundCount, todayCount;
  final int? receiptBranchId, refundBranchId;
}

class OwnerTodoLoader {
  const OwnerTodoLoader({
    required this.branches,
    this.payments,
    this.refunds,
    this.bookings,
  });
  final BranchRepository branches;
  final AdminPaymentRepository? payments;
  final AdminRefunds? refunds;
  final AdminBookingRepository? bookings;
  static const maxBranches = 5;

  Future<OwnerTodoSummary> load({DateTime? now}) async {
    final owned = (await branches.getBranches())
        .take(maxBranches)
        .toList(growable: false);
    final today = now ?? DateTime.now();
    final receipts = <TodoReceipt>[];
    var receiptCount = 0, refundCount = 0, todayCount = 0;
    int? receiptBranch, refundBranch;
    for (final Branch branch in owned) {
      final pending = await payments?.pending(branch.id) ?? const [];
      if (pending.isNotEmpty) {
        receiptBranch ??= branch.id;
        receiptCount += pending.length;
        receipts.addAll(pending.map((p) => TodoReceipt(branch.id, p)));
      }
      final due = await refunds?.pending(branch.id) ?? const [];
      if (due.isNotEmpty) {
        refundBranch ??= branch.id;
        refundCount += due.length;
      }
      final page = await bookings?.search(
        AdminBookingQuery(
          branchId: branch.id,
          date: DateTime(today.year, today.month, today.day),
        ),
      );
      todayCount += page?.total ?? 0;
    }
    return OwnerTodoSummary(
      receipts: receipts,
      receiptCount: receiptCount,
      refundCount: refundCount,
      todayCount: todayCount,
      receiptBranchId: receiptBranch,
      refundBranchId: refundBranch,
    );
  }
}

/// Đầu trang chủ chủ sân: ba thẻ đếm và duyệt/từ chối biên lai ngay trên thẻ.
class OwnerTodoPanel extends StatefulWidget {
  const OwnerTodoPanel({
    super.key,
    required this.loader,
    this.onReceipts,
    this.onRefunds,
    this.onToday,
  });
  final OwnerTodoLoader loader;
  final void Function(int branchId)? onReceipts, onRefunds;
  final VoidCallback? onToday;

  @override
  State<OwnerTodoPanel> createState() => _OwnerTodoPanelState();
}

class _OwnerTodoPanelState extends State<OwnerTodoPanel> {
  OwnerTodoSummary? _summary;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.loader.load();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được việc cần làm.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  static String _money(int value) => NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  ).format(value);

  Future<void> _approve(TodoReceipt item) async {
    final repository = widget.loader.payments;
    if (_busy || repository == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyệt biên lai?'),
        content: Text(
          'Đơn ${item.payment.bookingCode} · ${_money(item.payment.amountVnd)}. '
          'Đơn sẽ được xác nhận cho khách.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => repository.confirm(item.payment.id), 'Đã duyệt biên lai');
  }

  Future<void> _reject(TodoReceipt item) async {
    final repository = widget.loader.payments;
    if (_busy || repository == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối biên lai'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Lý do'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, value.text.trim()),
              child: const Text('Từ chối'),
            ),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    await _run(
      () => repository.reject(item.payment.id, reason),
      'Đã từ chối biên lai',
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _message(done);
      await _load();
    } on PaymentFailure catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Chưa xử lý được. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;
    if (_loading && summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (summary == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(_error ?? 'Không tải được việc cần làm.')),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return Column(
      key: const ValueKey('owner-todo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Việc cần làm', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CountCard(
                key: const ValueKey('todo-receipts'),
                icon: Icons.receipt_long_outlined,
                label: 'Biên lai chờ duyệt',
                count: summary.receiptCount,
                highlight: summary.receiptCount > 0,
                onTap:
                    widget.onReceipts == null || summary.receiptBranchId == null
                    ? null
                    : () => widget.onReceipts!(summary.receiptBranchId!),
              ),
              const SizedBox(width: 8),
              _CountCard(
                key: const ValueKey('todo-refunds'),
                icon: Icons.currency_exchange,
                label: 'Yêu cầu hoàn tiền',
                count: summary.refundCount,
                highlight: summary.refundCount > 0,
                onTap:
                    widget.onRefunds == null || summary.refundBranchId == null
                    ? null
                    : () => widget.onRefunds!(summary.refundBranchId!),
              ),
              const SizedBox(width: 8),
              _CountCard(
                key: const ValueKey('todo-today'),
                icon: Icons.event_note_outlined,
                label: 'Đơn hôm nay',
                count: summary.todayCount,
                onTap: widget.onToday,
              ),
            ],
          ),
        ),
        for (final item in summary.receipts.take(3)) ...[
          const SizedBox(height: 8),
          Card(
            key: ValueKey('todo-receipt-${item.payment.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.payment.bookingCode} · ${item.payment.customerName}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(_money(item.payment.amountVnd)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: ValueKey('reject-${item.payment.id}'),
                          onPressed: _busy ? null : () => _reject(item),
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: ValueKey('approve-${item.payment.id}'),
                          onPressed: _busy ? null : () => _approve(item),
                          child: const Text('Duyệt'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    this.highlight = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: highlight ? colors.primaryContainer : null,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
