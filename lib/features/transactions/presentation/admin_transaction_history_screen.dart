import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../../../core/error/failure.dart';
import '../../report_export/domain/report_export.dart';
import '../../report_export/presentation/revenue_export_button.dart';
import '../domain/branch_ledger.dart';
import '../domain/transaction.dart';
import 'transaction_widgets.dart';

class AdminTransactionHistoryScreen extends StatefulWidget {
  const AdminTransactionHistoryScreen({
    super.key,
    required this.repository,
    required this.branchId,
    this.exporter,
    this.revenueReports,
    this.fileOpener,
  });
  final AdminTransactions repository;
  final int branchId;
  final LedgerReportExporter? exporter;

  /// SCRUM-77: có cả hai thì thanh công cụ có nút xuất báo cáo doanh thu Excel/CSV.
  final RevenueReportRepository? revenueReports;
  final ReportFileOpener? fileOpener;
  @override
  State<AdminTransactionHistoryScreen> createState() =>
      _AdminTransactionHistoryScreenState();
}

class _AdminTransactionHistoryScreenState
    extends State<AdminTransactionHistoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _range;
  String _status = 'ALL', _type = 'ALL';
  bool _exporting = false;
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
      _type = 'ALL';
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
      transactionType: _type,
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
                  (i) => !_items.any((e) => e.key == i.key),
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

  Future<void> _export() async {
    if (_exporting || widget.exporter == null) return;
    final query = LedgerQuery(
      branchId: widget.branchId,
      status: _status,
      search: _search.text,
      transactionType: _type,
      fromDate: _range?.start,
      toDate: _range?.end,
    );
    setState(() => _exporting = true);
    try {
      await widget.exporter!.export(query);
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
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
    final colors = Theme.of(context).colorScheme;
    const pillPad = EdgeInsets.symmetric(horizontal: 13, vertical: 10);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đối soát tài chính'),
        actions: [
          if (widget.revenueReports != null && widget.fileOpener != null)
            RevenueExportButton(
              repository: widget.revenueReports!,
              opener: widget.fileOpener!,
              initialBranchId: widget.branchId,
              lockBranch: true,
            ),
          if (widget.exporter != null)
            IconButton(
              tooltip: _exporting ? 'Đang xuất báo cáo' : 'Xuất báo cáo CSV',
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.file_download),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(ownerPad, 4, ownerPad, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (ledger != null) ...[
              OwnerCard(
                radius: 23,
                padding: const EdgeInsets.all(18),
                color: colors.primaryContainer,
                bordered: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OwnerNote('Doanh thu thực tế'),
                      const SizedBox(height: 7),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          vnd(ledger.netRevenue),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Figure(
                    'Tổng thu',
                    vnd(ledger.received),
                    key: const ValueKey('ledger-received'),
                  ),
                  const SizedBox(width: 12),
                  _Figure('Tổng hoàn tiền', vnd(ledger.refunded)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Figure('Chờ duyệt', vnd(ledger.pending)),
                  const SizedBox(width: 12),
                  _Figure('Bị từ chối', '${ledger.rejectedCount}'),
                ],
              ),
              const SizedBox(height: 17),
            ],
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: colors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      enabled: !_exporting,
                      controller: _search,
                      maxLength: 100,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        hintText: 'Tìm mã đơn, tên hoặc số điện thoại',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      onChanged: _changed,
                      onSubmitted: (_) => _load(reset: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final pair in const {
                  'ALL': 'Mọi loại',
                  'BOOKING_PAYMENT': 'Đặt sân',
                  'REFUND': 'Hoàn tiền',
                  'WALK_IN_CASH': 'Tiền mặt',
                }.entries)
                  OwnerPill(
                    pair.value,
                    fontSize: 11,
                    padding: pillPad,
                    selected: _type == pair.key,
                    onTap: _exporting
                        ? null
                        : () {
                            setState(() => _type = pair.key);
                            _load(reset: true);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final pair in const {
                  'ALL': 'Tất cả',
                  'SUCCESS': 'Thành công',
                  'PENDING': 'Chờ duyệt',
                  'REJECTED': 'Từ chối',
                }.entries)
                  OwnerPill(
                    pair.value,
                    fontSize: 11,
                    padding: pillPad,
                    selected: _status == pair.key,
                    onTap: () {
                      setState(() => _status = pair.key);
                      _load(reset: true);
                    },
                  ),
                OwnerPill(
                  _range == null
                      ? 'Khoảng ngày'
                      : '${DateFormat('dd/MM/yyyy').format(_range!.start)} – ${DateFormat('dd/MM/yyyy').format(_range!.end)}',
                  fontSize: 11,
                  padding: pillPad,
                  trailing: Icon(
                    Icons.date_range,
                    size: 14,
                    color: colors.primary,
                  ),
                  onTap: _dates,
                ),
                if (_range != null)
                  OwnerPill(
                    'Xóa ngày',
                    fontSize: 11,
                    padding: pillPad,
                    onTap: () {
                      setState(() => _range = null);
                      _load(reset: true);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 17),
            if (_error != null) ...[
              OwnerNote(_error!, color: colors.error, size: 12),
              TextButton(
                onPressed: () => _load(reset: _items.isEmpty),
                child: const Text('Thử lại'),
              ),
            ],
            if (!_loading && _error == null && _items.isEmpty)
              const OwnerMessage(
                icon: Icons.account_balance_wallet_outlined,
                text: 'Không có giao dịch phù hợp',
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

/// Thẻ số liệu của sổ đối soát (`.kpi-pair`): nhãn nhỏ, giá trị 17 đậm.
class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: OwnerCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OwnerNote(label),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
