import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../domain/voucher.dart';

/// Thẻ voucher: mã + công tắc, thẻ trạng thái, mức giảm nổi bật màu nhấn,
/// các điều kiện, lượt dùng và nút sửa.
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
    final colors = Theme.of(context).colorScheme;
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
    final discount = row.type == VoucherDiscountType.percentage
        ? 'Giảm ${NumberFormat('0.##', 'vi').format(row.valueMinor / 100)}%'
        : 'Giảm ${money(row.valueMinor)}';
    return OwnerCard(
      radius: 23,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.code,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: colors.onSurface,
                  ),
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
            child: TintTag(label, tone: tone),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              discount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (row.capMinor != null) ...[
            OwnerNote('Tối đa: ${money(row.capMinor!)}'),
            const SizedBox(height: 2),
          ],
          OwnerNote('Đơn tối thiểu: ${money(row.minOrderMinor)}'),
          const SizedBox(height: 2),
          OwnerNote(
            'Hạn: ${DateFormat('dd/MM/yyyy HH:mm').format(row.endsAt.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
          ),
          if (busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: busy || blocked ? null : onUsage,
                  child: Text(
                    'Đã dùng: ${row.usedCount} / ${row.limit} lượt',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              OwnerPillButton(
                label: 'Chỉnh sửa',
                icon: Icons.edit_outlined,
                filled: false,
                onPressed: busy || blocked ? null : onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
