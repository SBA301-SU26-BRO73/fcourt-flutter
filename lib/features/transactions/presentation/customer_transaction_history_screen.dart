import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../domain/transaction.dart';
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
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Lịch sử thanh toán'),
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(reset: _items.isEmpty),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const Text(
              'Chưa có giao dịch thanh toán',
              textAlign: TextAlign.center,
            ),
          ..._items.map((e) => TransactionTile(entry: e)),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_more && !_loading)
            TextButton(onPressed: () => _load(), child: const Text('Xem thêm')),
        ],
      ),
    ),
  );
}
