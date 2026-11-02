import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../domain/branch_ledger.dart';
import '../domain/transaction.dart';
import 'transaction_widgets.dart';

class AdminTransactionHistoryScreen extends StatefulWidget {
  const AdminTransactionHistoryScreen({
    super.key,
    required this.repository,
    required this.branchId,
  });
  final AdminTransactions repository;
  final int branchId;
  @override
  State<AdminTransactionHistoryScreen> createState() =>
      _AdminTransactionHistoryScreenState();
}

class _AdminTransactionHistoryScreenState
    extends State<AdminTransactionHistoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _range;
  String _status = 'ALL';
  List<PaymentTransaction> _items = [];
  LedgerPage? _ledger;
  int _page = 0, _generation = 0;
  bool _loading = false, _more = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(AdminTransactionHistoryScreen old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId) {
      _debounce?.cancel();
      _search.clear();
      _range = null;
      _status = 'ALL';
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    _debounce?.cancel();
    final generation = ++_generation, page = reset ? 0 : _page + 1;
    final query = LedgerQuery(
      branchId: widget.branchId,
      status: _status,
      search: _search.text,
      fromDate: _range?.start,
      toDate: _range?.end,
    );
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items = [];
        _ledger = null;
        _more = false;
      }
    });
    try {
      final result = await widget.repository.load(query, page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _ledger = result;
        _items = reset
            ? result.transactions.items
            : [
                ..._items,
                ...result.transactions.items.where(
                  (i) => !_items.any((e) => e.id == i.id),
                ),
              ];
        _page = page;
        _more = result.transactions.hasMore;
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

  Future<void> _dates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (!mounted || result == null) return;
    setState(() => _range = result);
    await _load(reset: true);
  }

  void _changed(String value) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _items = [];
      _ledger = null;
      _loading = true;
      _more = false;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(reset: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = _ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('Đối soát tài chính')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (ledger != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      Text('Đã nhận\n${vnd(ledger.received)}'),
                      Text('Chờ duyệt\n${vnd(ledger.pending)}'),
                      Text('Bị từ chối\n${ledger.rejectedCount}'),
                    ],
                  ),
                ),
              ),
            TextField(
              controller: _search,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Tìm mã đơn, tên hoặc số điện thoại',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _changed,
              onSubmitted: (_) => _load(reset: true),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final pair in const {
                  'ALL': 'Tất cả',
                  'SUCCESS': 'Thành công',
                  'PENDING': 'Chờ duyệt',
                  'REJECTED': 'Từ chối',
                }.entries)
                  ChoiceChip(
                    label: Text(pair.value),
                    selected: _status == pair.key,
                    onSelected: (_) {
                      setState(() => _status = pair.key);
                      _load(reset: true);
                    },
                  ),
                ActionChip(
                  label: Text(
                    _range == null
                        ? 'Khoảng ngày'
                        : '${DateFormat('dd/MM/yyyy').format(_range!.start)} – ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
                  ),
                  avatar: const Icon(Icons.date_range),
                  onPressed: _dates,
                ),
                if (_range != null)
                  ActionChip(
                    label: const Text('Xóa ngày'),
                    onPressed: () {
                      setState(() => _range = null);
                      _load(reset: true);
                    },
                  ),
              ],
            ),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: () => _load(reset: _items.isEmpty),
                child: const Text('Thử lại'),
              ),
            ],
            if (!_loading && _error == null && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Không có giao dịch phù hợp'),
              ),
            ..._items.map((e) => TransactionTile(entry: e)),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_more && !_loading)
              TextButton(
                onPressed: () => _load(),
                child: const Text('Xem thêm'),
              ),
          ],
        ),
      ),
    );
  }
}
