import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';
import '../../admin_dashboard/presentation/widgets/owner_ui.dart';
import '../domain/transaction.dart';

String vnd(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
).format(amount);

String _when(PaymentTransaction entry) =>
    DateFormat('dd/MM/yyyy HH:mm')
        .format(entry.occurredAt.toUtc().add(const Duration(hours: 7)));

/// Tông màu thẻ trạng thái của một giao dịch.
StatusTone transactionTone(BuildContext context, PaymentTransaction entry) {
  final fc = context.fc;
  return switch (entry.status) {
    'SUCCESS' => fc.success,
    'REJECTED' => fc.danger,
    'PENDING' => fc.warning,
    _ => fc.neutral,
  };
}

Future<void> showReceipt(BuildContext context, PaymentTransaction entry) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(ownerPad, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Biên lai ${entry.code}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entry.receipt == null
                  ? const OwnerMessage(
                      icon: Icons.receipt_long_outlined,
                      text: 'Giao dịch chưa có ảnh biên lai',
                    )
                  : InteractiveViewer(
                      minScale: .5,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          entry.receipt.toString(),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text(
                            'Chưa tải được ảnh biên lai. Vui lòng mở lại.',
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

/// Một giao dịch của sổ đối soát: chi nhánh · sân và số tiền (xanh khi thu
/// thành công, đỏ khi hoàn tiền), mã + giờ, rồi hai thẻ loại và trạng thái.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.entry});
  final PaymentTransaction entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final refund = entry.transactionType == 'REFUND';
    final amountColor = refund
        ? colors.error
        : switch (entry.status) {
            'SUCCESS' => context.fc.success.color,
            'REJECTED' => colors.error,
            _ => colors.onSurface,
          };
    final plus = entry.amount >= 0 && entry.status == 'SUCCESS' && !refund;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OwnerCard(
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
                  '${plus ? '+' : ''}${vnd(entry.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            OwnerNote('${entry.code} · ${entry.bookingCode}'),
            OwnerNote(_when(entry)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TintTag(entry.typeLabel),
                TintTag(entry.label, tone: transactionTone(context, entry)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
