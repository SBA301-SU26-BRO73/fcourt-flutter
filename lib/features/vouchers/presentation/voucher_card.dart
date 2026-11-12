import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../domain/voucher.dart';

class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.voucher,
    required this.now,
    required this.busy,
    required this.onEdit,
    required this.onEnabled,
    this.blocked = false,
    this.onUsage,
  });
  final Voucher voucher;
  final DateTime now;
  final bool busy;
  final bool blocked;
  final VoidCallback? onUsage;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEnabled;

  @override
  Widget build(BuildContext context) {
    final row = voucher;
    final expired = row.expiredAt(now);
    final (label, tone) = expired
        ? ('Hết hạn', context.fc.danger)
        : row.status == VoucherStatus.expired
        ? ('Đã tắt', context.fc.neutral)
        : now.isBefore(row.startsAt)
        ? ('Chưa bắt đầu', context.fc.warning)
        : row.usedCount >= row.limit
        ? ('Hết lượt', context.fc.neutral)
        : ('Còn hiệu lực', context.fc.success);
    String money(int amount) =>
        '${NumberFormat('#,##0.##', 'vi').format(amount / 100)} đ';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.code,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Semantics(
                  label: 'Kích hoạt ${row.code}',
                  child: Switch(
                    value: row.enabledAt(now),
                    onChanged: busy || blocked || expired ? null : onEnabled,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(label, tone: tone),
            ),
            const SizedBox(height: 8),
            Text(
              row.type == VoucherDiscountType.percentage
                  ? 'Giảm ${NumberFormat('0.##', 'vi').format(row.valueMinor / 100)}%'
                  : 'Giảm ${money(row.valueMinor)}',
            ),
            if (row.capMinor != null) Text('Tối đa: ${money(row.capMinor!)}'),
            Text('Đơn tối thiểu: ${money(row.minOrderMinor)}'),
            TextButton(
              onPressed: busy || blocked ? null : onUsage,
              child: Text('Đã dùng: ${row.usedCount} / ${row.limit} lượt'),
            ),
            Text(
              'Hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(row.endsAt.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
            ),
            if (busy) const LinearProgressIndicator(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: busy || blocked ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
