import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/fc_widgets.dart';
import '../domain/admin_booking.dart';
import 'admin_receipt_screen.dart';
import 'booking_status_badge.dart';

String adminBookingMoney(num amount) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: 'đ',
  decimalDigits: amount % 1 == 0 ? 0 : 2,
).format(amount);

class AdminBookingDetail extends StatelessWidget {
  const AdminBookingDetail({
    super.key,
    required this.booking,
    this.receiptBuilder,
    this.onReviewPayment,
  });
  final AdminBooking booking;
  final Widget Function(Uri)? receiptBuilder;

  /// Chỉ hiện khi biên lai đang chờ duyệt: chuyển tới màn Duyệt/Từ chối của chi nhánh.
  final VoidCallback? onReviewPayment;

  static String _paymentLabel(String? status) => switch (status) {
    'CONFIRMED' || 'PAID' => 'Đã thanh toán',
    'PENDING' => 'Chờ duyệt',
    'REJECTED' => 'Bị từ chối',
    'CANCELLED' => 'Đã hủy',
    _ => status ?? 'Chưa ghi nhận',
  };

  @override
  Widget build(BuildContext context) {
    final row = booking;
    final theme = Theme.of(context);
    final canReview = onReviewPayment != null && row.paymentStatus == 'PENDING';
    final created = DateFormat('dd/MM/yyyy HH:mm')
        .format(row.createdAt.toUtc().add(const Duration(hours: 7)));
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin đơn đặt sân')),
      bottomNavigationBar: canReview
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Gap.screen),
                child: FilledButton.icon(
                  onPressed: onReviewPayment,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Duyệt / từ chối biên lai'),
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FcCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.code, style: theme.textTheme.titleLarge),
                  ),
                  BookingStatusBadge(row.status),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            FcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Lượt đặt'),
                  const SizedBox(height: Gap.md),
                  _InfoLine(
                    Icons.store_mall_directory_outlined,
                    row.branchName,
                  ),
                  _InfoLine(Icons.stadium_outlined, row.courtName),
                  _InfoLine(
                    Icons.event_outlined,
                    'Ngày chơi: ${DateFormat('dd/MM/yyyy').format(row.date)}',
                  ),
                  _InfoLine(
                    Icons.schedule,
                    'Ngày đặt: $created (giờ Việt Nam)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            FcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Khách hàng'),
                  const SizedBox(height: Gap.md),
                  _InfoLine(
                    Icons.person_outline,
                    'Khách hàng: ${row.customerName ?? 'Chưa cung cấp'}',
                  ),
                  _InfoLine(
                    Icons.phone_outlined,
                    'SĐT: ${row.customerPhone ?? 'Chưa cung cấp'}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),
            FcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Thanh toán'),
                  const SizedBox(height: Gap.md),
                  _InfoLine(
                    Icons.payments_outlined,
                    'Tổng tiền: ${adminBookingMoney(row.amount)}',
                  ),
                  _InfoLine(
                    Icons.fact_check_outlined,
                    'Thanh toán: ${_paymentLabel(row.paymentStatus)}',
                  ),
                  const SizedBox(height: Gap.sm),
                  if (row.receiptUri != null)
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog.fullscreen(
                          child:
                              receiptBuilder?.call(row.receiptUri!) ??
                              AdminReceiptScreen(uri: row.receiptUri!),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Xem biên lai'),
                    )
                  else
                    Text(
                      'Chưa có biên lai được cung cấp',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: Gap.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
