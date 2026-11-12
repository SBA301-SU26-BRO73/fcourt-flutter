import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/payment_checkout.dart';
import '../../domain/entities/pending_payment.dart';
import '../../domain/repositories/admin_payment_repository.dart';
import '../../../../app/widgets/fc_widgets.dart';
import '../../../admin_dashboard/presentation/widgets/owner_todo_panel.dart';
import '../../../admin_dashboard/presentation/widgets/owner_ui.dart';

class AdminPaymentApprovalScreen extends StatefulWidget {
  const AdminPaymentApprovalScreen({
    super.key,
    required this.repository,
    required this.branchId,
    this.onBack,
    this.onLedger,
    this.onRefunds,
    this.receiptBuilder,
  });
  final AdminPaymentRepository repository;
  final int branchId;
  final VoidCallback? onBack;
  final VoidCallback? onLedger;
  final VoidCallback? onRefunds;
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
      useRootNavigator: true,
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
      leading: widget.onBack == null
          ? null
          : IconButton(
              tooltip: 'Quay lại',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
      actions: [
        if (widget.onRefunds != null)
          IconButton(
            tooltip: 'Duyệt hoàn tiền',
            onPressed: widget.onRefunds,
            icon: const Icon(Icons.currency_exchange),
          ),
        if (widget.onLedger != null)
          IconButton(
            tooltip: 'Đối soát tài chính',
            onPressed: widget.onLedger,
            icon: const Icon(Icons.account_balance_wallet),
          ),
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
        padding: const EdgeInsets.fromLTRB(ownerPad, 4, ownerPad, 24),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            OwnerNote(
              _error!,
              color: Theme.of(context).colorScheme.error,
              size: 12,
            ),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
          if (!_loading && _error == null && _payments.isEmpty)
            const OwnerMessage(
              icon: Icons.fact_check_outlined,
              text: 'Không có biên lai chờ duyệt',
            ),
          if (_payments.isNotEmpty)
            OwnerSectionTitle(
              'Biên lai chờ duyệt',
              top: 4,
              trailing: OwnerNote('${_payments.length} biên lai'),
            ),
          for (final payment in _payments)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReceiptRow(
                payment: payment,
                onTap: () => _review(payment),
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

/// Thẻ biên lai chờ duyệt (như thẻ ở màn Việc cần làm): ảnh biên lai nhỏ,
/// khách + mã đơn, số tiền màu nhấn, giờ gửi và nút mở duyệt.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.payment, required this.onTap});
  final PendingPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OwnerCard(
      onTap: onTap,
      child: Row(
        children: [
          ReceiptThumb(uri: payment.receiptUri, amountVnd: payment.amountVnd),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.customerName} · ${payment.bookingCode}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  NumberFormat.currency(
                    locale: 'vi_VN',
                    symbol: '₫',
                    decimalDigits: 0,
                  ).format(payment.amountVnd),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 5),
                OwnerNote(
                  '${timeAgoVi(payment.submittedAt)} · ${DateFormat('dd/MM/yyyy HH:mm').format(payment.submittedAt)}',
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.fc.success.color,
                  foregroundColor: context.fc.success.container,
                ),
                onPressed: _busy ? null : () => _decide(true),
                child: const Text('Xác nhận nhận tiền'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
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
