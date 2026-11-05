import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  });
  final AdminBooking booking;
  final Widget Function(Uri)? receiptBuilder;
  @override
  Widget build(BuildContext context) {
    final row = booking;
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin đơn đặt sân')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(row.code, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: BookingStatusBadge(row.status),
          ),
          const SizedBox(height: 16),
          Text(row.branchName),
          Text(row.courtName),
          Text('Ngày chơi: ${DateFormat('dd/MM/yyyy').format(row.date)}'),
          Text(
            'Ngày đặt: ${DateFormat('dd/MM/yyyy HH:mm').format(row.createdAt.toUtc().add(const Duration(hours: 7)))} (giờ Việt Nam)',
          ),
          const SizedBox(height: 12),
          Text('Khách hàng: ${row.customerName ?? 'Chưa cung cấp'}'),
          Text('SĐT: ${row.customerPhone ?? 'Chưa cung cấp'}'),
          Text('Tổng tiền: ${adminBookingMoney(row.amount)}'),
          Text(
            'Thanh toán: ${switch (row.paymentStatus) {
              'CONFIRMED' || 'PAID' => 'Đã thanh toán',
              'PENDING' => 'Chờ duyệt',
              'REJECTED' => 'Bị từ chối',
              'CANCELLED' => 'Đã hủy',
              _ => row.paymentStatus ?? 'Chưa ghi nhận',
            }}',
          ),
          const SizedBox(height: 20),
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
            const Text('Chưa có biên lai được cung cấp'),
        ],
      ),
    );
  }
}
