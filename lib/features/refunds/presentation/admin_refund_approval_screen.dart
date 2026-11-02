import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/error/failure.dart';
import '../../payment/domain/entities/payment_receipt.dart';
import '../../payment/domain/repositories/receipt_repository.dart';
import '../../transactions/presentation/transaction_widgets.dart';
import '../domain/refund.dart';
import '../domain/admin_refunds.dart';

class AdminRefundApprovalScreen extends StatefulWidget {
  const AdminRefundApprovalScreen({
    super.key,
    required this.repository,
    required this.picker,
    required this.branchId,
  });
  final AdminRefunds repository;
  final ReceiptPicker picker;
  final int branchId;
  @override
  State<AdminRefundApprovalScreen> createState() =>
      _AdminRefundApprovalScreenState();
}

class _AdminRefundApprovalScreenState extends State<AdminRefundApprovalScreen> {
  List<RefundRequest> _items = [];
  bool _loading = false, _more = false;
  int _page = 0, _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(AdminRefundApprovalScreen old) {
    super.didUpdateWidget(old);
    if (old.branchId != widget.branchId) _load(reset: true);
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
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
      final rows = await widget.repository.pending(widget.branchId, page: page);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = reset
            ? rows
            : [
                ..._items,
                ...rows.where((r) => !_items.any((e) => e.id == r.id)),
              ];
        _page = page;
        _more = rows.length == 20;
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

  Future<void> _open(RefundRequest refund) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => AdminRefundDecision(
        repository: widget.repository,
        picker: widget.picker,
        refund: refund,
      ),
    );
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Duyệt hoàn tiền')),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(reset: true),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const Text('Không có yêu cầu hoàn tiền đang chờ'),
          for (final r in _items)
            Card(
              child: ListTile(
                title: Text('Đơn #${r.bookingId} · ${vnd(r.amount)}'),
                subtitle: Text(
                  '${r.accountName}\n${r.status == 'APPROVED' ? 'Đã tiếp nhận' : 'Chờ tiếp nhận'}',
                ),
                onTap: () => _open(r),
              ),
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_more && !_loading)
            TextButton(onPressed: () => _load(), child: const Text('Xem thêm')),
        ],
      ),
    ),
  );
}

class AdminRefundDecision extends StatefulWidget {
  const AdminRefundDecision({
    super.key,
    required this.repository,
    required this.picker,
    required this.refund,
    this.qrBuilder,
  });
  final AdminRefunds repository;
  final ReceiptPicker picker;
  final RefundRequest refund;
  final Widget Function(Uri)? qrBuilder;
  @override
  State<AdminRefundDecision> createState() => _AdminRefundDecisionState();
}

class _AdminRefundDecisionState extends State<AdminRefundDecision> {
  late RefundRequest _refund;
  ReceiptImage? _proof;
  bool _busy = false;
  String? _error;
  final _reason = TextEditingController();
  @override
  void initState() {
    super.initState();
    _refund = widget.refund;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool camera) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final proof = await widget.picker.pick(camera: camera);
      if (mounted) setState(() => _proof = proof ?? _proof);
    } on Exception catch (e) {
      if (mounted) {
        setState(
          () => _error = e is Failure
              ? e.message
              : 'Chưa chọn được chứng từ. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String action) async {
    if (_busy) return;
    if (action == 'complete' && _proof == null) {
      setState(() => _error = 'Vui lòng tải ảnh chứng từ chuyển khoản');
      return;
    }
    if (action == 'reject' && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = switch (action) {
        'approve' => await widget.repository.approve(_refund.id),
        'complete' => await widget.repository.complete(_refund.id, _proof!),
        _ => await widget.repository.reject(_refund.id, _reason.text),
      };
      if (!mounted) return;
      if (action == 'approve') {
        setState(() => _refund = result);
      } else {
        setState(() => _busy = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'complete'
                  ? 'Đã ghi nhận hoàn tiền'
                  : 'Đã từ chối yêu cầu hoàn tiền',
            ),
          ),
        );
      }
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hoàn ${vnd(_refund.amount)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            '${_refund.bankName}\n${_refund.accountNumber}\n${_refund.accountName}',
          ),
          Text('Lý do: ${_refund.reason}'),
          const Text(
            'Kiểm tra đúng người nhận và số tiền trước khi chuyển khoản. Sau khi chuyển thành công, tải chứng từ bên dưới.',
          ),
          SizedBox(
            height: 240,
            child:
                widget.qrBuilder?.call(refundQr(_refund)) ??
                SvgPicture.network(
                  refundQr(_refund).toString(),
                  errorBuilder: (_, _, _) => const Center(
                    child: Text(
                      'Chưa tải được QR. Dùng thông tin tài khoản bên trên.',
                    ),
                  ),
                  placeholderBuilder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                ),
          ),
          if (_refund.status == 'PENDING')
            FilledButton(
              onPressed: _busy ? null : () => _decide('approve'),
              child: const Text('Tiếp nhận xử lý'),
            ),
          if (_refund.status == 'APPROVED')
            const Text('Đã tiếp nhận · Đang chuyển khoản'),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _pick(false),
                child: const Text('Chọn chứng từ'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _pick(true),
                child: const Text('Chụp chứng từ'),
              ),
            ],
          ),
          if (_proof != null)
            Image.memory(
              _proof!.bytes,
              height: 180,
              errorBuilder: (_, _, _) => const Text('Chứng từ đã chọn'),
            ),
          FilledButton(
            onPressed: _busy || _proof == null || _refund.status != 'APPROVED'
                ? null
                : () => _decide('complete'),
            child: Text(_busy ? 'Đang xử lý…' : 'Xác nhận đã hoàn tiền'),
          ),
          TextField(
            controller: _reason,
            enabled: !_busy,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Lý do từ chối'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _decide('reject'),
            child: const Text('Từ chối yêu cầu'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}
