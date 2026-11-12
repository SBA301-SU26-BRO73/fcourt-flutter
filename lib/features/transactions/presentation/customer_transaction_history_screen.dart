import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/transaction.dart';
import '../../../app/widgets/fc_widgets.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import 'transaction_widgets.dart';

class CustomerTransactionHistoryScreen extends StatefulWidget {
  const CustomerTransactionHistoryScreen({super.key, required this.repository});
  final CustomerTransactions repository;
  @override
  State<CustomerTransactionHistoryScreen> createState() =>
      _CustomerTransactionHistoryScreenState();
}

class _CustomerTransactionHistoryScreenState
    extends State<CustomerTransactionHistoryScreen>
    with WidgetsBindingObserver {
  List<PaymentTransaction> _items = [];
  int _page = 0, _generation = 0;
  bool _loading = false, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(reset: true);
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = ++_generation, page = reset ? 0 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items = [];
        _more = false;
      }
    });
    try {
      final result = await widget.repository.load(page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = reset
            ? result.items
            : [
                ..._items,
                ...result.items.where((t) => !_items.any((e) => e.id == t.id)),
              ];
        _page = page;
        _more = result.hasMore;
      });
    } on Failure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử thanh toán')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          ownerPad,
          4,
          ownerPad,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null) ...[
            OwnerNote(
              _error!,
              color: Theme.of(context).colorScheme.error,
              size: 12,
            ),
            TextButton(
              onPressed: () => _load(reset: _items.isEmpty),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              message: 'Chưa có giao dịch thanh toán',
            ),
          for (final e in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CustomerTransactionCard(entry: e),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_more && !_loading)
            TextButton(onPressed: () => _load(), child: const Text('Xem thêm')),
        ],
      ),
    ),
  );
}

/// Một giao dịch: nơi và số tiền (chữ thường, không "+" vì là tiền đã trả hoặc
/// hoàn), mã + giờ, rồi thẻ trạng thái cùng loại giao dịch.
class _CustomerTransactionCard extends StatelessWidget {
  const _CustomerTransactionCard({required this.entry});
  final PaymentTransaction entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final refund = entry.transactionType == 'REFUND';
    return OwnerCard(
      onTap: () => showReceipt(context, entry),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${entry.branch} · ${entry.court}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${refund ? '−' : ''}${vnd(entry.amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          OwnerNote(
            '${entry.bookingCode} · ${DateFormat('dd/MM/yyyy HH:mm').format(entry.occurredAt.toUtc().add(const Duration(hours: 7)))}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TintTag(entry.label, tone: transactionTone(context, entry)),
              const SizedBox(width: 8),
              Flexible(child: OwnerNote(entry.typeLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
