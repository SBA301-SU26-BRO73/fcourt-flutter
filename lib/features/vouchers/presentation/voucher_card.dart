import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/voucher.dart';

class VoucherCard extends StatelessWidget {
  const VoucherCard({
    super.key,
    required this.voucher,
    required this.now,
    required this.busy,
    required this.onEdit,
    required this.onEnabled,
  });
  final Voucher voucher;
  final DateTime now;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEnabled;

  @override
  Widget build(BuildContext context) {
    final row = voucher;
    final expired = row.expiredAt(now);
    final (label, color) = expired
        ? ('Hết hạn', const Color(0xFFC62828))
        : row.status == VoucherStatus.expired
        ? ('Đã tắt', const Color(0xFF757575))
        : now.isBefore(row.startsAt)
        ? ('Chưa bắt đầu', const Color(0xFF965000))
        : row.usedCount >= row.limit
        ? ('Hết lượt', const Color(0xFF757575))
        : ('Còn hiệu lực', const Color(0xFF2E7D32));
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
                    onChanged: busy || expired ? null : onEnabled,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              row.type == VoucherDiscountType.percentage
                  ? 'Giảm ${NumberFormat('0.##', 'vi').format(row.valueMinor / 100)}%'
                  : 'Giảm ${money(row.valueMinor)}',
            ),
            if (row.capMinor != null) Text('Tối đa: ${money(row.capMinor!)}'),
            Text('Đơn tối thiểu: ${money(row.minOrderMinor)}'),
            Text('Đã dùng: ${row.usedCount} / ${row.limit} lượt'),
            Text(
              'Hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(row.endsAt.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
            ),
            if (busy) const LinearProgressIndicator(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: busy ? null : onEdit,
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
