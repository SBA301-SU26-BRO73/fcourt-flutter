import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/tokens.dart';
import '../../../admin_bookings/domain/admin_booking_query.dart';
import '../../../admin_bookings/domain/admin_booking_repository.dart';
import '../../../admin_facility/domain/entities/branch.dart';
import '../../../admin_facility/domain/repositories/branch_repository.dart';
import '../../../payment/domain/entities/payment_checkout.dart';
import '../../../payment/domain/entities/pending_payment.dart';
import '../../../payment/domain/repositories/admin_payment_repository.dart';
import '../../../refunds/domain/admin_refunds.dart';
import 'owner_ui.dart';

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
    this.branchLabel,
  });
  final List<TodoReceipt> receipts;
  final int receiptCount, refundCount, todayCount;
  final int? receiptBranchId, refundBranchId;

  /// Khu vực của chi nhánh đầu tiên, vd "Ba Đình, Hà Nội".
  final String? branchLabel;
}

String _area(Branch b) => [
  b.district,
  b.city,
].whereType<String>().where((p) => p.trim().isNotEmpty).join(", ");

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
      branchLabel: owned.isEmpty ? null : _area(owned.first),
      refundBranchId: refundBranch,
    );
  }
}

/// Lối tắt tới màn quản lý khác của chủ sân (vòng tròn tint dưới danh sách).
class OwnerShortcut {
  const OwnerShortcut(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Màn "Việc cần làm" của chủ sân (mockup 05): lời chào, ba thẻ đếm, biên lai
/// chờ duyệt có nút Duyệt/Từ chối ngay trên thẻ.
class OwnerTodoPanel extends StatefulWidget {
  const OwnerTodoPanel({
    super.key,
    required this.loader,
    this.onReceipts,
    this.onRefunds,
    this.onToday,
    this.onOverview,
    this.onNotifications,
    this.userName,
    this.shortcuts = const [],
    this.now,
  });
  final OwnerTodoLoader loader;
  final void Function(int branchId)? onReceipts, onRefunds;
  final VoidCallback? onToday, onOverview, onNotifications;
  final String? userName;
  final List<OwnerShortcut> shortcuts;

  /// Giờ hiện tại (cho test và ảnh chụp).
  final DateTime? now;

  @override
  State<OwnerTodoPanel> createState() => _OwnerTodoPanelState();
}

class _OwnerTodoPanelState extends State<OwnerTodoPanel> {
  OwnerTodoSummary? _summary;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  /// Số biên lai hiện trực tiếp trên thẻ; phần còn lại nằm sau dòng "Còn n".
  static const _visibleReceipts = 2;

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

  static String _price(int value) =>
      '${NumberFormat.decimalPattern('vi_VN').format(value)}đ';

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

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final Widget body;
    if (_loading && summary == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (summary == null) {
      body = OwnerMessage(
        icon: Icons.cloud_off_outlined,
        text: _error ?? 'Không tải được việc cần làm.',
        action: 'Thử lại',
        onAction: _load,
      );
    } else {
      body = _content(context, summary);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ownerPad),
      child: Column(
        key: const ValueKey('owner-todo'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hello(widget: widget, label: summary?.branchLabel),
          body,
        ],
      ),
    );
  }

  Widget _content(BuildContext context, OwnerTodoSummary summary) {
    final fc = context.fc;
    final shown = summary.receipts.take(_visibleReceipts).toList();
    final more = summary.receiptCount - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, bottom: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Việc cần làm',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (widget.onOverview != null)
                OwnerLink('Tổng quan', onTap: widget.onOverview),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CountCard(
                key: const ValueKey('todo-receipts'),
                icon: Icons.check,
                tone: fc.info,
                label: 'Biên lai\nchờ duyệt',
                count: summary.receiptCount,
                onTap:
                    widget.onReceipts == null || summary.receiptBranchId == null
                    ? null
                    : () => widget.onReceipts!(summary.receiptBranchId!),
              ),
              const SizedBox(width: 9),
              _CountCard(
                key: const ValueKey('todo-refunds'),
                icon: Icons.arrow_forward,
                tone: fc.warning,
                label: 'Yêu cầu\nhoàn tiền',
                count: summary.refundCount,
                onTap:
                    widget.onRefunds == null || summary.refundBranchId == null
                    ? null
                    : () => widget.onRefunds!(summary.refundBranchId!),
              ),
              const SizedBox(width: 9),
              _CountCard(
                key: const ValueKey('todo-today'),
                icon: Icons.event_note_outlined,
                tone: fc.success,
                label: 'Đơn\nhôm nay',
                count: summary.todayCount,
                onTap: widget.onToday,
              ),
            ],
          ),
        ),
        OwnerSectionTitle(
          'Biên lai chờ duyệt',
          trailing: OwnerNote('${summary.receiptCount} biên lai'),
        ),
        if (shown.isEmpty)
          OwnerCard(
            child: Row(
              children: [
                OwnerCircle(icon: Icons.check, tone: fc.success),
                const SizedBox(width: 13),
                const Expanded(
                  child: OwnerNote('Không có biên lai nào đang chờ duyệt'),
                ),
              ],
            ),
          ),
        for (final item in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReceiptCard(
              key: ValueKey('todo-receipt-${item.payment.id}'),
              item: item,
              price: _price(item.payment.amountVnd),
              ago: timeAgoVi(item.payment.submittedAt, now: widget.now),
              busy: _busy,
              onApprove: () => _approve(item),
              onReject: () => _reject(item),
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: InkWell(
              onTap:
                  widget.onReceipts == null || summary.receiptBranchId == null
                  ? null
                  : () => widget.onReceipts!(summary.receiptBranchId!),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  OwnerCircle(icon: Icons.schedule, tone: fc.info),
                  const SizedBox(width: 8),
                  OwnerNote('Còn $more biên lai chờ duyệt'),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        if (widget.shortcuts.isNotEmpty) ...[
          const OwnerSectionTitle('Quản lý'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in widget.shortcuts) _ShortcutIcon(shortcut: s),
            ],
          ),
        ],
      ],
    );
  }
}

class _Hello extends StatelessWidget {
  const _Hello({required this.widget, this.label});
  final OwnerTodoPanel widget;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = widget.now ?? DateTime.now();
    final date =
        '${_OwnerTodoPanelState._weekdays[now.weekday - 1]}, '
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}';
    final name = widget.userName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 7, bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OwnerNote('Chủ sân · $date'),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'Chào bạn' : 'Chào $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.7,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 23,
                      color: colors.primary,
                    ),
                  ],
                ),
                if (label != null && label!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: OwnerNote(label!)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Thông báo',
            child: Material(
              color: colors.surfaceContainerLow,
              shape: CircleBorder(
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onNotifications,
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(
                    Icons.notifications_none,
                    size: 22,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.label,
    required this.count,
    this.onTap,
  });
  final IconData icon;
  final StatusTone tone;
  final String label;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: OwnerSoftPanel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OwnerCircle(icon: icon, tone: tone, iconSize: 17),
            const SizedBox(height: 9),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    super.key,
    required this.item,
    required this.price,
    required this.ago,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });
  final TodoReceipt item;
  final String price, ago;
  final bool busy;
  final VoidCallback onApprove, onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final p = item.payment;
    return OwnerCard(
      child: Column(
        children: [
          Row(
            children: [
              ReceiptThumb(uri: p.receiptUri, amountVnd: p.amountVnd),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    OwnerNote('#${p.bookingCode} · $ago'),
                    const SizedBox(height: 5),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    OwnerNote(
                      "Gửi lúc ${DateFormat('HH:mm, dd/MM').format(p.submittedAt)}",
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OwnerPillButton(
                  key: ValueKey('approve-${p.id}'),
                  label: 'Duyệt',
                  icon: Icons.check,
                  onPressed: busy ? null : onApprove,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OwnerPillButton(
                  key: ValueKey('reject-${p.id}'),
                  label: 'Từ chối',
                  filled: false,
                  onPressed: busy ? null : onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ảnh biên lai nhỏ (67x92, nghiêng 3 độ, viền 5 màu nền mềm). Khi ảnh thật
/// chưa tải được thì vẽ tờ biên lai mẫu có dấu tích và số tiền.
class ReceiptThumb extends StatelessWidget {
  const ReceiptThumb({super.key, required this.uri, required this.amountVnd});
  final Uri uri;
  final int amountVnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const ink = Color(0xFF195D44);
    final amount = NumberFormat.decimalPattern('vi_VN').format(amountVnd);
    final stub = Container(
      color: const Color(0xFFF5FCF8),
      padding: const EdgeInsets.fromLTRB(3, 6, 3, 0),
      child: Column(
        children: [
          const SizedBox(height: 2),
          const Icon(Icons.check, size: 18, color: ink),
          const SizedBox(height: 2),
          Text(
            amount,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '••••••••\n──────\n••••••••',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 6,
              height: 1.6,
              color: Color(0xFFC3D7CB),
            ),
          ),
        ],
      ),
    );
    return Transform.rotate(
      angle: -3 * 3.1415926 / 180,
      child: Container(
        width: 67,
        height: 92,
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        padding: const EdgeInsets.all(5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            uri.toString(),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => stub,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : stub,
          ),
        ),
      ),
    );
  }
}

class _ShortcutIcon extends StatelessWidget {
  const _ShortcutIcon({required this.shortcut});
  final OwnerShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: shortcut.onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryContainer,
              ),
              child: Icon(shortcut.icon, size: 27, color: colors.primary),
            ),
            const SizedBox(height: 9),
            Text(
              shortcut.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
