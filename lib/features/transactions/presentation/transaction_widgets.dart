import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/transaction.dart';

String vnd(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: 0,
).format(amount);
Future<void> showReceipt(BuildContext context, PaymentTransaction entry) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            ListTile(
              title: Text('Biên lai ${entry.code}'),
              trailing: IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: entry.receipt == null
                  ? const Center(child: Text('Giao dịch chưa có ảnh biên lai'))
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

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.entry});
  final PaymentTransaction entry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text('${entry.branch} · ${entry.court}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.code} · ${entry.bookingCode}\n${DateFormat('dd/MM/yyyy HH:mm').format(entry.occurredAt.toUtc().add(const Duration(hours: 7)))}',
          ),
          Wrap(
            spacing: 6,
            children: [
              Chip(
                label: Text(entry.typeLabel),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(entry.label),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
      trailing: Text(
        '${entry.amount >= 0 ? '+' : ''}${vnd(entry.amount)}',
        style: TextStyle(
          color: entry.transactionType == 'REFUND'
              ? Theme.of(context).colorScheme.error
              : switch (entry.status) {
                  'SUCCESS' => Colors.green,
                  'REJECTED' => Theme.of(context).colorScheme.error,
                  _ => null,
                },
          fontWeight: FontWeight.bold,
        ),
      ),
      isThreeLine: true,
      onTap: () => showReceipt(context, entry),
    ),
  );
}
